# Orphaned ProfileScreen and HeatmapCard

Labels: enhancement, needs-triage, nice-to-have

> *Created 2026-05-18 from the parallel-review pass that confirmed
> Pass 1 and Pass 2 are regression-free. Surfaced while triaging the
> #032 residual failures.*

## Parent

None — independent triage decision.

## What this issue captures

`lib/src/features/profile_screen.dart` (ProfileScreen) and the
`HeatmapCard` widget in `lib/src/widgets/crm_widgets.dart` are still in
the codebase but have no UI entry point.

- The `/me` route is still wired in `connect_me_app.dart` GoRouter, but
  no widget anywhere in the running UI navigates to it.
- The `AppHeader` widget exposes a `profile-button` IconButton that
  routed to `/me`, but `AppHeader` itself is no longer instantiated by
  any screen since commit `62b06cb` (#016, three-tab IA refactor that
  moved settings behind the shell AppBar avatar).
- The shell AppBar avatar IconButton in `shell_screen.dart` routes to
  `/settings`, not `/me`.
- Test `widget_test.dart > 'profile button opens heatmap profile'` was
  the last reachable surface that exercised `ProfileScreen`. It was
  deleted in this commit's predecessor because the test depended on the
  vanished `profile-button` Key.

The parallel review (run 2026-05-18) flagged this as worth a separate
triage decision rather than silent deletion.

## Decision needed

Pick one:

1. **Delete the orphans.** Remove `lib/src/features/profile_screen.dart`,
   remove the `HeatmapCard` widget from `crm_widgets.dart`, remove the
   `/me` route from `connect_me_app.dart`, remove any seed data that
   only existed to power the heatmap. Lowest-cost path. Implies the
   feature was never important enough to keep alive.

2. **Restore an entry point.** Re-add a profile/heatmap affordance
   somewhere on the shell (probably the avatar IconButton, splitting
   profile-vs-settings into two destinations), reinstate the deleted
   widget test against a stable Key. Higher cost, requires a product
   call about whether the heatmap is part of the v1 product story.

## Acceptance criteria (for whichever path is chosen)

If option 1:
- [ ] `lib/src/features/profile_screen.dart` deleted
- [ ] `HeatmapCard` and `_HeatmapRow` removed from `crm_widgets.dart`
- [ ] `/me` GoRouter route removed
- [ ] Any seed data only used by `HeatmapCard` removed
- [ ] `flutter analyze` clean
- [ ] `flutter test` no new failures

If option 2:
- [ ] Shell exposes a stable, key-addressable entry point that opens
      `ProfileScreen`
- [ ] A widget test exercises that entry point (replacement for the
      deleted `profile button opens heatmap profile` test)
- [ ] `flutter analyze` clean
- [ ] `flutter test` no new failures

## Blocked by

None.

## Notes

This is a follow-up surfaced by parallel review during #032 residual
triage. Not on the critical path. Pick it up when the team decides
what the heatmap surface should be — either delete and free the code,
or commit to surfacing it again.

Severity: nice-to-have. The orphan code does not break anything; it
just rots unused.
