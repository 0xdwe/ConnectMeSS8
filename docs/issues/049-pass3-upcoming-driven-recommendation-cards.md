# Pass 3: RecommendationEngine surfaces "just got back" / "trip starts tomorrow" from memory.upcoming

Labels: enhancement, needs-triage

## Parent

- Pass 3 PRD: `docs/prd/2026-05-19-per-contact-memory-files-v2-prd.md`
  (Q12 — time-bound events)

## What to build

The Q12 special-card path. `RecommendationEngine` reads
`MemoryDocument.upcoming` and emits a special recommendation card when
an entry's `endDate` (or `startDate` if no `endDate`) falls in the
window `[now - 3d, now + 1d]`.

The Mock updater leaves `Upcoming` empty by design — extracting
"tomorrow" / "for a week" deterministically is too brittle. The engine
logic is tested via fixture memory documents only.

Narrative copy patterns:

- Post-trip (`endDate` ∈ `[now - 3d, now]`):
  `"<Name> just got back from <description> — ask how it went"`.
- Pre-trip (`startDate` ∈ `[now, now + 1d]`):
  `"<Name>'s <description> starts tomorrow — wish them well"`.

The engine logic ships in Pass 3 even though the Mock can't trigger
it, so Pass 4 doesn't have to revisit the engine when the LLM gains
the ability to populate `Upcoming`.

Whether special cards rank above the bond-tier-weighted top 3 or
replace one of them is an implementation choice. Document the choice
in code comments next to the merge logic.

## Acceptance criteria

- [ ] Engine reads `MemoryDocument.upcoming` per contact.
- [ ] Entry triggers a special card when `endDate` (or `startDate` if
      no `endDate`) ∈ `[now - 3d, now + 1d]`.
- [ ] Special-card narrative copy follows the post-trip / pre-trip
      patterns above.
- [ ] Special cards may rank above the bond-tier-weighted top 3 or
      replace one of them — implementation choice documented in code
      comments.
- [ ] Unit tests with fixture memory documents covering: entry
      exactly at `now`; entry 1d in future; entry 3d in past; entry
      outside window; entry without `endDate`.
- [ ] No regression in #047 ranking when no `Upcoming` entries exist.
- [ ] `flutter analyze` clean. `flutter test` passes.

## Blocked by

- #047 (needs the engine to extend)
