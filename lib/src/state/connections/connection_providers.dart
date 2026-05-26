import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/social_models.dart';
import '../firebase_providers.dart';
import 'connection_store.dart';
import 'in_memory_connection_store.dart';

/// Active [ConnectionStore] for the running app (Pass 4.5 #064).
///
/// Watches `currentUserProvider`. While signed out (or while the
/// auth stream is still loading), returns a [_SignedOutConnectionStore]
/// sentinel whose async surface throws so accidental signed-out
/// reads fail loudly. The signed-in path returns an
/// [InMemoryConnectionStore] for now; #065 swaps the production
/// override to a Firestore-backed adapter without changing this
/// provider's shape.
///
/// Auth changes rebuild this provider, which discards the previous
/// user's store identity. Tests and widget tests override this
/// provider directly with their own [ConnectionStore], in which case
/// the auth-aware logic is bypassed entirely (the override always
/// wins).
///
/// `AppController` does not yet read this provider. The wiring lands
/// in #070; Pass 4.5 keeps the read paths additive until then.
final connectionStoreProvider = Provider<ConnectionStore>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const _SignedOutConnectionStore();
  }
  // #065 will swap this branch for a `FirebaseConnectionStore` bound
  // to `user.uid` and `firestoreProvider`. Returning an in-memory
  // store today keeps the seam unblocked for #066–#068 tests without
  // pulling in the Firestore SDK.
  final ConnectionStore store = InMemoryConnectionStore();
  ref.onDispose(store.dispose);
  return store;
});

/// Sentinel returned by [connectionStoreProvider] while signed out.
///
/// Async methods throw [StateError] so a signed-out read surfaces
/// immediately. The [snapshot] stream is intentionally calm — it
/// emits a single empty map and completes — so widgets that watch
/// connections during a sign-out frame render an empty state instead
/// of crashing.
class _SignedOutConnectionStore implements ConnectionStore {
  const _SignedOutConnectionStore();

  static const String _msg =
      'Connections are not available while signed out.';

  @override
  Future<Connection?> load(String contactId) =>
      Future.error(StateError(_msg));

  @override
  Future<void> save(Connection connection) =>
      Future.error(StateError(_msg));

  @override
  Future<void> delete(String contactId) =>
      Future.error(StateError(_msg));

  @override
  Future<Map<String, Connection>> listAll() =>
      Future.error(StateError(_msg));

  @override
  Stream<Map<String, Connection>> snapshot() =>
      Stream<Map<String, Connection>>.value(const <String, Connection>{});

  @override
  Map<String, Connection>? snapshotSync() => const <String, Connection>{};

  @override
  Future<void> dispose() async {}
}
