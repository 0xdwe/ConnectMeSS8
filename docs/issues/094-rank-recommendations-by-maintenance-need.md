# 094 — Rank recommendations by Maintenance Need

## Parent

Bond Drift + Maintenance Need design thread (2026-06-04)

## What to build

Update Recommendation ranking to use Maintenance Need from the Relationship Maintenance policy instead of raw recency alone. Recommendations should prioritize Connections that are outside their personalized maintenance rhythm while respecting Bond Score durability and existing Relationship Graph signals. This changes Recommendation ranking behavior, not Bond Score persistence.

## Acceptance criteria

- [ ] RecommendationEngine uses Maintenance Need from the policy module when ranking recency/maintenance-driven Recommendations.
- [ ] Raw `daysSince`-style recency is no longer the sole ranking signal for maintenance Recommendations.
- [ ] High-Bond Score, low-maintenance Connections receive appropriate grace according to #090 calibration.
- [ ] Recent CrmInteraction activity lowers Maintenance Need as expected.
- [ ] Existing upcoming-driven and MemoryDocument-aware Recommendation behavior remains intact unless #090 explicitly recalibrates priority.
- [ ] Recommendation copy preserves the anti-shame guardrail: no numeric day counts or guilt phrasing.
- [ ] RecommendationEngine ranking does not mutate `bondScore` or `lastBondDriftAppliedAt`.
- [ ] Add targeted tests for category cadence, Bond Score durability, recent interaction suppression, and ranking order.

## Blocked by

#091 — Add Relationship Maintenance policy module.
