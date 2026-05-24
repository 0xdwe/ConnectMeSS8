# #062 Pass 4.2 — #058 follow-up: recommendation cache auth-rebuild

Labels: bug, needs-triage

## Parent

docs/prd/2026-05-24-firebase-memory-store-pass-4-2-prd.md
docs/issues/058-auth-aware-memory-store-provider-rebuild.md

## Background

Adversarial review of the merged Pass 4.2 work (commit `69d346d`) surfaced two follow-ups against #058. The second one (a `currentUserProvider` self-invalidate loop that froze app launch on iOS as a white screen) was already promoted to a hotfix and shipped on `fix/current-user-provider-invalidation-loop` (commit `792fcdb`). What remains is the recommendation-cache invalidation gap.

### `recommendationsProvider` does not invalidate on auth-user swap

#058 AC4 reads:

> `memoryProvider`, `memoryTopicsProvider`, `recommendationsProvider` rebuild/invalidate on store identity changes.

`memoryProvider` and `memoryTopicsProvider` watch the right things. `recommendationsProvider` does not. Today (`lib/src/state/memory/memory_providers.dart`, the `RecommendationsNotifier.build()` method) it watches `appControllerProvider`'s connections + interactions and `memoryEpochProvider`. It does not watch `memoryStoreProvider` or `currentUserProvider`. After sign-out → sign-in-as-different-user, if connections/interactions stay object-identical (the `AppController` is not yet auth-aware) and nothing has bumped `memoryEpochProvider`, the cached recommendation list from user A can be served to user B.

The leak is bounded today only because `recommendationsProvider` still passes `memories: const {}` to the engine (the gap that #051 will close). Once #051 lands and real per-contact memory flows in, the cache becomes a real cross-user leak.

## What to build

Make `recommendationsProvider` invalidate on auth-user swap.

- Add `ref.watch(memoryStoreProvider)` (cheap — just rebinds on store identity change) or `ref.watch(currentUserProvider)` inside `RecommendationsNotifier.build()`.
- On rebuild, the existing `_cache = null` path through `build()` already discards the old result.

## Acceptance criteria

- [ ] After sign-out → sign-in-as-different-user, `recommendationsProvider`'s next read recomputes from scratch rather than serving the prior user's cached list.
- [ ] Test (a sibling of `test/state/memory/memory_store_provider_test.dart`) asserts the recommendation cache does not survive a user swap.
- [ ] `flutter analyze` clean. Default `flutter test` sweep stays at or above the current baseline.

## Blocked by

None — can start immediately. Most natural to land before #060 (production cutover) so the cross-user isolation claim is verified rather than asserted.

## Notes

- The companion #058 follow-up (`currentUserProvider` self-invalidate loop) shipped separately on `fix/current-user-provider-invalidation-loop` (commit `792fcdb`) because it was a production-launch blocker on iOS, not a deferrable refinement. The fix is now on the branch alongside a regression test (`test/state/firebase_providers_test.dart`).
- This is bookkeeping for #058, not a redesign. The remaining fix is a one-line `ref.watch` plus a test.
