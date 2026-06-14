# #117 — Synchronous Recommendation Completion via AppState

**Parent PRD:** `docs/prd/2026-06-14-recommendation-completion-prd.md`

---

## What to build

The recommendation completion detection currently depends on the Firestore snapshot listener delivering new `aiSuggested` interactions before the `recommendationsProvider` recomputes. Because `memoryEpochProvider` bumps synchronously during `AiUpdate.commit()` but the interaction save completes asynchronously, the provider often recomputes too early — seeing old interactions and missing the completion signal.

Fix: add a synchronous completion signal to `AppState` that bypasses the async timing.

### AppState changes

Two new fields on `AppState`:
- `lastAiUpdatedContactId` (`String?`, defaults `null`) — the contact ID of the last AI Update
- `lastAiUpdatedAt` (`DateTime?`, defaults `null`) — when that AI Update occurred

Both fields are in-memory only. They are set synchronously in `applyAiUpdateResult` and cleared (set to `null`) by the `recommendationsProvider` after the engine has consumed them (to prevent re-detection on the next recomputation).

### Engine changes

`rankRecommendations` gains a new optional parameter `String? lastAiUpdatedContactId`. When provided and non-null, the engine checks: was this contact in `previousList` and did the contact drop off the new list? If both conditions hold, emit a completed card directly — without needing to check for an `aiSuggested` interaction in the (potentially stale) interactions list.

This is the **fast path**. The existing interaction-based detection (checking `ix.source == aiSuggested` with `ix.date > previousCacheTime`) remains as the **fallback path** for cases where the contact dropped off for a reason other than this specific AI Update (e.g. Bond Drift caused the drop).

### Provider wiring

`recommendationsProvider` reads `lastAiUpdatedContactId` and `lastAiUpdatedAt` from `AppController.state`, passes them to `rankRecommendations`, then clears them by calling a mutating method on `AppController` (or directly resetting the state fields).

```dart
final state = ref.read(appControllerProvider);
final list = rankRecommendations(
  ...
  previousList: lastRecommendationList,
  previousCacheTime: ...,
  lastAiUpdatedContactId: state.lastAiUpdatedContactId,
);
// Consume the signal so it doesn't fire twice
if (state.lastAiUpdatedContactId != null) {
  ref.read(appControllerProvider.notifier).clearLastAiUpdate();
}
```

## Acceptance criteria

- [ ] `AppState.lastAiUpdatedContactId` and `lastAiUpdatedAt` fields exist
- [ ] `applyAiUpdateResult` sets them synchronously (contact ID + `DateTime.now()`)
- [ ] `AppController` has a `clearLastAiUpdate()` method that sets both to `null`
- [ ] `rankRecommendations` accepts optional `lastAiUpdatedContactId` parameter
- [ ] Fast path: when `lastAiUpdatedContactId` matches a contact in `previousList` that dropped off the new list, completed card is emitted
- [ ] Fallback path: existing interaction-based detection still works when `lastAiUpdatedContactId` is null
- [ ] `recommendationsProvider` reads and clears the signal after each recomputation
- [ ] At most 1 completed card per recomputation (fast path + fallback combined)
- [ ] Existing engine tests still green (37/37)
- [ ] New engine tests cover fast path (contact with matching ID + dropped off) and fast-path skip (different contact ID)
- [ ] New provider test: set `lastAiUpdatedContactId`, trigger recomputation, assert completed card appears
- [ ] `flutter test test/state/` green (493+)
- [ ] `dart analyze` clean

## Blocked by

None — can start immediately.
