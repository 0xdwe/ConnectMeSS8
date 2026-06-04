# Bond Drift + Maintenance Need calibration PRD

Date: 2026-06-04

Issues: #090 calibration gate for #091, #093, #094, #095.

## Goal

Calibrate Relationship Graph maintenance behavior before product code. The design must keep Bond Score as relationship strength, not a raw activity streak, while still giving recommendations a humane sense of when a Connection could use attention.

## Core concepts

- **Bond Score** — stored 0..100 relationship strength on `Connection`. It changes slowly from meaningful interactions and bounded Bond Drift. It is not raw recency.
- **Maintenance Need** — derived recommendation urgency. It is not stored and does not mutate data. It can rise before Bond Drift applies.
- **Bond Drift** — bounded Bond Score decrease for Connections clearly outside their calibrated maintenance rhythm. It applies rarely through `AppController` only.

## V1 cadence buckets

Use category cadence buckets with a regular-rhythm fallback for unknown/custom categories.

| Connection category | Bucket | Base cadence |
| --- | --- | ---: |
| Family | close-rhythm | 14 days |
| Friends | regular-rhythm | 21 days |
| Work | professional-rhythm | 30 days |
| College | loose-tie | 45 days |
| High School | loose-tie | 45 days |
| Unknown/custom | regular-rhythm fallback | 21 days |

## Bond Score durability

Bond Score durability changes effective cadence and caps Bond Drift severity.

| Bond Score | Tier | Cadence multiplier | Drift cap |
| ---: | --- | ---: | ---: |
| 80–100 | close | 1.5 | -1 |
| 50–79 | steady | 1.0 | -2 |
| 0–49 | drifting | 0.75 | -3 |

Adjusted cadence is:

`(base category cadence × Bond Score durability multiplier).round()`

Use Dart `num.round()` after multiplication.

## Latest touch source

Cadence calculations use:

`latestTouchAt = max(Connection.lastContact, latest CrmInteraction.date for same Connection)`

If no CrmInteraction exists for the Connection, fall back to `Connection.lastContact`.

## Maintenance Need

Maintenance Need is derived from:

`elapsed since latestTouchAt / adjusted cadence`

| Ratio | Maintenance Need |
| ---: | --- |
| `< 0.75` | `none` |
| `>= 0.75 and < 1.0` | `low` |
| `>= 1.0 and <= 1.5` | `medium` |
| `> 1.5` | `high` |

Maintenance Need can become high before Bond Drift applies. It is for recommendation ranking and copy selection only; it is not stored and never mutates the Relationship Graph.

## Bond Drift

Bond Drift is bucketed and bounded, not continuous. Maximum per application is `-3` before caps. Drift buckets use the same ratio:

`elapsed since latestTouchAt / adjusted cadence`

| Ratio | Base Bond Drift |
| ---: | ---: |
| `< 1.5` | `0` |
| `>= 1.5 and < 2.0` | `-1` |
| `>= 2.0 and <= 3.0` | `-2` |
| `> 3.0` | `-3` |

Caps:

- Close tier caps at `-1`.
- Steady tier caps at `-2`.
- Drifting tier caps at `-3`.
- Work category caps at `-1` regardless of tier.

Bond Drift must never reduce Bond Score below 0.

## Application lifecycle

- `AppController` is the only Bond Drift application hook.
- `RecommendationEngine` never applies Bond Drift or mutates state.
- Apply Bond Drift only after `AppController` has current Connections and CrmInteractions snapshots.
- Enforce a 7-day minimum application window per Connection with `Connection.lastBondDriftAppliedAt`.
- Skip drift when `lastBondDriftAppliedAt != null && now - lastBondDriftAppliedAt < 7 days`.
- Persist the clamped `bondScore` change and `lastBondDriftAppliedAt = now` in the same existing `ConnectionStore` / `BatchedWrites` write path.
- Do not reapply drift from local optimistic or stale snapshots before the persisted timestamp is observed.
- A logged interaction naturally suppresses future drift because latest touch advances.

## MemoryDocument role

`MemoryDocument` signals do not affect v1 cadence or Bond Drift. They remain recommendation overlays and future personalization inputs.

Current/future recommendation overlays, such as `MemoryDocument.upcoming`, may outrank maintenance cards. They must not alter the cadence constants, Maintenance Need ratio, or Bond Drift buckets in v1.

## Copy guardrail

Proactive nudges and recommendation cards must not use numeric overdue/shame copy.

Allowed in proactive cards:

- “Want to check in on Sarah?”
- “Mike could use a quick hello.”
- “Wondering how Emily’s first week is going?”
- “A small note would go a long way.”

Rejected everywhere:

- “You neglected Sarah.”
- “Your relationship with Mike is decaying.”
- “Bond Score dropped because you haven’t talked.”

Neutral elapsed-time facts are allowed on user-pulled detail surfaces such as contact profile:

- “Last connected: 3 weeks ago”
- “Last interaction: Jan 12”

Never frame elapsed time as guilt or overdue failure.

## Implementation guidance

#091 should add a pure Relationship Maintenance policy module that accepts Connections, CrmInteractions, and an injected `now`, then returns adjusted cadence, latest touch, Maintenance Need, and candidate Bond Drift values without mutating.

#093 should call that policy from `AppController` and persist bounded Bond Drift through existing store/write patterns, atomically saving the clamped `bondScore` and `lastBondDriftAppliedAt = now` while respecting the 7-day idempotency gate.

#094 should rank regular recommendation cards by Maintenance Need while preserving special MemoryDocument overlay cards.

No implementation issue should choose new cadence constants, ratio buckets, drift caps, source-of-truth rules, or copy boundaries without reopening this calibration gate.
