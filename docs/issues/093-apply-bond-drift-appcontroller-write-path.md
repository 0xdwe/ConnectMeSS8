# 093 — Apply Bond Drift through AppController write path

## Parent

Bond Drift + Maintenance Need design thread (2026-06-04)

## What to build

Apply calibrated Bond Drift through the existing AppController write path so Bond Score can decrease in a bounded, personalized way when a Connection is outside its maintenance rhythm. Use the Relationship Maintenance policy from #091 and the persisted `lastBondDriftAppliedAt` timestamp from #092 to ensure repeated app opens or Recommendation refreshes do not repeatedly decay the same Connection.

## Acceptance criteria

- [ ] AppController invokes the Relationship Maintenance policy at the single authoritative lifecycle hook approved in #090 calibration notes.
- [ ] Bond Drift updates save both clamped `bondScore` and `lastBondDriftAppliedAt` through the existing ConnectionStore write path.
- [ ] Bond Drift is not applied more than once within the calibrated application window.
- [ ] Tests prove app-open plus Recommendation-refresh sequencing cannot double-apply Bond Drift.
- [ ] Bond Drift never bypasses existing Firestore/auth-aware store boundaries.
- [ ] Targeted tests cover first eligible drift, ineligible/no-drift cases, and repeated app open or refresh without repeated decay.
- [ ] User-visible copy, if any, preserves the anti-shame guardrail: no numeric day counts or guilt phrasing.

## Blocked by

#091 — Add Relationship Maintenance policy module.
#092 — Persist Bond Drift application timestamp.
