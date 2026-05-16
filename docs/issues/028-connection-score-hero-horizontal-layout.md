# ConnectionScoreHero: horizontal layout, score becomes page hero

Labels: enhancement, needs-triage

> *Created 2026-05-16 from Pass 1 of the home/people UI consistency grilling session.*

## Parent

PRD: pending — Pass 1 of "home/people UI consistency refinement" (issues 027–031).

## What to build

On the Home tab today, the `ConnectionScoreHero` card renders centered/stacked: a 120px BondRing on top, "Connection Score" label (`h2`, 21pt) below, caption below. The `SectionTitle('Today's Recommendation')` underneath uses `h1` (26pt), so the section title reads larger than anything inside the score card. Users perceive the score area as smaller than the recommendation block above it, even though the score is the page's headline metric.

Rebuild `ConnectionScoreHero` as a horizontal layout that makes the score number itself the page hero:

- Ring on the left at ~96px (down from 120px)
- Right column stacked:
  - Score number rendered at `display` (32pt) with tier label inline (e.g. `"78 · steady"` where the tier comes from `BondTier.from(score)`)
  - `bodyLg` subtitle "Average across all connections"
- Card stays a `CardBox` with the existing border/elevation
- Same input contract (`int score`)
- Same semantic label contract: still announces "Connection score: <n>, <tier>[, trending up]"

Net effect: the `display` number on the hero is larger than the `h1` section titles below it, restoring the intended hierarchy. The card's vertical footprint shrinks, so recommendations sit higher on first paint.

## Acceptance criteria

- [ ] `ConnectionScoreHero` lays out horizontally with ring on the left, score + subtitle on the right
- [ ] Score number renders at `AppTypography.display()` (32pt)
- [ ] Tier label appears inline with the score (close / steady / drifting per `BondTier.from`)
- [ ] Subtitle "Average across all connections" renders at `bodyLg` muted
- [ ] BondRing inside the hero is sized to ~96px
- [ ] Existing semantic label is preserved
- [ ] No regressions in Home tab widget tests; minimal updates if a test asserts old structural details
- [ ] `flutter analyze` clean
- [ ] `flutter test` green

## Blocked by

None — can start immediately.
