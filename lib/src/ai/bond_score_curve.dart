/// Bond Score curve helper (Pass 4.3 PRD §Q6 addendum / #085).
///
/// Lives in its own file so both [MockAiUpdate] and [LlmAiUpdate]
/// can call the canonical implementation without `llm_ai_update.dart`
/// being a transitive dependency of `ai_update.dart` (the seam).
/// The seam stays Firebase-AI-free; the curve is pure Dart.
///
/// See `docs/issues/085-apply-llm-bondscoredelta.md` for the full
/// reference table, anchor cells, and rationale.
library;

import 'package:flutter/foundation.dart' show visibleForTesting;

/// Applies the diminishing-returns Bond Score curve.
///
/// Formula: `delta = floor(depth × (100 − currentBond) / 160)`.
///
/// Splits two concerns:
/// 1. The LLM judges [depth] (0..100) on the input's own merits via
///    the prompt rubric — trivial, brief, substantive, significant,
///    deep day-long bonding. The LLM does not see the contact's
///    current Bond Score.
/// 2. This function applies the curve so the *same* depth produces
///    a much bigger delta at low bond than at high bond. Bond Score
///    is the existing relationship strength; the marginal gain from
///    one more interaction is naturally larger when the relationship
///    is undeveloped.
///
/// Anchored to the 2026-06-01 grilling decision:
/// - bond=20, depth=100 → +50 (one deep day-long update at low bond
///   should move the score by half).
/// - bond=90, depth=100 → +6 (the same deep update at high bond
///   should barely move the already-strong relationship).
///
/// No `+1` floor at non-zero depth: diminishing returns means *exactly*
/// that, and a floor would distort the curve. Trivial inputs at high
/// bond produce 0 movement.
///
/// Inputs are clamped defensively (depth to 0..100, currentBond to
/// 0..100). Schema validation should reject out-of-range values
/// upstream, but the helper never amplifies a corrupted input — a
/// negative depth produces 0, a >100 depth is treated as 100, a
/// >100 currentBond is treated as 100 (so the delta is 0).
int applyBondScoreCurve({required int depth, required int currentBond}) {
  final clampedDepth = depth.clamp(-100, 100);
  final clampedBond = currentBond.clamp(0, 100);
  if (clampedDepth >= 0) {
    // Positive: gain proportional to room to grow (diminishing returns at
    // high bond so the same great interaction matters less once strong).
    return (clampedDepth * (100 - clampedBond)) ~/ 160;
  } else {
    // Negative: drop proportional to current bond (symmetric formula).
    // A fight with someone you barely know hurts less than a fight with
    // a close friend — because there is less bond to damage.
    return -((-clampedDepth) * clampedBond) ~/ 160;
  }
}

/// Test-only handle. Re-exports [applyBondScoreCurve] under the
/// `@visibleForTesting` naming convention used by the rest of the
/// `ai/` directory so curve-helper tests in `test/state/ai/` can
/// call it from a single import.
@visibleForTesting
int debugApplyBondScoreCurve({required int depth, required int currentBond}) {
  return applyBondScoreCurve(depth: depth, currentBond: currentBond);
}
