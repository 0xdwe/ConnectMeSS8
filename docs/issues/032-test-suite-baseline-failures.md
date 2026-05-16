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

## What to fix

1. Patch the typography test's `tearDownAll` so it does not block on
   `GoogleFonts.pendingFonts()` in offline test runs (likely: skip the
   await, or guard it on `kIsWeb`/test env, or replace with a
   `Completer().future.timeout(...)`).
2. Triage the ~13 failing widget tests. For each, decide: fix the
   underlying code, fix the test fixture, or document why the test is
   intentionally skipped under the current Flutter version.

## Acceptance criteria

- [ ] `flutter test` (full suite, no exclusions) completes in under
      2 minutes on a clean checkout.
- [ ] All tests pass, OR any intentionally skipped test is annotated
      with `@Skip('reason')` and documented in `progress.md`.
- [ ] `test/theme/app_typography_test.dart` no longer hangs.
- [ ] `flutter analyze` remains clean (1 known info-level lint at
      `lib/src/features/ai_update_screen.dart:87` is pre-existing and
      out of scope here).

## Blocked by

None — independent of feature work.

## Notes

This issue exists so the broken test baseline is visible and grabbable,
rather than rediscovered every time a new feature pass starts. Should be
picked up before Pass 2 (contact profile redesign) so that pass can
ship under the original "all tests green" bar.
