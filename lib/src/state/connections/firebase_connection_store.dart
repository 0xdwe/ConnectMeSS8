import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/social_models.dart';
import 'connection_store.dart';

/// Firestore-backed [ConnectionStore] (Pass 4.5, #065).
///
/// Persists [Connection] records to
/// `users/{uid}/connections/{contactId}`. Each document is the full
/// 14-field connection shape per PRD §Q8 and the rules in
/// `firestore/firestore.rules` from #066:
///
///  * `id` (string, must equal the document key)
///  * `name`, `email`, `category`, `avatar`, `nextStep`, `notes`
///    (string, empty allowed)
///  * `bondScore` (int, 0..100)
///  * `lastContact`, `knownSince` (timestamp)
///  * `preferredChannels` (list of strings)
///  * `isSample` (bool, optional)
///  * `lastBondDriftAppliedAt` (timestamp, optional)
///  * `schemaVersion` (int, literal `1`)
///  * `updatedAt` (server timestamp)
///
/// **UID is bound at construction.** Mirrors [FirebaseMemoryStore]
/// from Pass 4.2 #057 — the adapter never reads
/// `FirebaseAuth.instance.currentUser` per operation. The
/// auth-aware `connectionStoreProvider` (#064) is responsible for
/// rebuilding a new adapter when the signed-in user changes.
///
/// **Snapshot listener pattern (PRD §Q6).** Pass 4.2's
/// [FirebaseMemoryStore] was pure request-response: `.get()`,
/// `.set()`, `.delete()`. Pass 4.5 introduces a NEW pattern that
/// Pass 4.2 did not pay for. At construction, the adapter opens a
/// `users/{uid}/connections.snapshots()` subscription. Incoming
/// snapshots are decoded into an immutable `Map<String, Connection>`
/// and pushed onto a broadcast stream that backs both [snapshot] and
/// [snapshotSync]. Cross-instance writes (a second store against
/// the same UID, or another device under the same account) flow in
/// through this listener automatically.
///
/// **Listener teardown contract.** [dispose] cancels the
/// subscription and closes the broadcast controller. Idempotent —
/// calling more than once must not throw. The auth-aware provider's
/// `onDispose` is the canonical caller; production widgets should
/// not call it directly.
///
/// **Listener-error contract.** Errors emitted by the underlying
/// `snapshots()` stream (network, permission-denied during
/// sign-out race) are forwarded onto the broadcast stream's error
/// channel. The mirror map is left unchanged so downstream readers
/// do not see a torn snapshot.
///
/// **Save acceptance contract.** [save] returns when the SDK
/// accepts the write into its local cache and queues replication.
/// It does not wait for server acknowledgement. This is the
/// offline-friendly default — a user editing Sarah on the subway
/// sees `save` complete immediately and the queued write replicates
/// when network returns. The accepted prototype failure mode: an
/// app uninstall while a queued write is still pending loses that
/// write. Documented rather than engineered around — the product is
/// a memory aid, not a financial ledger.
///
/// **`snapshotSync()` null-while-loading contract.** Returns null
/// until the first Firestore snapshot resolves, then returns the
/// current mirror map (empty or populated) for the lifetime of the
/// adapter. Callers that need to distinguish "loading" from
/// "signed-in but empty" check for null on the synchronous getter
/// and fall through to the [snapshot] stream's first event for the
/// loaded state.
class FirebaseConnectionStore implements ConnectionStore {
  FirebaseConnectionStore({
    required FirebaseFirestore firestore,
    required String uid,
  }) : _firestore = firestore,
       _uid = uid {
    _subscribe();
  }

  /// Schema version written into every connection document. Bumped
  /// only when the canonical Firestore shape changes.
  static const int schemaVersion = 1;

  final FirebaseFirestore _firestore;
  final String _uid;
  final StreamController<Map<String, Connection>> _controller =
      StreamController<Map<String, Connection>>.broadcast();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  Map<String, Connection>? _mirror;
  bool _disposed = false;

  /// Path: `users/{uid}/connections`. Single getter so call sites
  /// can't drift from the canonical structure.
  CollectionReference<Map<String, dynamic>> get _connectionsRef =>
      _firestore.collection('users').doc(_uid).collection('connections');

  DocumentReference<Map<String, dynamic>> _docRef(String contactId) =>
      _connectionsRef.doc(contactId);

  void _subscribe() {
    _subscription = _connectionsRef.snapshots().listen(
      (query) {
        final next = <String, Connection>{};
        for (final doc in query.docs) {
          final parsed = _decode(doc);
          if (parsed != null) next[parsed.id] = parsed;
        }
        final immutable = Map<String, Connection>.unmodifiable(next);
        _mirror = immutable;
        if (!_controller.isClosed) _controller.add(immutable);
      },
      onError: (Object error, StackTrace stack) {
        // Forward listener errors onto the stream's error channel
        // without corrupting the mirror map. Callers that subscribe
        // to `snapshot()` see the error; the synchronous mirror
        // continues to expose the last-known-good map.
        if (!_controller.isClosed) _controller.addError(error, stack);
      },
    );
  }

  @override
  Future<Connection?> load(String contactId) async {
    final snapshot = await _docRef(contactId).get();
    if (!snapshot.exists) return null;
    final data = snapshot.data();
    if (data == null) return null;
    return decode(data);
  }

  @override
  Future<void> save(Connection connection) async {
    // Set with no merge: a single atomic replace of the document.
    // The rules require an exact key set per #066 — merging risks
    // leaving stale fields if the shape ever changes.
    await _docRef(connection.id).set(_encode(connection));
  }

  @override
  Future<void> delete(String contactId) async {
    // Firestore's delete is naturally idempotent — deleting a
    // missing doc is a no-op, no exception, no extra read.
    await _docRef(contactId).delete();
  }

  @override
  Future<Map<String, Connection>> listAll() async {
    final query = await _connectionsRef.get();
    final out = <String, Connection>{};
    for (final doc in query.docs) {
      final parsed = _decode(doc);
      if (parsed != null) out[parsed.id] = parsed;
    }
    return Map.unmodifiable(out);
  }

  @override
  Stream<Map<String, Connection>> snapshot() {
    // Wrap the broadcast controller so each new subscriber gets the
    // current mirror replayed on first listen, matching
    // `InMemoryConnectionStore.snapshot()`. Without the replay,
    // subscribers that listen after the first Firestore snapshot
    // would block until the next mutation.
    late StreamController<Map<String, Connection>> controller;
    StreamSubscription<Map<String, Connection>>? sub;
    controller = StreamController<Map<String, Connection>>(
      onListen: () {
        final current = _mirror;
        if (current != null) controller.add(current);
        sub = _controller.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () async {
        await sub?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  @override
  Map<String, Connection>? snapshotSync() => _mirror;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  // ---------------------------------------------------------------
  // Encode / decode
  // ---------------------------------------------------------------

  Map<String, dynamic> _encode(Connection c) => encode(c);

  /// Public encoder used by [save] and by [ConnectionSeeder] (#069).
  /// Pure — does not read `_firestore` or `_uid`. Exposed so the
  /// seeder can reuse the canonical document shape without
  /// duplicating field lists, and so the encoder can be tested in
  /// isolation if needed.
  static Map<String, dynamic> encode(Connection c) {
    final data = <String, dynamic>{
      'id': c.id,
      'name': c.name,
      'email': c.email,
      'category': c.category,
      'avatar': c.avatar,
      'bondScore': c.bondScore,
      'nextStep': c.nextStep,
      'lastContact': Timestamp.fromDate(c.lastContact),
      'notes': c.notes,
      'knownSince': Timestamp.fromDate(c.knownSince),
      'preferredChannels': List<String>.from(c.preferredChannels),
      'phone': c.phone,
      'address': c.address,
      'instagram': c.instagram,
      'linkedin': c.linkedin,
      'whatsapp': c.whatsapp,
      'line': c.line,
      'isSample': c.isSample,
      'schemaVersion': schemaVersion,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final lastBondDriftAppliedAt = c.lastBondDriftAppliedAt;
    if (lastBondDriftAppliedAt != null) {
      data['lastBondDriftAppliedAt'] = Timestamp.fromDate(
        lastBondDriftAppliedAt,
      );
    }
    return data;
  }

  Connection? _decode(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return decode(doc.data());
  }

  /// Defensive decode. Tolerate malformed documents by returning
  /// null rather than throwing — the rules normally guarantee shape,
  /// but a transient inconsistency (e.g. mid-migration write) should
  /// not poison the snapshot. Mirrors `FirebaseMemoryStore.load`.
  @visibleForTesting
  static Connection? decode(Map<String, dynamic> data) {
    try {
      final id = data['id'];
      final name = data['name'];
      final email = data['email'];
      final category = data['category'];
      final avatar = data['avatar'];
      final bondScore = data['bondScore'];
      final nextStep = data['nextStep'];
      final lastContact = data['lastContact'];
      final notes = data['notes'];
      final knownSince = data['knownSince'];
      final preferredChannels = data['preferredChannels'];
      final phone = data['phone'];
      final address = data['address'];
      final instagram = data['instagram'];
      final linkedin = data['linkedin'];
      final whatsapp = data['whatsapp'];
      final line = data['line'];
      final isSample = data['isSample'];
      final lastBondDriftAppliedAt = data['lastBondDriftAppliedAt'];

      if (id is! String ||
          name is! String ||
          email is! String ||
          category is! String ||
          avatar is! String ||
          bondScore is! int ||
          nextStep is! String ||
          lastContact is! Timestamp ||
          notes is! String ||
          knownSince is! Timestamp ||
          preferredChannels is! List ||
          (lastBondDriftAppliedAt != null &&
              lastBondDriftAppliedAt is! Timestamp)) {
        return null;
      }

      return Connection(
        id: id,
        name: name,
        email: email,
        category: category,
        avatar: avatar,
        bondScore: bondScore,
        nextStep: nextStep,
        lastContact: lastContact.toDate(),
        notes: notes,
        knownSince: knownSince.toDate(),
        preferredChannels: List<String>.from(
          preferredChannels.whereType<String>(),
        ),
        phone: phone is String ? phone : '',
        address: address is String ? address : '',
        instagram: instagram is String ? instagram : '',
        linkedin: linkedin is String ? linkedin : '',
        whatsapp: whatsapp is String ? whatsapp : '',
        line: line is String ? line : '',
        isSample: isSample is bool ? isSample : false,
        lastBondDriftAppliedAt: lastBondDriftAppliedAt is Timestamp
            ? lastBondDriftAppliedAt.toDate()
            : null,
      );
    } catch (_) {
      // Defensive — never let a single bad document block the
      // snapshot. Decode failures show up in tests against real
      // Firestore documents; in production they are silently
      // dropped from the map so the rest of the user's connections
      // continue to render.
      return null;
    }
  }
}
