# Pass 2 — Densify History into a single-card list with inline AI badge

Labels: enhancement, needs-triage

> *Created 2026-05-16 from the Pass 2 contact-profile-redesign grilling
> session.*

## Parent

Pass 2 slice 4 of 4.

## What to build

Today's history section on the contact profile renders one `CardBox`
per interaction — every history item gets its own elevated rounded
card. Alongside the new tighter header (#033) and the AI Insights card
(#034), the per-tile chrome reads as visually heavier than the AI
content above it. Consolidate the history section into a single card
holding a dense list of rows.

### Layout

- One `CardBox` with `padding: EdgeInsets.zero` (or equivalent — the
  inside owns its own padding)
- Inside the card, top: a `Padding`-wrapped section header row
  containing `Text('History', style: AppTypography.h2())` plus a small
  count badge or inline subtitle if the count is helpful (e.g.
  `'(${history.length})'` in `caption` muted). Optional — keep simple.
- Below the header, for each interaction:
  - `Padding(EdgeInsets.symmetric(horizontal: AppSpacing.space4, vertical: AppSpacing.space3))`
  - A `Row` with: type icon (left, `tokens.inkMuted`), title (`bodyLg`,
    `Expanded`), date in `caption` muted (right), optional AI badge
    (right, after the date).
  - The "AI" badge stays as today's pill (existing
    `tokens.primaryTint` background + sparkle + "AI" caption) but now
    renders inline at the row's right edge rather than above the row
- Between rows: `Divider(color: tokens.border, height: 1, thickness: 1)`
  with no horizontal indent
- No divider after the last row

### Empty state

Today the empty state renders a centered "first-name's new — you'll
fill this in over time" message. Keep it functional but render it
inside the new History card (one row's worth of padding, centered text)
rather than as a separate widget below.

### Out of this slice

- Date grouping ("This week", "Last month") between rows — deferred,
  not worth the complexity at current data volumes
- Tap-to-expand on a row — out of scope
- Filtering or sorting history — out of scope
- Changes to the underlying `CrmInteraction` data shape

## Acceptance criteria

- [ ] History section on the contact profile screen is one `CardBox`
- [ ] Rows separated by 1px `tokens.border` dividers, no per-row card
      chrome
- [ ] Each row shows: type icon + title + date + optional AI badge,
      single-line layout
- [ ] AI badge renders inline at the right of its row, not above
- [ ] Empty state renders inside the new card
- [ ] Long titles truncate with ellipsis instead of wrapping (single-
      line constraint)
- [ ] Existing tests that verify the AI badge presence still pass —
      the finder may need updating from a per-card position to
      per-row position
- [ ] `flutter analyze` clean
- [ ] Per-commit verification bar: targeted tests pass, full sweep
      ≤ 12 baseline failures

## Blocked by

None — independent of #033, #034, #035. Can run in parallel with the
others.

## Notes

This is the lightest of the four Pass 2 slices and the most isolated.
A worker can pick it up alongside #033 without conflicts (they touch
different regions of `contact_profile_screen.dart` and different parts
of `crm_widgets.dart`).
