# ContactListCard: density pass + numeric ring

Labels: enhancement, needs-triage

> *Created 2026-05-16 from Pass 1 of the home/people UI consistency grilling session.*

## Parent

PRD: pending — Pass 1 of "home/people UI consistency refinement" (issues 027–031).

## What to build

`ContactListCard` on the People tab feels too tall and too padded for a phone, and long names truncate because the avatar (80px) and the right-side ring (72px) eat horizontal space. The right-side ring also renders the same emoji as the left-side avatar, which reads as repetitive.

Re-tune the card for phone density and switch the right-side ring to numeric:

- Card padding: `EdgeInsets.symmetric(horizontal: AppSpacing.space4, vertical: AppSpacing.space3)` (16h × 12v)
- Avatar `CircleAvatar` radius: 28 (56px), emoji rendered with `AppTypography.glyph(26)`
- Gap between avatar and text column: `AppSpacing.space4` (16)
- Name: `AppTypography.h2()` (unchanged — fits now that there's room)
- Email: demoted from `bodyLg` to `body` (15pt) muted
- Category `Chip` removed (category is already implied by tier color and is shown on the contact profile)
- Right-side `BondRing` size: 48px, with `showAvatar: false` (renders numeric score, preserves trend arrow)
- "Sample" pill behavior preserved when `connection.isSample`

## Acceptance criteria

- [ ] Card uses 16h × 12v padding via `AppSpacing` tokens
- [ ] Left avatar is 56px (radius 28) with `glyph(26)` emoji
- [ ] Email renders at `AppTypography.body()` muted (not `bodyLg`)
- [ ] Category Chip is no longer rendered on the row
- [ ] Right-side `BondRing` is 48px and uses `showAvatar: false` (numeric score, no emoji inside)
- [ ] Trend arrow still appears at 4 o'clock when present
- [ ] "Sample" pill still appears for `isSample` connections
- [ ] Long names no longer truncate on a 360pt phone width with a typical email
- [ ] Tests asserting the category Chip's presence are updated to assert its absence (or removed if no longer meaningful)
- [ ] `flutter analyze` clean
- [ ] `flutter test` green

## Blocked by

- #027 (BondRing `showAvatar` parameter) — required for the numeric right-side ring.
