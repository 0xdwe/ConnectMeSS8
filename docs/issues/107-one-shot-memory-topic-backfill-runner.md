# One-shot memory topic backfill runner and sentinel

Labels: enhancement, ready-for-agent, pass-4.3-follow-up

## Parent

- PRD: `docs/prd/2026-06-13-memory-topic-backfill-prd.md`

## What to build

Wire a signed-in, one-shot, non-blocking backfill runner that enriches existing Connections after normal memory seeding completes. The runner scans eligible Connections whose MemoryDocument lacks prepared Topic Suggestions, calls MemoryTopicEnricher with MemoryDocument plus recent CrmInteractions, saves successful MemoryDocuments, and writes a versioned completion sentinel only when all eligible contacts succeed or are skipped.

This slice makes old Connections receive the feature automatically on app launch without blocking first frame.

## Acceptance criteria

- [ ] Backfill starts only after memory seeding finishes.
- [ ] Backfill is signed-in only and no-ops while signed out.
- [ ] Backfill is silent and non-blocking; the app shell does not wait on Gemini work before rendering.
- [ ] Eligibility is limited to contacts whose MemoryDocument has no prepared Topic Suggestions.
- [ ] Contacts with no useful memory text and no recent CrmInteractions are skipped without model calls.
- [ ] Recent CrmInteractions are bounded to the same 10-item horizon used by AI context.
- [ ] Backfill processes eligible contacts with concurrency 1 or equivalent tight API-pressure control.
- [ ] Successful enrichments are saved to MemoryStore and invalidate memory-dependent providers through the existing memory epoch mechanism.
- [ ] Completion sentinel `topicSuggestionsBackfillV1CompletedAt` is written only if all eligible contacts succeed or are skipped.
- [ ] If any eligible contact fails, no completion sentinel is written; already successful contacts are skipped on next run because they now have Topic Suggestions.
- [ ] Firestore user-document rules allow owner timestamp writes for `topicSuggestionsBackfillV1CompletedAt` and reject wrong types, cross-user writes, anonymous writes, and disallowed extra fields.
- [ ] Provider/orchestrator tests cover success, skip, partial failure retry behavior, signed-out no-op, non-blocking launch behavior, and second-run idempotency.
- [ ] JS Firestore rules tests cover the new sentinel field.
- [ ] Targeted state tests and JS rules tests pass.

## Blocked by

- #106 MemoryTopicEnricher single-contact enrichment
