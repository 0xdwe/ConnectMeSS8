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

  final nextScore = (connection.bondScore + result.bondScoreDelta).clamp(0, 100);

  // Use the interaction's date as lastContact so a user-chosen date
  // (edited in the preview screen) is reflected on the connection card,
  // the heatmap, and the recommendations engine. Fall back to `now` only
  // when there is no interaction (shouldn't happen given the guard above).
  final interactionDate = result.interactions.single.date;
  final lastContact = interactionDate.isBefore(now) ? interactionDate : now;

  final updatedConnection = connection.copyWith(
    nextStep: result.nextStep ?? connection.nextStep,
    lastContact: lastContact,
    bondScore: nextScore,
    previousBondScore: connection.bondScore,
    lastBondDriftAppliedAt: now,
  );

  return AiUpdateCommitPlan(
    interaction: result.interactions.single.copyWith(
      bondScoreDelta: result.bondScoreDelta,
    ),
    updatedConnection: updatedConnection,
    summary: result.summary,
  );
}
