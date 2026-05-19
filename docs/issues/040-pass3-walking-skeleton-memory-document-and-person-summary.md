# Pass 3: walking skeleton — MemoryDocument, in-memory store, profile reads memory.summary

Labels: enhancement, needs-triage

## Parent

- Pass 3 PRD: `docs/prd/2026-05-19-per-contact-memory-files-v2-prd.md`

## What to build

The minimum vertical slice that proves the four-layer architecture
lights up end-to-end. This is the walking skeleton: parser, store,
provider, profile read — all hooked together, none of them deep yet.

Adds the `MemoryDocument` immutable model with the full schema from
the PRD (frontmatter + `Summary`, `History`, `Preferences`, `Topics`,
and the new `Upcoming` section, since the parser must be total and
needs to round-trip every section it can encounter). Adds an
`InMemoryMemoryStore` adapter implementing the async `MemoryStore`
interface, plus `memoryStoreProvider` and `memoryProvider` (family by
contactId, async, lazy-creates an empty document via the store when
none exists). A filesystem-inferred seed migration runs once on
startup when the memories collection is empty: writes one
`MemoryDocument` per existing seeded `Connection`, populated from the
connection's seed `notes` and category-derived starter topics.

The contact profile screen's Person Summary swaps from reading
`ContactInsight.summary` to `MemoryDocument.summary` via
`memoryProvider`. That swap is the user-visible payoff for this slice.

What this slice deliberately does NOT do:
- No file persistence — `FileMemoryStore` is #041.
- No AI write path through memory — unified `AiUpdate` is #042.
- No real topic extraction — keyword extractor is #043.
- No `ContactInsight.summary` deletion — that cleanup is #050.

## Acceptance criteria

- [ ] `MemoryDocument` model with fields: `contactId`, `displayName`,
      `lastUpdated`, `version`, `summary`, `history`, `preferences`,
      `topics`, `upcoming` (list of `{startDate, endDate?, description}`),
      `parseErrors`.
- [ ] `MemoryDocument.parse(String)` is total — never throws on any
      input. Malformed frontmatter populates `parseErrors`; the rest
      of the document still parses.
- [ ] `MemoryDocument.render() → String` round-trips every parseable
      document losslessly.
- [ ] `MemoryDocument.empty(contactId, displayName)` constructor for
      fresh documents.
- [ ] `MemoryStore` async interface with `load`, `save`, `delete`,
      `listAll`.
- [ ] `InMemoryMemoryStore` adapter implementing the interface.
- [ ] `memoryStoreProvider` returning the in-memory store for now;
      the production swap to `FileMemoryStore` lands in #041.
- [ ] `memoryProvider` (family by `contactId`) returns the parsed
      document; lazy-creates an empty document via the store when none
      exists.
- [ ] Bootstrap path runs the seed migration when the memories
      collection is empty: writes one `MemoryDocument` per existing
      seeded `Connection`, populated from the connection's seed
      `notes` and category-derived starter topics.
- [ ] Contact profile Person Summary reads `MemoryDocument.summary`
      via `memoryProvider`. (`ContactInsight.summary` removal is
      deferred to #050.)
- [ ] Unit tests: `MemoryDocument` round-trip on a full document;
      missing optional sections; malformed frontmatter populates
      `parseErrors`; empty file produces an empty document; `Upcoming`
      entries with and without `endDate` round-trip;
      `InMemoryMemoryStore` save / load / delete / `listAll` tests;
      `memoryProvider` lazy-creates on null.
- [ ] `flutter analyze` clean. `flutter test` passes.

## Blocked by

None - can start immediately.
