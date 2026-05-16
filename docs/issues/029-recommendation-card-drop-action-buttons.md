# RecommendationCard: drop bottom action button row

Labels: enhancement, needs-triage

> *Created 2026-05-16 from Pass 1 of the home/people UI consistency grilling session.*

## Parent

PRD: pending — Pass 1 of "home/people UI consistency refinement" (issues 027–031).

## What to build

`RecommendationCard` currently ends with a row of two buttons:

- "Update Connection" (`FilledButton`) — currently a TODO, no action wired
- "Open profile" (`TextButton`) — duplicates the card's own `onTap`, which already navigates to the contact profile

This adds ~80px of vertical chrome per card and competes with the new tighter `ConnectionScoreHero` for visual weight on Home. The whole card is already tappable via `onTap: () => context.push('/contact/<id>')`. "Update with AI" lives on the contact profile screen and gets a dedicated FAB in a future pass.

Remove the entire button row from `RecommendationCard`. The card keeps:

- Row 1: `BondRing` (56px) + name (`h2`) + category dot
- Row 2: conversational headline (`bodyLg`)
- Row 3: insight text (`body`, muted)

The whole card stays a single tap target via the existing `CardBox(onTap: ...)`.

## Acceptance criteria

- [ ] `RecommendationCard` no longer renders the action button row
- [ ] Tapping anywhere on the card still invokes the existing `onTap` (navigates to the contact profile)
- [ ] Any existing tests that tap "Update Connection" or "Open profile" by label/key are updated to assert card-tap navigation instead
- [ ] No new buttons or affordances added on this card
- [ ] `flutter analyze` clean
- [ ] `flutter test` green

## Blocked by

None — can start immediately.
