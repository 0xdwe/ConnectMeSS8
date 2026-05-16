# BondRing: optional `showAvatar` parameter

Labels: enhancement, needs-triage

> *Created 2026-05-16 from Pass 1 of the home/people UI consistency grilling session.*

## Parent

PRD: pending — Pass 1 of "home/people UI consistency refinement" (issues 027–031).

## What to build

`BondRing` currently renders the connection's avatar emoji at the center when constructed from a `Connection`, and the numeric score when constructed via `BondRing.fromScore(...)`. On the People tab the same emoji shows up twice per row (large avatar on the left, ring on the right with the same emoji inside), which reads as repetitive.

Add an optional `showAvatar` boolean parameter to the `BondRing` default constructor. Default `true` (no caller change). When `false`, the connection-aware ring renders the numeric bond score in the center instead of the avatar emoji, while preserving every other connection-derived behavior:

- Tier-colored arc (close / steady / drifting) sized to `bondScore / 100`
- Trend arrow at 4 o'clock when `bondTrend` is up or down
- Animated arc on score change (and the existing reduced-motion fallback)
- Semantic label of the form `"<name>, <tier>[, trending up/down]"`

The number rendering should match the existing `BondRing.fromScore` font sizing (`size * 0.28`, weight 700) so the two numeric paths look identical.

## Acceptance criteria

- [ ] `BondRing(connection: …, showAvatar: false)` renders the numeric score, no emoji
- [ ] Trend arrow still appears at 4 o'clock when `bondTrend != flat`
- [ ] Tier color, arc fraction, and animation are unchanged from the avatar variant
- [ ] Semantic label still includes the connection's name and tier
- [ ] Default value `showAvatar: true` keeps every existing call site rendering exactly as before
- [ ] New widget test in `test/widgets/bond_ring_test.dart` (or equivalent) covering the `showAvatar: false` path with a `Connection` fixture
- [ ] `flutter analyze` clean
- [ ] `flutter test` green

## Blocked by

None — can start immediately.
