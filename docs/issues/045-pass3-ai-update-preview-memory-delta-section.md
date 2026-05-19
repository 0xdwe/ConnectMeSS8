# Pass 3: AI Update preview shows About <Name> ✨ memory delta; cancel discards both

Labels: enhancement, needs-triage

## Parent

- Pass 3 PRD: `docs/prd/2026-05-19-per-contact-memory-files-v2-prd.md`
  (Q5 — preview UX)

## What to build

The user-visible expression of the all-or-nothing contract. The Pass
2 AI Update preview screen gains a new section below the interaction
cards: **"About <Name> ✨"**.

The section shows additions only:

- Newly extracted topics highlighted (visually distinct from existing
  topics).
- A 1–2 line summary of what's being appended to the History section.

Read-only — no inline editing of the memory delta. The Pass 5 surface
that allows editing memory is explicitly out of scope.

The ✨ tag uses `primary` icon on `primary-tint` background per the
existing AI marker convention. Reduced motion
(`MediaQuery.disableAnimations`) replaces any highlight pulse with an
instant cut.

Cancel on the preview screen discards both the interaction additions
and the memory delta — neither persists. Save commits both atomically.
Engine-level enforcement of the all-or-nothing contract lands in #046;
this slice covers the UI surface.

## Acceptance criteria

- [ ] AI Update preview renders the "About <Name> ✨" section below
      the interaction cards when there is a memory delta to show.
- [ ] New topics extracted in this run are visually highlighted in
      the topics list.
- [ ] A 1–2 line preview of what's being appended to History is shown.
- [ ] Section is read-only — no inline editing of topics or history
      copy.
- [ ] ✨ tag uses `primary` on `primary-tint` background per existing
      AI markers.
- [ ] Reduced motion (`MediaQuery.disableAnimations`) collapses any
      highlight motion to instant.
- [ ] Cancel on the preview screen discards interactions and memory
      delta together at the UI seam — no persistence has happened yet
      (per #042's `AiUpdateResult` shape).
- [ ] Save commits both via the same code path. Engine-level
      atomicity for the commit path is enforced separately in #046.
- [ ] Widget test: preview shows "About <Name>" section after
      `MockAiUpdate.run`; new topics highlighted; cancel leaves no
      observable change in `memoryProvider` or
      `interactionsByContactProvider`.
- [ ] Accessibility: the section has a semantic label; the ✨ icon
      has a semantic description.
- [ ] `flutter analyze` clean. `flutter test` passes.

## Blocked by

- #043 (delta highlights newly-extracted topics, which requires
  #043's extractor)
