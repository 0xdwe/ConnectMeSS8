# Pass 3: delete ContactInsight.summary and .why; audit remaining fields

Labels: enhancement, needs-triage, refactor

## Parent

- Pass 3 PRD: `docs/prd/2026-05-19-per-contact-memory-files-v2-prd.md`
  (Q10 — `ContactInsight` cleanup)

## What to build

The Q10 cleanup landing once both replacement seams are in place.
With `MemoryDocument.summary` driving Person Summary (#040) and
`RecommendationEngine` driving "why now" copy (#047, #049),
`ContactInsight.summary` and `ContactInsight.why` no longer have
callers. Delete both fields.

Audit the remaining `ContactInsight` fields (`daysSinceContact`,
`frequencyTotal`, `_potentialGain`, etc.) at this seam: keep what
still has callers (the engine reads recency signals), delete what
doesn't. Document the audit in the PR description, or as code
comments where deletions happen.

Update or remove tests that hit deleted fields — assertions on
`.summary` move to `MemoryDocument.summary`; assertions on `.why`
move to engine output where they still make sense, otherwise delete.

## Acceptance criteria

- [ ] `ContactInsight.summary` and `ContactInsight.why` removed from
      the model and from `AppState.contactInsightFor`.
- [ ] Audit of remaining fields documented in the PR description (or
      as code comments where deletions happen): which are kept and
      why, which are deleted.
- [ ] Any tests asserting on `.summary` or `.why` either updated to
      assert on `MemoryDocument.summary` / engine output, or removed
      if redundant.
- [ ] No surface in the app references the deleted fields.
- [ ] `flutter analyze` clean. `flutter test` passes.

## Blocked by

- #040 (Person Summary must read memory first)
- #047 (engine must own "why now" copy first)
