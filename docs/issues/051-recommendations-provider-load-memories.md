# Pass 4 wire-up: recommendationsProvider loads MemoryStore.listAll() into the engine's memories parameter

Labels: enhancement, needs-triage

> *Filed 2026-05-19 during Pass 3 wrap-up. Surfaces the production
> wire-up gap that #049 deliberately deferred.*

## Parent

- Pass 3 PRD: `docs/prd/2026-05-19-per-contact-memory-files-v2-prd.md`
  (Q12 — time-bound events)
- Closed issue: `docs/issues/049-pass3-upcoming-driven-recommendation-cards.md`

## Background

`#049` taught the `RecommendationEngine` how to surface
"just got back from <trip>" / "trip starts tomorrow" cards from
`MemoryDocument.upcoming`. The engine logic is fixture-tested and
production-ready.

What `#049` did NOT do: wire `recommendationsProvider` to actually
pass the per-contact memory map into the engine. Today the provider
calls `rankRecommendations(memories: const {})` because
`Notifier.build()` is sync and `MemoryStore.listAll()` returns a
`Future`. The engine has the capability; the production read path
never feeds it the data.

Pass 3 deferred this on purpose: `MockAiUpdate` doesn't populate
`memory.upcoming` (extracting "tomorrow" / "for a week"
deterministically is too brittle), so the production gap doesn't
show up until `LlmAiUpdate` lands and starts populating `Upcoming`
for real. Filing now so it isn't lost.

## What to build

`recommendationsProvider` aggregates the per-contact memory map and
passes it to `rankRecommendations`. Pick whichever of these shapes
fits cleanest:

- **A.** Async-ify `recommendationsProvider`. Becomes a
  `FutureProvider<List<Recommendation>>` (or a `NotifierProvider`
  whose `build` returns a `Future`). Reads
  `await store.listAll()` then calls the engine.
- **B.** Add a `memoryMapProvider` (a small async cache) and have
  `recommendationsProvider` watch it. The cache invalidates on the
  same `memoryEpochProvider` signal that already exists. Engine
  call stays sync; the provider waits on the cache.
- **C.** Keep the provider sync. Add a `MemoryStore.snapshot()`
  method that returns `Map<String, MemoryDocument>` from an
  in-memory mirror updated on every `save`/`delete`. The
  `FileMemoryStore` would maintain the mirror as a side-effect of
  reads/writes.

Whichever shape: the existing dual-invalidation logic from #048
must continue to work. Memory change still bumps `memoryEpoch`;
6h elapsed still triggers recompute.

## Acceptance criteria

- [ ] `recommendationsProvider` reads the per-contact memory map and
      passes it to `rankRecommendations` (no more `const {}`).
- [ ] Memory change still invalidates the cache on next read.
- [ ] 6h elapsed still invalidates the cache on next read.
- [ ] Production read path surfaces upcoming-driven cards when a
      contact's `MemoryDocument.upcoming` has an entry in the
      `[now - 3d, now + 1d]` window. (Demo path: hand-edit a memory
      file or seed one via test override.)
- [ ] Existing tests in `test/state/recommendations_provider_test.dart`
      still pass.
- [ ] New integration test pumps the AI update flow with a memory
      override carrying a populated `Upcoming` entry; asserts the
      special card surfaces on the home recommendations list.
- [ ] `flutter analyze` clean. `flutter test` passes.

## Blocked by

- None — can start immediately. Most natural to land alongside
  `LlmAiUpdate` in Pass 4 since that's when `Upcoming` actually
  gets populated for real, but the wire-up is independent and can
  ship sooner if the demo wants it.
