# Test suite baseline failures: typography hang + 13 widget failures

Labels: bug, needs-triage, test-infra

> *Created 2026-05-16 from the Pass 1 worker pre-flight. Baseline-broken
> state confirmed at HEAD with a clean working tree.*

## Parent

None — this is independently scoped maintenance, surfaced during Pass 1
implementation when the worker discovered the test suite cannot be brought
to green by Pass 1 alone.

## Problem

`flutter test` does not pass at HEAD on a clean working tree. Two distinct
pre-existing problems:

### 1. `test/theme/app_typography_test.dart` hangs indefinitely

The suite includes:

```dart
tearDownAll(() async => await GoogleFonts.pendingFonts());
```

In offline test environments, `GoogleFonts.pendingFonts()` never resolves,
even though `test/flutter_test_config.dart` claims to disable HTTP font
fetching. The full `flutter test` run hangs for 9+ minutes on this file
and never completes. Last touched in commit `78bb906 feat(typography):
Inter font via google_fonts (#010)`.

### 2. ~13 widget tests fail at HEAD

With the working tree fully stashed, `flutter test` (excluding the hanging
typography suite) reports ~13 failing tests. Representative example:
`test/widget_test.dart > "settings can add custom event type"` throws
`Bad state: No element` from `WidgetTester.showKeyboard`. These appear to
be Flutter test framework / fixture issues, not application logic
regressions.

## Impact

- Pass 1 (issues #027–#031) cannot satisfy a literal "all tests green"
  acceptance bar. Pass 1 ships under a relaxed bar: per-commit targeted
  subset + final no-new-failures sweep.
- Future PRs inherit the same problem until this is fixed.
- CI signal value is reduced: a real regression introduced by a future
  change is hidden inside a noisy baseline.

## Status

**Partially resolved 2026-05-18 in commit `077ab33`.**

Root cause of problem 1 (typography hang) was missing Inter font assets
— `google_fonts` was attempting a runtime HTTP fetch which
`flutter_test_config.dart` blocks but never times out. Fixed by
bundling Inter as static `.ttf` files in `assets/fonts/` and wiring
them into `pubspec.yaml`. The font is shipped under the SIL Open Font
License 1.1 (license file included).

### Resolved
- `test/theme/app_typography_test.dart` no longer hangs. Goes from
  indefinite (>9 min) to passing in 23s. All 11 typography assertions
  pass.
- Full `flutter test` sweep now completes in under a minute (was
  impossible to complete before).
- Side effect: the running app now actually renders Inter on device
  instead of falling back to Roboto/SF.

### Residual: 12 widget-test failures

The 12 fixture failures are genuine and unrelated to the asset issue.
They persist after the font fix. Categorization:

**Group A — `WidgetTester.showKeyboard` `Bad state: No element` (1 test)**
- `test/widget_test.dart > settings can add custom event type` —
  the test taps a `Text` widget that's offset (396, 603) outside the
  800×600 root render tree, then calls `enterText` which fails because
  there is no `EditableTextState` to find. Fix likely needs a
  `tester.binding.setSurfaceSize(...)` larger viewport or a different
  finder that resolves to an on-screen target.

**Group B — Hit-test misses on Pass 2 redesigned contact profile (8 tests)**
Tests written against the pre-Pass-2 contact profile screen layout
still find widgets but tap-targets land on the wrong element after
the redesign:
- `test/features/recommendation_tap_test.dart > tapping a recommendation
  on Home opens the contact dashboard`
- `test/features/recommendation_tap_test.dart > tapping a recommendation
  on the recommendations screen opens the contact dashboard`
- `test/features/auth_screen_test.dart > valid signup updates profile and
  enters the main app`
- `test/widget_test.dart > profile button opens heatmap profile`
- `test/widget_test.dart > plus menu update connection opens AI update
  page`
- `test/widget_test.dart > contact profile shows insight summary in
  header` (assertion targets old inline summary line that #033 moved
  into Person Summary)
- `test/widget_test.dart > contact profile avoids overflow at narrow
  large text scale` (asserts old layout)
- `test/widget_test.dart > profile can be edited from settings` (taps
  the old AppBar Edit IconButton which #033 removed)

**Group C — Calendar fixture issues (4 tests)**
- `test/features/planner_calendar_test.dart > Calendar accessibility day
  cells have minimum 44pt touch target`
- `test/features/planner_calendar_test.dart > Calendar visual states
  today indicator shows filled primary circle`
- `test/features/planner_calendar_test.dart > Calendar visual states
  selected day (not today) shows primaryTint bg with primary ring`
- `test/features/planner_calendar_test.dart > Calendar visual states
  days with events show up to 3 dots`
- `test/features/planner_calendar_test.dart > Calendar typography
  day-of-week header uses caption style with inkMuted`

**Group D — BondRing animation timing (1 test)**
- `test/widgets/bond_ring_test.dart > BondRing Animation animates arc
  when score changes` — asserts the animation is at 0.5 mid-flight
  but observed 0.8. Animation curve change drift (`Curves.easeOutQuart`
  vs the test's expected curve) or a timing assumption change.

### Recommended next steps

Fix Group B by updating the affected widget tests to match the Pass 2
redesigned layout (most are 1–2 line assertion updates: find Edit pill
in header instead of AppBar IconButton; assert Person Summary instead
of inline summary line). Fixing Group B alone would knock the residual
from 12 to 4.

Group A and Group C need real fixture investigation. Group D is a
one-line tolerance update.

Acceptance criteria status:
- [x] `flutter test` (full suite, no exclusions) completes in under
      2 minutes on a clean checkout.
- [ ] All tests pass — 12 fixture failures remain (Groups A–D above).
- [x] `test/theme/app_typography_test.dart` no longer hangs.
- [x] `flutter analyze` remains clean (1 pre-existing info lint).

## Blocked by

None — independent of feature work.

## Notes

This issue exists so the broken test baseline is visible and grabbable,
rather than rediscovered every time a new feature pass starts. Should be
picked up before Pass 2 (contact profile redesign) so that pass can
ship under the original "all tests green" bar.
