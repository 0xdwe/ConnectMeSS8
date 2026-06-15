# #115 — Recommendation Completion: Engine Detection & Model

**Parent PRD:** `docs/prd/2026-06-14-recommendation-completion-prd.md`

---

## What to build

Add recommendation completion detection to the engine. When a user completes an AI Update on a contact that was appearing as a top recommendation, the engine detects this on the next recomputation and emits a completed `Recommendation` card.

### Model changes

Two new optional fields on `Recommendation`:
- `isCompleted` (`bool`, defaults `false`)
- `completedAt` (`DateTime?`, defaults `null`)

Both are in-memory only — never persisted to Firestore.

### Engine changes

`rankRecommendations` gains an optional parameter `List<Recommendation>? previousList`. When provided, the engine compares old vs. new lists after ranking: any contact that was in `previousList` but is NOT in the new ranked list AND has a new `CrmInteraction` with `source == aiSuggested` whose `date` is after the previous cache's `computedAt` → produces a completed `Recommendation` with `isCompleted: true` and `completedAt: now`.

Completed cards keep their **original slot position** from `previousList`. If the original position was slot 0, the completed card becomes the new slot 0, pushing other cards down. At most 1 completed card per recomputation — if multiple contacts were acted upon, only the highest-ranked original slot produces a completed card.

### Provider wiring

The `recommendationsProvider` already reads the `_RecommendationsCacheHolder`. During recomputation, it passes `holder.cache?.list` as `previousList` to `rankRecommendations`. No new provider or seam needed.

## Acceptance criteria

- [ ] `Recommendation` model has `isCompleted` and `completedAt` fields
- [ ] `rankRecommendations` accepts optional `previousList` parameter
- [ ] Completed card emitted when: contact was in previousList, dropped off new list, has new `aiSuggested` interaction after cache time
- [ ] Completed card NOT emitted when interaction is `manual` source
- [ ] Completed card NOT emitted when contact is still in the new list
- [ ] Completed card keeps original slot position
- [ ] At most 1 completed card per recomputation
- [ ] Completed card NOT emitted without `previousList` (backward compatible)
- [ ] Existing engine tests still green (no regressions)
- [ ] New engine unit tests cover all detection paths
- [ ] `flutter test test/state/recommendation_engine_test.dart` green
- [ ] `dart analyze` clean

## Blocked by

None — can start immediately.
