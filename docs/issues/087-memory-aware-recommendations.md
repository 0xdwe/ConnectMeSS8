# 087 — Memory-aware recommendations from `MemoryDocument.upcoming`

## Parent

Pass 4.3 LLM AI Update PRD: `docs/prd/2026-05-27-llm-ai-update-pass-4-3-prd.md`

## What to build

Make Home and the recommendations screen use Gemini-written per-contact memory when ranking recommendations. `RecommendationEngine` already accepts a `memories` map and contains upcoming-driven card logic, but `recommendationsProvider` currently passes `memories: const {}`. Convert the provider to an async shape, load memories from `MemoryStore.listAll()`, pass them into the engine, and show stable loading placeholders until the final memory-aware list is ready.

This slice is limited to `MemoryDocument.upcoming`. Topic-based suggestions/recommendations are a separate design issue.

## Acceptance criteria

- [ ] `recommendationsProvider` returns an async recommendation value rather than a plain `List<Recommendation>`.
- [ ] The provider loads `MemoryStore.listAll()` and passes the returned map into `rankRecommendations`.
- [ ] Existing 6h freshness, `memoryEpochProvider`, auth/store, connections, and interactions invalidation semantics are preserved.
- [ ] If memory loading fails, recommendations silently fall back to recency-only engine output using `memories: const {}`.
- [ ] Home tab shows recommendation skeleton/loading placeholders while the async recommendation list resolves; it does not first show recency-only cards then reshuffle.
- [ ] Recommendations screen shows loading placeholders while the async recommendation list resolves.
- [ ] Upcoming-card copy is softened and remains anti-shame compliant:
  - post-trip: `Wondering how <Name>'s <description> went?`
  - pre-trip: `<Name>'s <description> is coming up.`
- [ ] Tests cover: provider surfaces an upcoming card from `MemoryDocument.upcoming`; load failure returns recency-only recommendations; cache avoids repeated `listAll()` inside the freshness window; memory epoch invalidates and reloads; Home / recommendations loading placeholders render.
- [ ] No numeric day counts are introduced in user-visible copy.

## Blocked by

None - can start immediately. Recommended after #086 for cleaner dev-console output.
