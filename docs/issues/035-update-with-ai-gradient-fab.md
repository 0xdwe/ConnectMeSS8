# Pass 2 — Replace inline Update with AI button with gradient FAB

Labels: enhancement, needs-triage

> *Created 2026-05-16 from the Pass 2 contact-profile-redesign grilling
> session.*

## Parent

Pass 2 slice 3 of 4.

## What to build

Replace the inline `FilledButton.icon` "Update with AI" on the contact
profile screen with a floating action button styled per the Figma
spec: a pill-shaped gradient button hovering over the bottom-right of
the screen.

### FAB anatomy

Flutter's `FloatingActionButton.extended` does not accept a gradient
directly (its `backgroundColor` is a single `Color`). Implement as a
custom shape using:

- A `Container` with `BoxDecoration(gradient: tokens.aiGradient)` (token
  from #033) and pill-shape `BorderRadius.circular(AppRadius.pill)`
- Wrapped in `Material(color: Colors.transparent)` for ink behavior
- An `InkWell` with matching border radius for the tap target
- Inner `Padding` and `Row` rendering a white sparkle icon
  (`Icons.auto_awesome`) and `Text('Update with AI', ...)` in white,
  bold, weight 600 or 700

Place via `Scaffold.floatingActionButton` with
`floatingActionButtonLocation: FloatingActionButtonLocation.endFloat`
(Material default for bottom-right, includes safe-area handling).

Tapping the FAB navigates to `/ai-update/<contactId>` — same target as
the inline button it replaces.

Touch target ≥ 48pt tall (Material guideline; the pill height should
not be smaller than 48 even on narrow screens).

### Removed in this slice

- The inline `SizedBox(width: double.infinity, child: FilledButton.icon(...))`
  block currently rendering "Update with AI" between the header and the
  facts card / history.

### Out of this slice

- Hero/transition animation between the FAB and the AI update screen
- FAB on any other tab or screen
- Adding the FAB to the planner or people tab (those are separate
  product calls, not Pass 2)

## Acceptance criteria

- [ ] The contact profile screen renders a gradient FAB at
      bottom-right (`endFloat`)
- [ ] FAB uses `tokens.aiGradient` from #033, not a hardcoded gradient
- [ ] FAB shows a white sparkle icon and "Update with AI" white label
- [ ] Tap navigates to `/ai-update/<contactId>`
- [ ] Inline `FilledButton.icon` "Update with AI" is removed from the
      screen body
- [ ] FAB tap target is ≥ 48pt
- [ ] Existing tests that tap "Update with AI" by label still pass
      (the label is the same, the position changed)
- [ ] FAB respects safe-area insets on iOS notched devices
- [ ] `flutter analyze` clean
- [ ] Per-commit verification bar: targeted tests pass, full sweep
      ≤ 12 baseline failures

## Blocked by

- #033 — needs `tokens.aiGradient`

## Notes

The custom gradient FAB pattern is small but worth keeping in one place
for reuse. Consider extracting it as a private widget in
`crm_widgets.dart` named e.g. `AiActionFab` so future surfaces (the
home tab, the planner, anywhere else "Update with AI" might float) can
reuse it without re-implementing the gradient + InkWell wrapping.
