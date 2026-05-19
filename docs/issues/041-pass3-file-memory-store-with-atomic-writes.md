# Pass 3: FileMemoryStore with atomic temp-file-then-rename writes

Labels: enhancement, needs-triage

## Parent

- Pass 3 PRD: `docs/prd/2026-05-19-per-contact-memory-files-v2-prd.md`

## What to build

The persistence layer behind the `MemoryStore` interface from the
walking skeleton (#040). Adds `FileMemoryStore` writing to
`<app_documents>/memories/<contactId>.md` via `path_provider`. Writes
are atomic: write to `<id>.md.tmp`, fsync, rename to `<id>.md`. This
atomic property is what makes the all-or-nothing failure contract
(#046) real on disk — if the rename fails, the previous file is intact
and `MemoryStore.save` throws, which is the signal the engine catches
to abandon the interaction commit.

Two new `pubspec.yaml` dependencies, both pinned: `path_provider` for
the documents directory, and `yaml` as a read-only frontmatter parser.
The renderer stays hand-written — no YAML writer dependency.

Production `memoryStoreProvider` swaps from `InMemoryMemoryStore` to
`FileMemoryStore`. Tests override with `InMemoryMemoryStore` via
`ProviderScope(overrides: [...])` per the existing Riverpod test
pattern.

Per-contact 64KB cap is enforced on save: when a write would exceed
the cap, drop oldest `History` bullets until the document fits.
Topics, Summary, Preferences, and Upcoming are preserved. The 16MB
global cap is a soft check at the same seam.

## Acceptance criteria

- [ ] `path_provider` and `yaml` added to `pubspec.yaml` with pinned
      versions.
- [ ] `FileMemoryStore` adapter implementing the `MemoryStore`
      interface from #040.
- [ ] Writes use atomic temp-file-then-rename. A failure between
      temp-write and rename leaves the previous file intact.
- [ ] Per-contact 64KB cap: when a save would exceed the cap, oldest
      `History` bullets are dropped until the document fits. Topics,
      Summary, Preferences, and Upcoming are preserved.
- [ ] Production `memoryStoreProvider` returns `FileMemoryStore` by
      default; tests can override with `InMemoryMemoryStore`.
- [ ] Memory persists across app restart: an update made in one
      session is readable on next launch.
- [ ] On second launch with seeded memories already on disk, the
      seed migration is skipped (verified by integration test or
      smoke test of the bootstrap path).
- [ ] Smoke test for `FileMemoryStore` using a temp directory: save →
      load round-trip; partial-write rollback; 64KB cap dropping
      oldest history.
- [ ] `flutter analyze` clean. `flutter test` passes including the
      new smoke test.

## Blocked by

- #040 (walking skeleton — `MemoryStore` interface and `MemoryDocument`
  model)
