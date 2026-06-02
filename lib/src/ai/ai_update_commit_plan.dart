import '../models/social_models.dart';

/// Pure projection of an accepted [AiUpdateResult] onto the Relationship Graph
/// writes that [AppController] coordinates.
class AiUpdateCommitPlan {
  const AiUpdateCommitPlan({
    required this.interaction,
    required this.updatedConnection,
    required this.summary,
  });

  final CrmInteraction interaction;
  final Connection updatedConnection;
  final String summary;
}

AiUpdateCommitPlan buildAiUpdateCommitPlan({
  required AiUpdateResult result,
  required Connection connection,
  required DateTime now,
}) {
  if (result.interactions.length != 1) {
    throw StateError(
      'applyAiUpdateResult expects exactly one interaction, '
      'got ${result.interactions.length}',
    );
  }

  final nextScore =
      (connection.bondScore + result.bondScoreDelta).clamp(0, 100);
  final updatedConnection = connection.copyWith(
    nextStep: result.nextStep ?? connection.nextStep,
    lastContact: now,
    bondScore: nextScore,
  );

  return AiUpdateCommitPlan(
    interaction: result.interactions.single,
    updatedConnection: updatedConnection,
    summary: result.summary,
  );
}
