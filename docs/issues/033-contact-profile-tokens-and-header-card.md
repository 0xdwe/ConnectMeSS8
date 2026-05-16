# Pass 2 — Tokens + redesigned header card on contact profile

Labels: enhancement, needs-triage

> *Created 2026-05-16 from the Pass 2 contact-profile-redesign grilling
> session. Supersedes the older #017 framing.*

## Parent

PRD draft: `docs/prd/` will receive a Pass 2 PRD if needed; for now the
spec lives in this issue and its three siblings (#034, #035, #036).
Related historical issue: #017 (superseded by this slice).

## What to build

A vertical slice that lands four new design tokens and rebuilds the
contact profile screen's top header card. After this issue ships:

- The contact profile screen renders a redesigned header card with
  `tokens.primaryTint` surface, BondRing on the left, name + category
  dot + a one-line facts strip + an Edit pill on the right.
- The screen's AppBar drops its trailing Edit `IconButton` and becomes
  title-only.
- The inline `summary` line below the old header is removed (its content
  moves to Person Summary inside the AI Insights card in #034).
- The middle/bottom of the screen still renders today's components
  (inline FilledButton, `RelationshipFactsCard`, history list) — those
  are addressed by #034, #035, and #036.

The four tokens introduced here are dual-purpose: the header card uses
`primaryTint` (already exists), but #034 and #035 need the new tokens,
so they land here so siblings can pick up in parallel after this lands.

### Tokens added to `AppTokens`

- `aiGradient` — `LinearGradient` purple-to-indigo for the gradient FAB
  in #035 and any future "AI surface" element. Defined per theme.
- `recommendationSurface` — warm cream/yellow background for the
  Recommendation callout in #034.
- `recommendationBorder` — golden-yellow border for the same callout.
- `topicAccent` — terracotta/burnt orange (~`#E77E55`) used as the
  Conversation Topics pill fill in #034.

Each token gets light-mode and dark-mode values. Dark-mode picks should
be desaturated/dimmed equivalents (deep amber instead of pure cream,
slightly muted terracotta) so the screen reads correctly on a dark
canvas.

### Header card layout

Card surface: `tokens.primaryTint` (existing token). Wrapping `CardBox`
or equivalent so border-radius and elevation match the project system.

Left side:
- `BondRing(connection: person, size: 96)` — keep the existing avatar,
  arc, and trend arrow.

Right side, stacked:
- Row 1: `Text(person.name, style: AppTypography.display())` followed by
  a small `categoryColor`-tinted dot (radius 4) and the category label
  in `caption` muted, on one line.
- Row 2: a one-line "facts strip" caption combining
  `relationshipLabel · known X years · last contact <date>` in
  `AppTypography.caption(color: tokens.inkMuted)`. Use ` · ` separators
  matching the score-hero pattern.
- Row 3 (top-right of the card, not in the same column): a single
  Edit pill button (`OutlinedButton.icon` or equivalent) with white
  surface, `tokens.primary` text and pencil icon, label "Edit". Tapping
  it calls the existing `showEditConnectionModal(context, person)`.

Place Edit so it's clearly aligned to the top-right of the card; the
intent is "primary identity action lives in the header" not a separate
button row.

### Out of this slice

- AI Insights card and all its subsections (#034)
- Gradient FAB replacing the inline button (#035)
- Dense history list (#036)
- Removing `RelationshipFactsCard` from the screen — defer to #034 when
  the AI Insights card replaces it visually. For this slice, leave it
  in place even though the facts strip duplicates its data; the
  duplication is short-lived.

## Acceptance criteria

- [ ] `AppTokens` exposes `aiGradient`, `recommendationSurface`,
      `recommendationBorder`, `topicAccent` for both light and dark
      themes
- [ ] Token tests in `test/theme/app_tokens_test.dart` (or equivalent)
      cover the new fields in both modes
- [ ] Contact profile screen header card uses `tokens.primaryTint`
      surface
- [ ] Header right side shows name (`display`), category dot + label,
      and the facts strip as one-line `caption`
- [ ] Header has a single Edit pill (white + purple text + pencil)
      that opens the existing edit modal
- [ ] AppBar on the contact profile screen is title-only — no trailing
      Edit IconButton
- [ ] The inline `summary` line that previously sat below the header
      is removed
- [ ] Long names truncate with ellipsis instead of overflowing on a
      narrow phone (320pt wide)
- [ ] Existing `recommendation_tap_test.dart`, contact-profile widget
      tests, and integration tests still pass (or are updated in this
      commit if a structural assertion needs to change)
- [ ] `flutter analyze` clean
- [ ] Per-commit verification bar (per #032 baseline): targeted test
      files pass, full sweep ≤ 12 failures

## Blocked by

None — can start immediately.

## Notes

This slice keeps the screen visually broken in the middle (old inline
button, old facts card, old summary copy still there alongside the new
header) until #034–#036 land. That is intentional. Each slice is small
and revertible. The whole-screen integration is the sum of all four
issues.
