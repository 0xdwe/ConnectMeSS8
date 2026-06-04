# 090 — Grill Bond Drift + Maintenance Need calibration

## Parent

Bond Drift + Maintenance Need design thread (2026-06-04)

## What to build

Run a design grill for calibrating Relationship Graph maintenance behavior before product code. Decide how Maintenance Need and Bond Drift should interpret Connection category, Bond Score durability, CrmInteraction recency, and relationship-specific expectations without turning Bond Score into a raw activity streak. This issue produces PRD / calibration notes and follow-up implementation guidance; it does not require product code.

## Acceptance criteria

Calibration notes: `docs/prd/2026-06-04-bond-drift-maintenance-need-calibration-prd.md`.

- [x] Decide calibrated cadence buckets/labels by Connection category.
- [x] Decide how high Bond Score durability changes effective cadence and Bond Drift severity.
- [x] Decide decay buckets or equivalent aggressiveness rules for Bond Drift.
- [x] Decide how Maintenance Need differs from Bond Score and Bond Drift in user-facing behavior.
- [x] Decide whether MemoryDocument signals can inform future cadence personalization, while keeping v1 implementable.
- [x] Preserve the anti-shame guardrail: no numeric overdue/shame copy in proactive nudges; neutral elapsed-time facts are allowed on user-pulled detail surfaces.
- [x] Write PRD or calibration notes that #091, #093, and #094 can implement without choosing new constants.

## Blocked by

None - can start immediately.
