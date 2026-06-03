# 090 — Grill Bond Drift + Maintenance Need calibration

## Parent

Bond Drift + Maintenance Need design thread (2026-06-04)

## What to build

Run a design grill for calibrating Relationship Graph maintenance behavior before product code. Decide how Maintenance Need and Bond Drift should interpret Connection category, Bond Score durability, CrmInteraction recency, and relationship-specific expectations without turning Bond Score into a raw activity streak. This issue produces PRD / calibration notes and follow-up implementation guidance; it does not require product code.

## Acceptance criteria

- [ ] Decide calibrated cadence buckets/labels by Connection category.
- [ ] Decide how high Bond Score durability changes effective cadence and Bond Drift severity.
- [ ] Decide decay buckets or equivalent aggressiveness rules for Bond Drift.
- [ ] Decide how Maintenance Need differs from Bond Score and Bond Drift in user-facing behavior.
- [ ] Decide whether MemoryDocument signals can inform future cadence personalization, while keeping v1 implementable.
- [ ] Preserve the anti-shame guardrail: no numeric day counts or guilt phrasing in user-visible copy.
- [ ] Write PRD or calibration notes that #091, #093, and #094 can implement without choosing new constants.

## Blocked by

None - can start immediately.
