# 092 — Persist Bond Drift application timestamp

## Parent

Bond Drift + Maintenance Need design thread (2026-06-04)

## What to build

Persist an optional `lastBondDriftAppliedAt` timestamp on Connection so Bond Drift can be applied safely without repeated score drops on repeated app opens or Recommendation refreshes. Update the local model, Firebase mapper, Firestore rules, and tests while preserving existing Connection and Relationship Graph behavior for old documents without the field.

## Acceptance criteria

- [ ] Add optional `lastBondDriftAppliedAt` to the Connection model without breaking existing constructors, copies, or seeded data.
- [ ] Update Firebase Connection mapping to read and write `lastBondDriftAppliedAt` when present.
- [ ] Update Firestore rules/tests to allow the optional timestamp while continuing to reject invalid Connection shapes.
- [ ] Ensure old Firestore Connection documents without `lastBondDriftAppliedAt` remain valid.
- [ ] Add targeted Dart model/mapper tests and Firestore JS rules tests for absent, valid, and invalid timestamp cases.
- [ ] Do not apply Bond Drift or mutate Bond Score in this issue.

## Blocked by

None - can start immediately.
