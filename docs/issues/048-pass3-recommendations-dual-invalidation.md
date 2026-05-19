# Pass 3: recommendationsProvider lazy with dual invalidation (memory-change OR 6h elapsed)

Labels: enhancement, needs-triage

## Parent

- Pass 3 PRD: `docs/prd/2026-05-19-per-contact-memory-files-v2-prd.md`
  (Q2 — recommendations invalidation)

## What to build

The Q2 caching policy. `recommendationsProvider` caches a
`(computedAt, List<Recommendation>)` tuple. On read, recomputes when
**either** any contact's `MemoryDocument.lastUpdated` is newer than
`computedAt`, **or** `now - computedAt > 6h`. Otherwise serves from
cache.

Reads on Home and the recommendations screen are what trigger the
freshness check. No background scheduler. The 6h window is a named
constant for easy tuning (2h–24h is a reasonable range).

## Acceptance criteria

- [ ] `recommendationsProvider` holds a cache tuple
      `(computedAt, List<Recommendation>)`.
- [ ] Recompute triggers when any contact's memory `lastUpdated` is
      newer than the cache's `computedAt`.
- [ ] Recompute triggers when `now - computedAt > 6h`.
- [ ] Cache is served when neither condition is met.
- [ ] The 6h window is a named constant for easy tuning.
- [ ] Unit tests: memory-change invalidation triggers recompute; 6h
      elapsed triggers recompute (use injectable clock or `DateTime`
      argument); neither met → cache returned without re-running the
      engine.
- [ ] Integration test: an AI update on a contact triggers the Home
      recommendations recompute on next read.
- [ ] `flutter analyze` clean. `flutter test` passes.

## Blocked by

- #047 (needs the engine and provider to exist before adding caching)
