# Pass 3: RecommendationEngine pure module, bond-tier-weighted ranking, 24h cooldown, replaces hardcoded getter

Labels: enhancement, needs-triage

## Parent

- Pass 3 PRD: `docs/prd/2026-05-19-per-contact-memory-files-v2-prd.md`
  (Q11 — ranking; absorbed candidate 3)

## What to build

A pure-function `RecommendationEngine` reading connections,
interactions, per-contact memory map, and `now`, returning a ranked
list of recommendations.

Q11 ranking formula:

- `score = daysSinceContact * tierWeight`
- `tierWeight = { drifting: 1.5, steady: 1.0, close: 0.8 }`
- Filter out connections with `daysSinceContact < 1` (24h cooldown —
  don't re-recommend someone you just talked to).
- Top N = 3.

The hardcoded `AppState.recommendations` getter is removed in this
slice. New `recommendationsProvider` recomputes on every read for now;
dual invalidation lands in #048. Home tab and recommendations screen
read from the new provider. Deleted-contact ids never surface — the
existing `recommendations_screen_stale_id_test.dart` regression
coverage carries over.

The Mock path generates deterministic narrative copy keyed off bond
tier and recency; no LLM copy. The future LLM path uses the same
ranking and only swaps in warmer narrative copy from memory context
for the top 3 — the math is shared so swapping adapters does not move
the recommendations.

Upcoming-driven cards are deferred to #049.

## Acceptance criteria

- [ ] `RecommendationEngine` exposes a pure function:
      `(connections, interactions, memories, now) → List<Recommendation>`.
- [ ] Q11 score formula and tier weights implemented exactly as
      specified.
- [ ] 24h cooldown filter excludes connections with
      `daysSinceContact < 1`.
- [ ] Returns top 3 by score descending.
- [ ] Mock narrative copy generation: deterministic for fixed
      `(connections, interactions, memories, now)`. Implementation
      chooses the recency bucketing internally; no numeric day counts
      or guilt-shaped phrases appear in the output (per the v2 PRD's
      anti-shame guardrail).
- [ ] `AppState.recommendations` getter deleted.
- [ ] `recommendationsProvider` added; recomputes on every read (no
      caching yet).
- [ ] Home tab and recommendations screen read from
      `recommendationsProvider`. Deleted-contact ids never surface
      (regression coverage from existing
      `recommendations_screen_stale_id_test.dart`).
- [ ] Unit tests covering: ranking on a fixture spanning all three
      bond tiers; 24h cooldown filter; deleted-contact exclusion;
      deterministic copy.
- [ ] `flutter analyze` clean. `flutter test` passes.

## Blocked by

- #040 (needs memory map plumbing — the engine reads memories)
