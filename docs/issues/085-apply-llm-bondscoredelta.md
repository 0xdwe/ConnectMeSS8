# #085 Diminishing-returns Bond Score curve from LLM-emitted interactionDepth

Labels: issue, ready

## Parent

`docs/prd/2026-05-27-llm-ai-update-pass-4-3-prd.md` §Q6 (rewritten by this issue) and the 2026-06-01 grilling addendum.

## Why this exists

Pass 4.3 originally specified a `bondScoreDelta: integer 0..5` field that the LLM would emit per the rubric "0=trivial, 5=major life moment." `LlmAiUpdate` parses it but nothing else does — `_projectOntoAiUpdateResult` discards the field, `AppController.applyAiUpdateResult` hardcodes `+3` regardless of input. Every committed AI Update bumps Bond Score by exactly +3, which feels wrong end-to-end:

- Trivial small-talk updates and major-life-moment updates move Bond Score identically.
- A user who opens a fresh contact at bond 20 and runs one deep "we travelled together for a day" update gets +3 (→23), which feels useless given the depth of input.
- A user at bond 90 who runs the same deep update gets +3 (→93), which feels reasonable.

The 2026-06-01 grilling concluded that **the discrepancy is not a calibration knob — it's a curve shape**. The same input should move the score a lot more at low bond than at high bond, because Bond Score is the existing relationship strength and the *marginal* bond-strength gained from a single interaction is naturally larger when the relationship is undeveloped.

## What changes

### Architectural split

The LLM judges interaction depth on its own merits. The code applies the diminishing-returns curve. Splitting these two concerns keeps the formula testable and the prompt focused.

- LLM emits `interactionDepth: integer 0..100`. The schema description anchors are: 0 = trivial / small talk / no new info; 25 = brief interaction with some content; 50 = a real conversation with new context; 75 = significant news, plans, or shared activity; 100 = deep day-long bonding or major life moment.
- Projection (in `LlmAiUpdate._projectOntoAiUpdateResult`) computes `bondScoreDelta = floor(interactionDepth × (100 − currentBondScore) / 160)`.
- `AiUpdateResult` gains a `bondScoreDelta: int` field that carries the projected delta forward.
- `AppController.applyAiUpdateResult` applies `result.bondScoreDelta` instead of the hardcoded `+3`. Clamps the resulting score to 0..100 (existing invariant).

### The curve

`delta = floor(depth × (100 − currentBond) / 160)`

Anchored to the user's two grilling points:
- bond 20, deep day-long update (depth=100) → +50 → 70.
- bond 90, deep day-long update (depth=100) → +6 → 96.

Reference table (depth × bond → delta):

| bond | depth=0 | depth=10 | depth=50 | depth=100 |
|---|---|---|---|---|
| 0 | +0 | +6 | +31 | +62 |
| 20 | +0 | +5 | +25 | +50 |
| 50 | +0 | +3 | +16 | +31 |
| 80 | +0 | +1 | +6 | +12 |
| 90 | +0 | +0 | +3 | +6 |
| 100 | +0 | +0 | +0 | +0 |

No `+1` floor when depth is non-zero. Diminishing returns means *exactly* that — at high bond, only big things move you. A floor would distort the curve.

### Mock parity

`MockAiUpdate` keeps a fixed `interactionDepth = 50`. With Mike's seed bond of 68, that's `floor(50 × 32 / 160) = +10`. Different from today's +3, but tests get rewritten.

### What stays invisible

The user does not see the depth or the delta in the AI Update preview. They see the score move on the profile after commit. Surfacing the math is a separate UX decision (rejected during grilling — see PRD addendum question 4 for rationale).

### What stays silent

Bond Tier crossings (e.g. 68 → 84 jumping from medium to high tier) happen silently. The Bond Ring color change on the profile is the only signal. Recommendations re-rank on the next read because the cache invalidates on memory change (already the case today; the new curve just makes tier-crossings happen more often).

## Acceptance criteria

- [ ] `LlmAiUpdateResponse.bondScoreDelta` field renamed to `LlmAiUpdateResponse.interactionDepth` (int 0..100). Schema constraint updated. JSON parsing updated. No backward-compat shim — single-device prototype scope per ADR-0003.
- [ ] `kLlmAiUpdateResponseSchema` description for `interactionDepth` reflects the 0/25/50/75/100 anchors.
- [ ] `kLlmAiUpdatePromptV1` rubric rewritten from 0..5 to 0..100 with the same anchors. `kLlmAiUpdatePromptVersion` bumps from 1 to 2 (a real prompt-shape change per #078's contract).
- [ ] `AiUpdateResult` gains `bondScoreDelta: int` (default 0 to preserve any test that constructs without it). The Mock and Llm adapters both populate it.
- [ ] `LlmAiUpdate._projectOntoAiUpdateResult` computes the curve via a new private helper `_applyBondScoreCurve(depth: int, currentBond: int) → int`. Helper is exported as `@visibleForTesting debugApplyBondScoreCurve` so the curve can be unit tested directly.
- [ ] `MockAiUpdate.run` populates `bondScoreDelta` with the curve output for `interactionDepth = 50` against the contact's current bond.
- [ ] `AppController.applyAiUpdateResult` reads `result.bondScoreDelta` instead of the hardcoded `+3`. The clamping to 0..100 stays.
- [ ] Tests in `test/state/ai/llm_ai_update_test.dart`:
   - `interactionDepth field round-trips through the response model`.
   - `_applyBondScoreCurve` returns the expected delta at each of the four anchor cells (bond=20/depth=100=+50, bond=90/depth=100=+6, bond=20/depth=0=+0, bond=100/depth=anything=+0).
   - Projection populates `bondScoreDelta` with the curve output for representative inputs.
- [ ] Tests in `test/ai/ai_update_test.dart`: `MockAiUpdate.run` populates `bondScoreDelta` correctly for the seeded bond values.
- [ ] Tests in `test/state/app_state_test.dart`: `applyAiUpdateResult` applies `result.bondScoreDelta` not `+3`. Includes a +0 path and a large-delta-clamps-to-100 path.
- [ ] `CONTEXT.md` Bond Score entry updated: replace `(+3, clamped)` with a one-line reference to the curve and a pointer to `LlmAiUpdate._applyBondScoreCurve`.
- [ ] PRD §Q6 rewritten to point at this issue and the 2026-06-01 addendum. The 0..5 rubric language is replaced.
- [ ] No existing widget test fails because of this change. (The five legacy `test/features/` failures from `ui-login-page` / `fix-navbar` UI merges are out of scope per AGENTS.md.)
- [ ] `flutter test test/state/` passes; the +18 LlmAiUpdate tests, the AppController tests, and the ai_update_test.dart legacy tests all stay green.
- [ ] `flutter analyze` clean for new files.

## Process

TDD strictly per AGENTS.md. Each AC item gets a failing test first, then implementation, then GREEN. Reviewer dispatch through the work → review → fix loop.

## Blocked by

None. #080 (LlmAiUpdate adapter) and #081 (production cutover) shipped on `main`; this is the deferred bondScoreDelta wiring + curve calibration on top of them.
