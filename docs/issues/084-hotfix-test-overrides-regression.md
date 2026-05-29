# #084 Hotfix: test_overrides regression from PR #1

Labels: issue, needs-triage

**Status: shipped on `main` (commits `1209931` + merge `800f486`, 2026-05-29).** Filed retroactively so the audit trail in `docs/issues/` matches what's on `main`.

## Parent

None — pure hotfix, not under a PRD.

## What was wrong

PR #1 (`feature/settings-and-planner-redesign`, merged as commit `3412a76` on 2026-05-29) expanded `signedInDemoOverrides()` in `test/test_overrides.dart` to seed sample connections / interactions / events into the in-memory stores via fire-and-forget async `save()` calls:

```dart
final connections = InMemoryConnectionStore();
for (final c in SeederSampleSource.connections()) {
  connections.save(c);  // async, NOT awaited
}
```

Each `save()` triggered an async broadcast event on the snapshot stream. By the time tests read `memoryProvider`, the pending publishes invalidated `appControllerProvider.select((s) => s.connections)` mid-load, and 8 tests in `test/state/memory/` timed out at 30s each with:

> Bad state: The provider FutureProvider<MemoryDocument>(...) was disposed during loading state, yet no value could be emitted.

This dropped the documented `flutter test test/state/` baseline from **232 passed + 2 skipped** to **224 + 2 + 8 failed**, breaking AGENTS.md's discipline of "no regressions" baselines for any subsequent issue.

## What was done

Added a `@visibleForTesting` `seedSync(Iterable<T>)` method to the three in-memory stores (`InMemoryConnectionStore`, `InMemoryInteractionStore`, `InMemoryEventStore`). It populates the underlying map without setting `_mirror` and without firing `_publish()` — so:

- Late `snapshot()` subscribers see no replay event (the `onListen` callback only forwards when `_mirror != null`).
- AppController's snapshot subscription is not pushed by the helper.
- `state.connections` stays untouched during `ProviderContainer` setup.

`signedInDemoOverrides()` calls `seedSync` instead of `save()`. Tests rely on `AppState.seeded()` (the controller's initial build value) for sample contacts, which already carries the same set.

## Acceptance criteria (verified)

- [x] `flutter test test/state/`: **232 passed + 2 skipped, 0 failed.** Baseline restored.
- [x] `flutter test test/state/memory/memory_provider_test.dart`: **5/5 passed.** (Was 0/5.)
- [x] `flutter analyze`: 32 pre-existing infos / warnings (unrelated UI-merge drift); no new issues.
- [x] `seedSync` annotated `@visibleForTesting` so production code accidentally calling it would emit a lint.
- [x] Reviewer (`.agent-runs/test-overrides-hotfix-review.md`) verdict: APPROVE.

## Reviewer notes for follow-up

Reviewer flagged three nice-to-haves, all deferred:

1. `@visibleForTesting` annotation added before merge per the review.
2. Post-`seedSync` invariant divergence — `_store` populated but `_mirror` null, `snapshotSync()` returns null. No today-bug; docstring calls it out.
3. Branch name `fix/test-overrides-await-seed-saves` slightly misleading (the actual fix is "use a sync hatch that doesn't broadcast at all," not "await the saves"). Merge commit message dominates the historical record.

## Files changed

- `lib/src/state/connections/in_memory_connection_store.dart`
- `lib/src/state/connections/in_memory_event_store.dart`
- `lib/src/state/connections/in_memory_interaction_store.dart`
- `test/test_overrides.dart`

## Blocked by

None — was a hotfix, ran first in the AFK session.
