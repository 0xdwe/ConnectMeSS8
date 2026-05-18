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

### Residual: parallel-review pass 2026-05-18 + #032 cleanup

A parallel-review pass on 2026-05-18 (correctness + simplicity
reviewers, fresh context) confirmed **Pass 1 and Pass 2 have zero real
user-visible regressions** in the failing test set. Every failure is
one of: stale assertion against pre-redesign UI, fixture problem
(viewport/duplicate finder/wrong tab label), or pre-existing animation
bug from #021. The original "12 failures" list also included 3 tests
that were already passing at HEAD when the doc was written; the doc
was stale in that respect too.

The true residual was 9 failures. As of this commit, Fixes 1–5 (Group
C helper, Group B tap-test copy, Group B signup-username assertion,
Group B dead profile-button test, Group B picker-modal duplicate
finder) have been applied. What remains:

**Group A — viewport too small (1 test)**
- `test/widget_test.dart > settings can add custom event type` —
  Settings tab's "Manage Event Types" row lands at y≈603 in the
  default 800×600 test surface; `enterText` then fails because the
  field is offscreen. Fix is `tester.binding.setSurfaceSize(...)` to
  give Settings comfortable vertical room.

**Group D — BondRing first-score animation suppressed (1 test)**
- `test/widgets/bond_ring_test.dart > BondRing Animation animates arc
  when score changes` — `_isFirstBuild` flag in
  `lib/src/widgets/bond_ring.dart` suppresses the animation on the
  *first* score change after mount (subsequent changes animate fine).
  Pre-existing from #021. Cosmetic severity, but a real bug worth
  removing — small visible polish improvement (first score change
  now animates).

Both are addressed in follow-up commits in the same #032 chain. After
those land, the full sweep should be at 0 failures.

### History: original 12-failure breakdown (for reference)

The doc previously categorized the failures as:
- Group A (1) — viewport / `showKeyboard`
- Group B (8) — tests written against pre-Pass-2 contact profile
- Group C (5) — calendar fixture
- Group D (1) — BondRing animation timing

Three of the listed Group B tests (`contact profile shows insight
summary in header`, `contact profile avoids overflow at narrow large
text scale`, `profile can be edited from settings`) were actually
passing at HEAD when this doc was written; they are not part of the
actual residual. The remaining 5 Group B + 1 Group A + 5 Group C +
1 Group D = 12 listed, but the ground-truth count was 9.

The parallel-review pass also surfaced an unrelated finding worth a
follow-up: `ProfileScreen` and `HeatmapCard` are orphaned dead code
since #016 dropped their entry point. Captured in #037.

### Status: closed

As of 2026-05-18, all residual failures are resolved.

- Group C: helper updated to find `'Plan'` (commit `16bd3fc`)
- Group B drift: assertions updated to match Pass 2 copy
  (`e8481c3`, `5a6257c`)
- Group B dead test: `profile button opens heatmap profile` deleted,
  replaced by #037 follow-up (commit `c63c153`)
- Group B duplicate finder: picker-modal scope (commit `628a5ab`)
- Group A viewport: surface size 800×1200 (commit `0ca1c61`)
- Group D animation: `_isFirstBuild` flag removed from `BondRing`
  (commit `fff16ac`)

Acceptance criteria status:
- [x] `flutter test` (full suite, no exclusions) completes in under
      2 minutes on a clean checkout (~10s).
- [x] All tests pass — **169 passed, 0 failed**.
- [x] `test/theme/app_typography_test.dart` no longer hangs.
- [x] `flutter analyze` remains clean (1 pre-existing info lint at
      `ai_update_screen.dart:88`, out of scope).

## Blocked by

None — independent of feature work.

## Notes

This issue exists so the broken test baseline is visible and grabbable,
rather than rediscovered every time a new feature pass starts. Should be
picked up before Pass 2 (contact profile redesign) so that pass can
ship under the original "all tests green" bar.
