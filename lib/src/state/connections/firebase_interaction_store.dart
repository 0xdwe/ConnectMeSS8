import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/social_models.dart';
import 'interaction_store.dart';

/// Firestore-backed [InteractionStore] (Pass 4.5, #067).
///
/// Persists [CrmInteraction] records to
/// `users/{uid}/interactions/{interactionId}`. Each document
/// matches the closed shape from `firestore/firestore.rules`:
///
///  * `id` (string, must equal the document key)
///  * `contactId` (string, foreign key into the connection store)
///  * `type` (string, enum from [InteractionType])
///  * `title`, `note` (string, empty allowed)
///  * `date` (timestamp)
///  * `attachments` (list of strings, optional)
///  * `source` (string, enum from [InteractionSource], optional)
///  * `schemaVersion` (int, literal `1`)
///  * `updatedAt` (server timestamp)
///
/// **Attachments round-trip is name-only.** [AttachmentRef] declares
/// `path` as a nullable string that points at a local file on the
/// origin device. Local paths are non-portable across devices, so
/// the encoder flattens attachments to `name` only and the decoder
/// reconstructs `AttachmentRef(name: ..., path: null)`. This
/// behavior is intentional for Pass 4.5 single-device-prototype
/// scope; even on the same device, a save → read cycle drops the
/// path. A future Pass 4.x can add proper file-storage round-tripping
/// (Cloud Storage upload, signed URL persistence) without changing
/// this seam.
///
/// **UID is bound at construction.** Mirrors
/// [FirebaseConnectionStore] from #065. The auth-aware
/// `interactionStoreProvider` (#067) is responsible for rebuilding
/// a new adapter when the signed-in user changes; the adapter never
/// reads `FirebaseAuth.instance.currentUser` per operation.
///
/// **Snapshot listener pattern (PRD §Q6).** At construction, the
/// adapter opens a `users/{uid}/interactions.snapshots()`
/// subscription. Incoming snapshots are decoded into an immutable
/// `Map<String, CrmInteraction>` and pushed onto a broadcast
/// stream that backs both [snapshot] and [snapshotSync].
/// Cross-instance writes flow in through this listener
/// automatically. Listener errors are forwarded onto the broadcast
/// stream's error channel; the mirror is left unchanged so
/// downstream readers do not see a torn snapshot.
///
/// **Listener teardown contract.** [dispose] cancels the
/// subscription and closes the broadcast controller. Idempotent —
/// calling more than once must not throw. The auth-aware provider's
/// `onDispose` is the canonical caller.
///
/// **`snapshotSync()` null-while-loading contract.** Returns null
/// until the first Firestore snapshot resolves, then returns the
/// current mirror map (empty or populated) for the lifetime of the
/// adapter.
class FirebaseInteractionStore implements InteractionStore {
  FirebaseInteractionStore({
    required FirebaseFirestore firestore,
    required String uid,
  })  : _firestore = firestore,
        _uid = uid {
    _subscribe();
  }

  /// Schema version written into every interaction document.
  static const int schemaVersion = 1;

  final FirebaseFirestore _firestore;
  final String _uid;
  final StreamController<Map<String, CrmInteraction>> _controller =
      StreamController<Map<String, CrmInteraction>>.broadcast();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  Map<String, CrmInteraction>? _mirror;
  bool _disposed = false;

  /// Path: `users/{uid}/interactions`. Single getter so call sites
  /// can't drift from the canonical structure.
  CollectionReference<Map<String, dynamic>> get _interactionsRef =>
      _firestore.collection('users').doc(_uid).collection('interactions');

  DocumentReference<Map<String, dynamic>> _docRef(String interactionId) =>
      _interactionsRef.doc(interactionId);

  void _subscribe() {
    _subscription = _interactionsRef.snapshots().listen(
      (query) {
        final next = <String, CrmInteraction>{};
        for (final doc in query.docs) {
          final parsed = _decode(doc);
          if (parsed != null) next[parsed.id] = parsed;
        }
        final immutable = Map<String, CrmInteraction>.unmodifiable(next);
        _mirror = immutable;
        if (!_controller.isClosed) _controller.add(immutable);
      },
      onError: (Object error, StackTrace stack) {
        if (!_controller.isClosed) _controller.addError(error, stack);
      },
    );
  }

  @override
  Future<CrmInteraction?> load(String interactionId) async {
    final snapshot = await _docRef(interactionId).get();
    if (!snapshot.exists) return null;
    final data = snapshot.data();
    if (data == null) return null;
    return _decodeData(data);
  }

  @override
  Future<void> save(CrmInteraction interaction) async {
    await _docRef(interaction.id).set(_encode(interaction));
  }

  @override
  Future<void> delete(String interactionId) async {
    await _docRef(interactionId).delete();
  }

  @override
  Future<Map<String, CrmInteraction>> listAll() async {
    final query = await _interactionsRef.get();
    final out = <String, CrmInteraction>{};
    for (final doc in query.docs) {
      final parsed = _decode(doc);
      if (parsed != null) out[parsed.id] = parsed;
    }
    return Map.unmodifiable(out);
  }

  @override
  Stream<Map<String, CrmInteraction>> snapshot() {
    // Wrap the broadcast controller so each new subscriber gets the
    // current mirror replayed on first listen, matching
    // `InMemoryInteractionStore.snapshot()`.
    late StreamController<Map<String, CrmInteraction>> controller;
    StreamSubscription<Map<String, CrmInteraction>>? sub;
    controller = StreamController<Map<String, CrmInteraction>>(
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
  Map<String, CrmInteraction>? snapshotSync() => _mirror;

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

  Map<String, dynamic> _encode(CrmInteraction i) => encode(i);

  /// Public encoder used by [save] and by [ConnectionSeeder] (#069).
  /// Pure — does not read `_firestore` or `_uid`.
  static Map<String, dynamic> encode(CrmInteraction i) {
    return <String, dynamic>{
      'id': i.id,
      'contactId': i.contactId,
      'type': i.type.name,
      'title': i.title,
      'note': i.note,
      'date': Timestamp.fromDate(i.date),
      // attachments: Firestore can't serialize AttachmentRef; flatten
      // to the simple name list for now. Path is non-portable across
      // devices anyway and Pass 4.5 is single-device-prototype scope.
      'attachments': i.attachments.map((a) => a.name).toList(),
      'source': i.source.name,
      'schemaVersion': schemaVersion,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  CrmInteraction? _decode(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return _decodeData(doc.data());
  }

  /// Defensive decode. Tolerate malformed documents by returning
  /// null rather than throwing — the rules normally guarantee shape,
  /// but a transient inconsistency should not poison the snapshot.
  CrmInteraction? _decodeData(Map<String, dynamic> data) {
    try {
      final id = data['id'];
      final contactId = data['contactId'];
      final typeName = data['type'];
      final title = data['title'];
      final note = data['note'];
      final date = data['date'];
      final attachments = data['attachments'];
      final sourceName = data['source'];

      if (id is! String ||
          contactId is! String ||
          typeName is! String ||
          title is! String ||
          note is! String ||
          date is! Timestamp) {
        return null;
      }

      final type = InteractionType.values
          .where((t) => t.name == typeName)
          .firstOrNull;
      if (type == null) {
        // Unknown enum value — drop the document from the snapshot
        // rather than silently coercing to `interaction`. Rules
        // prevent this state in production; the guard exists for
        // the rules-disabled emulator path and any future schema
        // migration that lands a new enum value the client doesn't
        // recognize yet.
        return null;
      }
      final InteractionSource source;
      if (sourceName == null) {
        source = InteractionSource.manual;
      } else if (sourceName is String) {
        final candidate = InteractionSource.values
            .where((s) => s.name == sourceName)
            .firstOrNull;
        if (candidate == null) {
          // Unknown enum value — same defensive drop as above.
          return null;
        }
        source = candidate;
      } else {
        return null;
      }

      final List<AttachmentRef> attachmentRefs = attachments is List
          ? attachments
              .whereType<String>()
              .map((name) => AttachmentRef(name: name, path: null))
              .toList()
          : const <AttachmentRef>[];

      return CrmInteraction(
        id: id,
        contactId: contactId,
        type: type,
        title: title,
        note: note,
        date: date.toDate(),
        attachments: attachmentRefs,
        source: source,
      );
    } catch (_) {
      return null;
    }
  }
}
