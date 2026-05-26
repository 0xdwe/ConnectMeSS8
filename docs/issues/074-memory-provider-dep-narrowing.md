# #074 memoryProvider dep narrowing for recommendations cache invalidation tests

Labels: issue, needs-triage, follow-up

## Parent

docs/prd/2026-05-26-connection-persistence-pass-4-5-prd.md
docs/issues/070-app-controller-write-through-store.md (review S1)

## What to build

Narrow `memoryProvider`'s dep set so the two recommendations-cache invalidation tests at `test/state/recommendations_provider_test.dart` can re-enable.

## Background

Pass 4.5 #070 flipped `AppController.state.connections` to be a thin denormalization of the connection-store snapshot listener. Every save through `AppController` (or via the listener after a remote write) emits a fresh `connections` list with a different identity, even when content is unchanged. This invalidates `memoryProvider`'s in-flight future when the test's `memoryProvider('mike').future` is awaited during a save loop, causing the future to never resolve.

Two recommendations tests are skipped under the note `tracked: memoryProvider/connections-mirror interaction (#070 follow-up)`:

1. `AI update commit bumps memoryEpoch which invalidates recommendations cache` (`recommendations_provider_test.dart:265-310`)
2. `failed commit (failOnApply) still bumps the epoch — a transient extra recompute is acceptable per the rollback contract` (`recommendations_provider_test.dart:381-428`)

The contracts these tests covered (AI commit success → bondScore bump; AI commit failure → in-memory rollback) are independently asserted in `app_state_test.dart` at lines 173-209 and 540-589 respectively. The skipped tests specifically cover the chain through the recommendations cache, which is downstream of those upstream contracts. PRD §Q2 calls the recommendations-cache invalidation contract load-bearing.

## Two paths the reviewer suggested

### Cheap: narrow `memoryProvider`'s dep set
`memoryProvider` reads `connections` only to look up a display name on lazy creation. Pull the connection out before the await rather than watching the whole list:
```dart
final connection = ref.read(appControllerProvider).connections.firstWhere(...);
```
…if the lazy-create path actually needs it. Or pass the display name in via the family parameter.

### Cheaper: narrow the `select`
```dart
final connection = ref.watch(appControllerProvider.select(
  (s) => s.connections.firstWhere((c) => c.id == contactId, orElse: () => null),
));
```
Stops invalidating when an unrelated connection mutates.

## Acceptance criteria

- [ ] `memoryProvider` no longer watches the entire `connections` list when only one Connection's identity matters.
- [ ] The two skipped tests in `recommendations_provider_test.dart` are re-enabled (drop the `skip:` argument) and pass GREEN.
- [ ] `flutter test test/state/` count: 232 + 2 → 234 + 0 skipped.
- [ ] No regression in `app_state_test.dart` or `test/state/connections/`.
- [ ] `flutter analyze` clean.

## Blocked by

None. Pass 4.5 is shipped; this is post-#070 polish.
