import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/social_models.dart';
import '../firebase_providers.dart';
import 'batched_writes.dart';

/// Active [BatchedWrites] for the running app (Pass 4.5 #070).
///
/// Watches `currentUserProvider`. While signed out, returns a
/// [_SignedOutBatchedWrites] sentinel whose async methods throw —
/// AppController should never invoke a multi-store batch while
/// signed out, and the loud failure surfaces an ordering bug
/// rather than silently swallowing the call.
///
/// Signed-in path returns a [FirebaseBatchedWrites] bound to the
/// current `user.uid` and the active `firestoreProvider`.
final batchedWritesProvider = Provider<BatchedWrites>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const _SignedOutBatchedWrites();
  }
  final firestore = ref.watch(firestoreProvider);
  return FirebaseBatchedWrites(firestore: firestore, uid: user.uid);
});

class _SignedOutBatchedWrites implements BatchedWrites {
  const _SignedOutBatchedWrites();

  static const String _msg =
      'Multi-store batches are not available while signed out.';

  @override
  Future<void> commitDeleteConnection({
    required String contactId,
    required Iterable<CrmInteraction> interactions,
    required Iterable<PlannerEvent> events,
  }) =>
      Future.error(StateError(_msg));

  @override
  Future<void> commitAiUpdate({
    required CrmInteraction interaction,
    required Connection updatedConnection,
  }) =>
      Future.error(StateError(_msg));

  @override
  Future<void> commitRemoveSampleConnections({
    required Iterable<Connection> connections,
    required Iterable<CrmInteraction> interactions,
    required Iterable<PlannerEvent> events,
  }) =>
      Future.error(StateError(_msg));
}
