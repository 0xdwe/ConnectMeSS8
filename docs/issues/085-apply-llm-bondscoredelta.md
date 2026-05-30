# #085 Apply LLM-supplied bondScoreDelta when committing AI Update

Labels: issue, needs-triage

**Status: deferred from #080 (Pass 4.3 LlmAiUpdate adapter).** Filed as a follow-up so the deferral isn't silently lost during Pass 4.3 closeout.

## Parent

docs/prd/2026-05-27-llm-ai-update-pass-4-3-prd.md (PRD §Q4 + user story 17).

## Problem

The Pass 4.3 schema-constrained response (`LlmAiUpdateResponse`) carries a `bondScoreDelta` field clamped 0..5 per the PRD §Q6 rubric: 0 trivial, 1-2 normal, 3-4 meaningful, 5 only for major life moments. The whole point of the rubric is user story 17:

> As a ConnectMe user, I want meaningful updates to move Bond Score more than trivial updates, so that relationship strength reflects real context.

`LlmAiUpdate` parses the field, clamps it correctly, and... discards it. `AiUpdateResult` has no `bondScoreDelta` slot, and `AppController.applyAiUpdateResult` (`lib/src/state/app_state.dart:737`) hardcodes a `+3` bond score nudge regardless of the LLM's judgment. So today every AI Update bumps Bond Score by exactly 3, which is what `MockAiUpdate` produced and what the recommendation engine has been expecting since Pass 3.

The reviewer (`.agent-runs/080-llm-ai-update-review.md`) flagged this as a Note ("strict reading of #080 AC says only 'clamped client-side to 0..5' — satisfied, but this is a real Pass 4.3 gap that will surprise a future maintainer"). The Pass 4.3 PRD's §Q4 and user story 17 explicitly call out the rubric as a feature, so this gap matters.

## What to build

Thread the LLM-supplied `bondScoreDelta` from `LlmAiUpdateResponse` through `AiUpdateResult` and into `AppController.applyAiUpdateResult` so the bond score actually moves by the calibrated amount.

## Acceptance criteria

- [ ] `AiUpdateResult` gains a `bondScoreDelta` field (or a metadata sub-object). Default value preserves the existing `+3` semantics so older `MockAiUpdate` tests do not need to change.
- [ ] `LlmAiUpdate.projectLlmResponseOntoAiUpdateResult` (or its successor) populates `bondScoreDelta` from `LlmAiUpdateResponse.bondScoreDelta`.
- [ ] `MockAiUpdate.run` continues to emit a fixed delta (or its existing implicit `+3`); existing `test/ai/ai_update_test.dart` cases stay green.
- [ ] `AppController.applyAiUpdateResult` uses `result.bondScoreDelta` instead of the hardcoded `+3`. Clamp to `0..100` on the resulting score (Pass 3 invariant).
- [ ] Tests added under `test/state/ai/` verifying the projected `AiUpdateResult.bondScoreDelta` round-trips through `applyAiUpdateResult` and changes the contact's Bond Score by the LLM-chosen amount.
- [ ] Tests verify clamping: a delta of 0 leaves Bond Score unchanged; a delta of 5 increases it by 5 (or to 100, whichever is smaller).
- [ ] No production behavior change for `MockAiUpdate`-driven tests.
- [ ] `flutter analyze` clean.

## Why deferred from #080

Adding `bondScoreDelta` to `AiUpdateResult` touches `MockAiUpdate.run`, every test that constructs `AiUpdateResult` directly, and `AppController.applyAiUpdateResult`. That's outside #080's scoped surface (LlmAiUpdate adapter only) and would have required reshaping unrelated tests. The seam is in good shape to land this small change in a follow-up without touching anything in `lib/src/ai/llm_ai_update.dart`.

## Blocked by

#080 (shipped). Can start immediately when picked up.
