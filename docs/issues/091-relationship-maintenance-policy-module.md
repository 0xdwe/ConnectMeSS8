# 091 — Add Relationship Maintenance policy module

## Parent

Bond Drift + Maintenance Need design thread (2026-06-04)

## What to build

Add a pure Relationship Maintenance policy module that calculates Maintenance Need and Bond Drift for a Connection using the calibrated rules from #090, recent CrmInteraction history, and an injected clock. The module should keep scoring math out of AppController, UI, Firestore stores, and Recommendation orchestration. This slice only adds pure policy behavior and tests; it does not write Bond Score changes to Firestore.

## Acceptance criteria

- [ ] Add a pure module for Relationship Maintenance policy.
- [ ] Expose a calculation path for Maintenance Need using Connection data, recent CrmInteraction history or latest interaction timestamp, and calibrated policy from #090.
- [ ] Expose a calculation path for Bond Drift using Connection data, recent CrmInteraction history or latest interaction timestamp, and calibrated policy from #090.
- [ ] Accept an injected `now`/clock input so tests and callers do not depend on wall-clock time.
- [ ] Keep the module independent of AppController, Firestore, Firebase Auth, and widget/UI dependencies.
- [ ] Add table-driven tests covering high-Bond Score durability, lower-Bond Score drift, category cadence differences, no-drift cases, and calibrated application-window boundaries.
- [ ] Do not persist `lastBondDriftAppliedAt` or mutate Bond Score in this issue.
- [ ] If the policy returns reason codes, keep them domain-coded rather than user-copy strings; UI copy remains responsible for anti-shame wording.

## Blocked by

#090 — Grill Bond Drift + Maintenance Need calibration.
