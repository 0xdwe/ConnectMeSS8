# 086 — Remove Pass 4.3 diagnostic logs

## Parent

Pass 4.3 LLM AI Update PRD: `docs/prd/2026-05-27-llm-ai-update-pass-4-3-prd.md`

## What to build

Remove the temporary debug logging added while diagnosing the 2026-06-01 Bond Score stall. The stall root cause was `AiUpdateScreen.save()` dropping `bondScoreDelta` while rebuilding `AiUpdateResult`; that fix shipped separately. The diagnostic logs are no longer needed in day-to-day dogfooding.

## Acceptance criteria

- [ ] Remove the temporary `LlmAiUpdate` interaction-depth / current-bond / delta `debugPrint`.
- [ ] Remove the temporary `AppController.applyAiUpdateResult` prior-bond / delta / next-bond `debugPrint`.
- [ ] Remove the temporary connection snapshot bond-summary `debugPrint`.
- [ ] Keep the `bondScoreDelta` preview forwarding fix intact.
- [ ] Keep targeted tests green for touched areas.

## Blocked by

None - can start immediately.
