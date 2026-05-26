import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/social_models.dart';
import '../firebase_providers.dart';
import 'event_store.dart';
import 'firebase_event_store.dart';

/// Active [EventStore] for the running app (Pass 4.5 #068).
///
/// Watches `currentUserProvider`. While signed out (or while the
/// auth stream is still loading), returns a [_SignedOutEventStore]
/// sentinel whose async surface throws so accidental signed-out
/// reads fail loudly. The signed-in path returns a
/// [FirebaseEventStore] bound to the current `user.uid` and the
/// active `firestoreProvider`.
///
/// Auth changes rebuild this provider, which discards the previous
/// user's store identity. The provider's `onDispose` calls
/// `store.dispose()` so the [FirebaseEventStore]'s snapshot listener
/// (PRD §Q6) is torn down before the next user's store is
/// constructed.
///
/// `AppController` does not yet read this provider. The wiring lands
/// in #070.
final eventStoreProvider = Provider<EventStore>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const _SignedOutEventStore();
  }
  final firestore = ref.watch(firestoreProvider);
  final store = FirebaseEventStore(
    firestore: firestore,
    uid: user.uid,
  );
  ref.onDispose(store.dispose);
  return store;
});

/// Sentinel returned by [eventStoreProvider] while signed out.
///
/// Async methods throw [StateError] so a signed-out read surfaces
/// immediately. The [snapshot] stream is intentionally calm — it
/// emits a single empty map and completes — so widgets that watch
/// events during a sign-out frame render an empty state instead of
/// crashing.
class _SignedOutEventStore implements EventStore {
  const _SignedOutEventStore();

  static const String _msg =
      'Events are not available while signed out.';

  @override
  Future<PlannerEvent?> load(String eventId) =>
      Future.error(StateError(_msg));

  @override
  Future<void> save(PlannerEvent event) =>
      Future.error(StateError(_msg));

  @override
  Future<void> delete(String eventId) =>
      Future.error(StateError(_msg));

  @override
  Future<Map<String, PlannerEvent>> listAll() =>
      Future.error(StateError(_msg));

  @override
  Stream<Map<String, PlannerEvent>> snapshot() =>
      Stream<Map<String, PlannerEvent>>.value(
        const <String, PlannerEvent>{},
      );

  @override
  Map<String, PlannerEvent>? snapshotSync() =>
      const <String, PlannerEvent>{};

  @override
  Future<void> dispose() async {}
}
