# MemoryTopicEnricher single-contact enrichment

Labels: enhancement, ready-for-agent, pass-4.3-follow-up

## Parent

- PRD: `docs/prd/2026-06-13-memory-topic-backfill-prd.md`

## What to build

Add a memory-only AI enrichment seam for one Connection. Given a Connection, its current MemoryDocument, and recent CrmInteractions, the seam produces an enriched MemoryDocument with Gemini-ranked topics and topic-scoped Topic Suggestions. It must not use the normal AI Update commit path and must not create CrmInteractions, append history, or change Bond Score.

This slice proves the core enrichment behavior for one contact. It does not wire app-launch backfill or write the global backfill sentinel.

## Acceptance criteria

- [ ] A `MemoryTopicEnricher` seam exists with a production Gemini-backed adapter and deterministic test/fake path.
- [ ] The enricher accepts Connection, MemoryDocument, and recent CrmInteractions as source context.
- [ ] The enricher returns an updated MemoryDocument candidate; persistence remains outside the enricher.
- [ ] Returned topics are Gemini-ranked first and respect the existing MemoryDocument topic cap.
- [ ] Generic seeded starter topics are removed when better AI-ranked topics are returned.
- [ ] Non-generic existing topics may be preserved only after Gemini-ranked topics and only if room remains.
- [ ] Existing prepared Topic Suggestions are preserved by the higher-level eligibility policy; this slice must not overwrite fresh AI Update output in tests.
- [ ] Topic Suggestions are grouped by selected topic and capped to the existing shape.
- [ ] Suggestions are topic-scoped, gentle, and non-shaming.
- [ ] Tests prove no CrmInteraction is created, memory history is not appended, and Bond Score is not changed.
- [ ] Tests cover starter-topic removal, ranked ordering, non-generic preservation, blank/weak-context behavior, and prepared-suggestion preservation/skip policy.
- [ ] Targeted state/AI tests pass.

## Blocked by

None - can start immediately
