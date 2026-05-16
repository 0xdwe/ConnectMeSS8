# People tab: normalize search/filter/sort typography for phone

Labels: enhancement, needs-triage

> *Created 2026-05-16 from Pass 1 of the home/people UI consistency grilling session.*

## Parent

PRD: pending — Pass 1 of "home/people UI consistency refinement" (issues 027–031).

## What to build

The top of the People tab has font-size mismatches that contribute to the "fonts not consistent" complaint:

- Search field's `prefixIcon` is size 34 and the hint text is styled as `AppTypography.h1()` (26pt). When the user starts typing the text shrinks to `bodyLg` (17pt) — a jarring drop.
- Filter row icon is size 32 next to chip labels at `body` (15pt).
- "Sort by:" label uses `h2` muted (21pt), the same size as card titles, so it competes with section headings.

Normalize to standard mobile sizing:

- Search `prefixIcon`: size 24
- Search hint text: `AppTypography.bodyLg()` (matches the input style, no shrink on type)
- Filter row icon: size 22
- "Sort by:" label: `AppTypography.caption()` (13pt) muted
- Chip labels: unchanged (`body`, 15pt)
- Filter and sort rows continue to scroll horizontally (no layout/wrapping change)

No behavior change — only sizing/typography.

## Acceptance criteria

- [ ] Search prefix icon renders at size 24
- [ ] Search hint uses `bodyLg` style; visually matches the input text size
- [ ] Filter row icon renders at size 22
- [ ] "Sort by:" label renders at `caption` muted
- [ ] Filter chips and sort chips still scroll horizontally
- [ ] No structural changes to the search/filter/sort behavior (query, category, sort selection)
- [ ] `flutter analyze` clean
- [ ] `flutter test` green

## Blocked by

None — can start immediately.
