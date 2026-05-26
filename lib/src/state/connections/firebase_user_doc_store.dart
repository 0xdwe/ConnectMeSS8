import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_doc_store.dart';

/// Firestore-backed [UserDocStore] (Pass 4.5 #070).
///
/// Persists `categories` and `eventTypes` as list-of-string fields
/// on `users/{uid}` (PRD §Q12). The user doc is shared with the
/// Pass 4.2 #059 migration sentinel (`migratedFromDiskAt`) and the
/// Pass 4.5 #069 seeding sentinels — those fields are owned by
/// other writers, so this store always uses set+merge to avoid
/// stomping on them.
///
/// **UID is bound at construction.** Mirrors
/// [FirebaseConnectionStore] from #065 — the adapter never reads
/// `FirebaseAuth.instance.currentUser` per operation. The
/// auth-aware provider (`userDocStoreProvider`) is responsible for
/// rebuilding a new adapter when the signed-in user changes.
///
/// **Snapshot listener.** Opens a `users/{uid}.snapshots()`
/// subscription at construction. Each document event decodes into
/// a [UserDocSnapshot] and pushes onto a broadcast stream backing
/// both [snapshot] and [snapshotSync]. Cross-instance writes (a
/// second store against the same UID, or another device under the
/// same account) flow in through this listener.
///
/// **Listener teardown contract.** [dispose] cancels the
/// subscription and closes the broadcast controller. Idempotent —
/// calling more than once must not throw.
///
/// **Listener-error contract.** Errors from the underlying
/// `snapshots()` stream forward onto the broadcast stream's error
/// channel. The mirror snapshot is left unchanged so downstream
/// readers do not see a torn state.
class FirebaseUserDocStore implements UserDocStore {
  FirebaseUserDocStore({
    required FirebaseFirestore firestore,
    required String uid,
  })  : _firestore = firestore,
        _uid = uid {
    _subscribe();
  }

  final FirebaseFirestore _firestore;
  final String _uid;
  final StreamController<UserDocSnapshot> _controller =
      StreamController<UserDocSnapshot>.broadcast();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  UserDocSnapshot? _mirror;
  bool _disposed = false;

  DocumentReference<Map<String, dynamic>> get _docRef =>
      _firestore.collection('users').doc(_uid);

  void _subscribe() {
    _subscription = _docRef.snapshots().listen(
      (doc) {
        final data = doc.exists ? doc.data() : null;
        final snap = _decode(data);
        _mirror = snap;
        if (!_controller.isClosed) _controller.add(snap);
      },
      onError: (Object error, StackTrace stack) {
        if (!_controller.isClosed) _controller.addError(error, stack);
      },
    );
  }

  @override
  Future<void> saveCategories(List<String> categories) async {
    // set+merge: preserve sibling fields (`migratedFromDiskAt`,
    // `*SeededAt`, the other list field) that this store does not
    // own.
    await _docRef.set(
      <String, dynamic>{'categories': List<String>.from(categories)},
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> saveEventTypes(List<String> eventTypes) async {
    await _docRef.set(
      <String, dynamic>{'eventTypes': List<String>.from(eventTypes)},
      SetOptions(merge: true),
    );
  }

  @override
  Stream<UserDocSnapshot> snapshot() {
    // Wrap the broadcast controller so each new subscriber gets the
    // current mirror replayed on first listen, matching
    // [FirebaseConnectionStore.snapshot].
    late StreamController<UserDocSnapshot> controller;
    StreamSubscription<UserDocSnapshot>? sub;
    controller = StreamController<UserDocSnapshot>(
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
  UserDocSnapshot? snapshotSync() => _mirror;

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

  /// Defensive decode. Tolerate a missing or malformed user doc by
  /// falling back to empty lists. The seeder (#069) guarantees that
  /// a fully-seeded account has both fields, so a missing field is
  /// either a fresh-seeded-only-categories partial state (carries
  /// the present field forward) or a corrupt write (degraded but
  /// non-crashing).
  UserDocSnapshot _decode(Map<String, dynamic>? data) {
    if (data == null) return UserDocSnapshot.empty;
    final categoriesRaw = data['categories'];
    final eventTypesRaw = data['eventTypes'];
    final categories = categoriesRaw is List
        ? List<String>.unmodifiable(categoriesRaw.whereType<String>())
        : const <String>[];
    final eventTypes = eventTypesRaw is List
        ? List<String>.unmodifiable(eventTypesRaw.whereType<String>())
        : const <String>[];
    return UserDocSnapshot(
      categories: categories,
      eventTypes: eventTypes,
    );
  }
}
