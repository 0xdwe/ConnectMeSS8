import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'file_memory_store.dart' show trimToCap;
import 'memory_document.dart';
import 'memory_store.dart';

// Re-export so consumers don't need to import file_memory_store.dart
// just to catch the cap exception on writes.
export 'file_memory_store.dart' show MemoryCapExceededException;

/// Firestore-backed [MemoryStore]. Pass 4.2 (#057).
///
/// Persists per-contact memory documents to
/// `users/{uid}/memories/{contactId}`. Each document is stored as
/// exactly three fields per the canonical Firestore shape from
/// PRD Q3:
///
///  * `markdown` — the rendered [MemoryDocument] (string, ≤64KB).
///  * `updatedAt` — server-side [FieldValue.serverTimestamp].
///  * `schemaVersion` — int literal `1`.
///
/// The shape is enforced server-side by the Firestore rules in
/// `firestore/firestore.rules`: any extra key, missing key, wrong
/// type, or oversized markdown is rejected. The 64KB per-contact
/// cap from PRD Q6 is therefore enforced by both the client (via
/// [trimToCap]) and the rules.
///
/// **UID is bound at construction (PRD Q7).** This adapter never
/// reads `FirebaseAuth.instance.currentUser` per operation. The
/// auth-aware Riverpod provider in #058 rebuilds the store when the
/// signed-in user changes; if the user signs out and a new user
/// signs in, that produces a brand-new `FirebaseMemoryStore`
/// instance bound to the new UID. There is no way for one store
/// instance to silently route a write to another user's collection.
///
/// **Save acceptance contract (PRD Q8).** [save] returns when the
/// SDK accepts the write into its local cache and queues
/// replication. It does not wait for server-side acknowledgement.
/// This is the offline-friendly default — a user updating Sarah on
/// the subway sees `save` complete immediately, the AI Update flow
/// commits its in-memory state delta via [AiUpdate.commit], and the
/// queued write replicates when network returns. The accepted
/// prototype failure mode: if the app is uninstalled while a queued
/// write is still pending, that write is lost. This is documented
/// here rather than engineered around — the product is a memory
/// aid, not a financial ledger.
///
/// **Production wiring is deferred to #060.** This issue ships the
/// adapter behind the existing `MemoryStore` seam; the production
/// `memoryStoreProvider` continues to return `FileMemoryStore`
/// until #058 (auth-aware provider rebuild) and #060 (production
/// cutover) land.
class FirebaseMemoryStore implements MemoryStore {
  FirebaseMemoryStore({
    required FirebaseFirestore firestore,
    required String uid,
  })  : _firestore = firestore,
        _uid = uid;

  /// Schema version written into every memory document. Bumped only
  /// when the canonical Firestore shape changes.
  static const int schemaVersion = 1;

  final FirebaseFirestore _firestore;
  final String _uid;

  /// Path: `users/{uid}/memories`. Single getter so call sites can't
  /// drift from the canonical structure.
  CollectionReference<Map<String, dynamic>> get _memoriesRef =>
      _firestore.collection('users').doc(_uid).collection('memories');

  DocumentReference<Map<String, dynamic>> _docRef(String contactId) =>
      _memoriesRef.doc(contactId);

  @override
  Future<MemoryDocument?> load(String contactId) async {
    final snapshot = await _docRef(contactId).get();
    if (!snapshot.exists) return null;
    final data = snapshot.data();
    if (data == null) return null;

    // Defensive: tolerate documents that lack the expected fields by
    // returning null rather than throwing. Mirrors the
    // `FileMemoryStore.listAll` behavior of skipping un-parseable
    // docs. The rules normally guarantee this never happens, but a
    // future migration could leave a transient malformed doc.
    final markdown = data['markdown'];
    if (markdown is! String) return null;

    return MemoryDocument.parse(markdown);
  }

  @override
  Future<void> save(MemoryDocument doc) async {
    // Client-side trim. The rules also enforce ≤64KB markdown
    // server-side, but trimming here gives the app a clean error
    // path (oldest history bullets dropped first; throws
    // [MemoryCapExceededException] if there's nothing left to drop).
    final trimmed = trimToCap(doc);
    final markdown = trimmed.render();

    // Set with no merge: a single atomic replace of the document.
    // The rules require an exact key set of {markdown, updatedAt,
    // schemaVersion}; merging risks leaving stale fields if the
    // shape ever changes.
    await _docRef(doc.contactId).set(<String, dynamic>{
      'markdown': markdown,
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': schemaVersion,
    });
  }

  @override
  Future<void> delete(String contactId) async {
    // Firestore's delete is naturally idempotent — deleting a
    // missing doc is a no-op, no exception, no extra read.
    await _docRef(contactId).delete();
  }

  @override
  Future<Map<String, MemoryDocument>> listAll() async {
    final query = await _memoriesRef.get();
    final out = <String, MemoryDocument>{};
    for (final doc in query.docs) {
      final data = doc.data();
      final markdown = data['markdown'];
      if (markdown is! String) {
        // Skip un-parseable docs rather than poisoning the snapshot.
        continue;
      }
      final parsed = MemoryDocument.parse(markdown);
      // An empty contactId means the markdown frontmatter was
      // unreadable. Drop it from the snapshot.
      if (parsed.contactId.isEmpty) continue;
      out[parsed.contactId] = parsed;
    }
    return Map.unmodifiable(out);
  }
}
