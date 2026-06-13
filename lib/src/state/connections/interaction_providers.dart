import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/social_models.dart';
import '../firebase_providers.dart';
import 'firebase_interaction_store.dart';
import 'interaction_store.dart';

/// Active [InteractionStore] for the running app (Pass 4.5 #067).
///
/// Watches `currentUserProvider`. While signed out (or while the
/// auth stream is still loading), returns a
/// [_SignedOutInteractionStore] sentinel whose async surface throws
/// so accidental signed-out reads fail loudly. The signed-in path
/// returns a [FirebaseInteractionStore] bound to the current
/// `user.uid` and the active `firestoreProvider`.
///
/// Auth changes rebuild this provider, which discards the previous
/// user's store identity. The provider's `onDispose` calls
/// `store.dispose()` so the [FirebaseInteractionStore]'s snapshot
/// listener (PRD §Q6) is torn down before the next user's store is
/// constructed. Tests and widget tests override this provider
/// directly with their own [InteractionStore], in which case the
/// auth-aware logic is bypassed entirely.
///
/// `AppController` does not yet read this provider. The wiring lands
/// in #070; Pass 4.5 keeps the read paths additive until then.
final interactionStoreProvider = Provider<InteractionStore>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const _SignedOutInteractionStore();
  }
  final firestore = ref.watch(firestoreProvider);
  final store = FirebaseInteractionStore(firestore: firestore, uid: user.uid);
  ref.onDispose(store.dispose);
  return store;
});

/// Sentinel returned by [interactionStoreProvider] while signed
/// out.
///
/// Async methods throw [StateError] so a signed-out read surfaces
/// immediately. The [snapshot] stream is intentionally calm — it
/// emits a single empty map and completes — so widgets that watch
/// interactions during a sign-out frame render an empty state
/// instead of crashing.
class _SignedOutInteractionStore implements InteractionStore {
  const _SignedOutInteractionStore();

  static const String _msg = 'Interactions are not available while signed out.';

  @override
  Future<CrmInteraction?> load(String interactionId) =>
      Future.error(StateError(_msg));

  @override
  Future<void> save(CrmInteraction interaction) =>
      Future.error(StateError(_msg));

  @override
  Future<void> delete(String interactionId) => Future.error(StateError(_msg));

  @override
  Future<Map<String, CrmInteraction>> listAll() =>
      Future.error(StateError(_msg));

  @override
  Stream<Map<String, CrmInteraction>> snapshot() =>
      Stream<Map<String, CrmInteraction>>.value(
        const <String, CrmInteraction>{},
      );

  @override
  Map<String, CrmInteraction>? snapshotSync() =>
      const <String, CrmInteraction>{};

  @override
  Future<void> dispose() async {}
}
