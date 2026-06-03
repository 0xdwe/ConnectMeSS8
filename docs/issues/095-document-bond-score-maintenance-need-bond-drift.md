# 095 — Update docs for Bond Score, Maintenance Need, and Bond Drift

## Parent

Bond Drift + Maintenance Need design thread (2026-06-04)

## What to build

Update project documentation to make the Relationship Graph maintenance concepts explicit after implementation. Clarify that Bond Score represents relationship strength, Maintenance Need represents Recommendation urgency, and Bond Drift is bounded score decrease outside a calibrated maintenance rhythm. Document how Connection, CrmInteraction, MemoryDocument, AppController, RecommendationEngine, and Firestore participate in the shipped behavior.

## Acceptance criteria

- [ ] Update `CONTEXT.md` with glossary entries for Maintenance Need and Bond Drift.
- [ ] Clarify the Bond Score glossary entry so it is not confused with raw recency or an activity streak.
- [ ] Document the AppController / policy / Firestore responsibility split for applying Bond Drift.
- [ ] Document how Recommendation ranking uses Maintenance Need.
- [ ] Update `progress.md` at closeout, or the relevant PRD/issue closeout notes, with shipped status and deferred follow-ups.
- [ ] Preserve the anti-shame guardrail in all docs and examples: no numeric day-count shame copy.

## Blocked by

#093 — Apply Bond Drift through AppController write path.
#094 — Rank recommendations by Maintenance Need.
