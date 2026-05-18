# SectionTitle: responsive layout for narrow phones

Labels: bug, needs-triage

> *Created 2026-05-18 from a user-reported overflow on iPhone 16
> simulator: home tab's "Today's Recommendation" header rendered as
> "Today's Recommendatio\nn", cutting the trailing "n" mid-character.*

## Parent

None — independent regression follow-up to Pass 1.

## Problem

The `SectionTitle` widget at `lib/src/widgets/crm_widgets.dart` placed
its title (`AppTypography.h1()`, 26pt bold) inside `Expanded` next to
an optional action button in a single `Row`. On iPhone 16 (390pt
logical width):

- Page padding: 32pt × 2 = 64pt
- Title's own internal padding: 4pt × 2 = 8pt
- "View All ->" `TextButton`: ~110pt

Available width for the title: ~208pt. "Today's Recommendation" at h1
needs ~290pt. The string wraps, but "Recommendation" has no internal
spaces — Flutter falls back to mid-character break, producing
"Today's Recommendatio\nn".

Affects the home tab and the planner tab; any future caller of
`SectionTitle` with a long title would inherit the same problem.

## Fix

Two changes:

### A. Responsive `SectionTitle` layout via `LayoutBuilder`

When `constraints.maxWidth < 420` AND `title.length > 12`, lay the
action below the title in a Column. Otherwise keep the original Row.
This keeps short titles (`History`, `Plan`, `Settings`) on the same
row even on narrow phones, while long titles stack on phones and stay
inline on tablets.

Threshold tuning:
- 420pt: empirically the smallest constraint width where a 22-char h1
  title (`Today's Recommendation`) plus a typical action button fits
  without wrapping.
- 12 chars: covers all current short titles but keeps long titles
  (`Today's Recommendation` = 22, `Upcoming Events` = 15) on the
  stacked path.

### B. Replace `'View All ->'` literal arrow with `TextButton.icon`

The literal `->` ASCII arrow inside the home tab's `View All` button
adds three characters of width and uses non-typographic notation.
Switching to `TextButton.icon` with `Icons.arrow_forward` reduces the
button's footprint and uses Material's icon system. Cleaner regardless
of the layout fix.

## Acceptance criteria

- [ ] `SectionTitle('Today\'s Recommendation', action: TextButton(...))`
      renders without overflow on iPhone SE (320pt), iPhone 16 (390pt),
      iPhone 16 Pro Max (430pt), iPad Mini (768pt)
- [ ] On phone widths (<420pt) with a long title, the action stacks
      below the title left-aligned
- [ ] On tablet widths (≥420pt), the action sits inline to the right
- [ ] Short titles (≤12 chars) keep the Row layout regardless of width
- [ ] Home tab's "View All ->" text becomes a `TextButton.icon` with
      `Icons.arrow_forward` and label "View All"
- [ ] Existing planner SectionTitle (`'Upcoming Events'` + Create) still
      renders correctly across widths
- [ ] New `test/widgets/section_title_test.dart` covers 320 / 390 / 768
      and short-title / no-action cases
- [ ] `flutter analyze` clean
- [ ] Full test sweep stays at 0 failures

## Blocked by

None.

## Notes

The `LayoutBuilder` adds one extra layout pass per `SectionTitle`,
which is cheap. The threshold values are documented as constants on
`SectionTitle` for future tuning.
