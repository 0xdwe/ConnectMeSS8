## Review: Recommendation Completion Detection — Correctness

**Files reviewed:**
- `lib/src/state/recommendation_engine.dart` — `rankRecommendations` completion detection block (lines 107–169)
- `lib/src/state/memory/memory_providers.dart` — `lastRecommendationList`, `previousCacheTime` fallback, `isFresh` cache check, `_RecommendationsCacheHolder` (lines 248–313)
- `test/state/recommendation_engine_test.dart` — completion detection test group (lines 1096–1422)

---

### Blocker: Operator precedence bug makes `ix.date == previousCacheTime` an independent condition

**File:** `lib/src/state/recommendation_engine.dart`, lines 127–133

```dart
final hasNewAiInteraction = interactions.any(
  (ix) =>
      ix.contactId == prev.contactId &&
      ix.source == InteractionSource.aiSuggested &&
      ix.date.isAfter(previousCacheTime) ||
      ix.date == previousCacheTime,
);
```

Due to Dart operator precedence (`&&` binds tighter than `||`), this parses as:

```
(ix.contactId == prev.contactId && ix.source == aiSuggested && ix.date.isAfter(previousCacheTime))
||
(ix.date == previousCacheTime)
```

The second disjunct (`ix.date == previousCacheTime`) stands **alone** — it is true for *any* interaction (from any contact, of any source) whose date exactly equals `previousCacheTime`. This bypasses the `contactId` and `aiSuggested` guards.

**Evidence from git history:** Commit `f59ca69` (`fix: recommendation completion detection on first read + exact-time match`) added the `|| ix.date == previousCacheTime` line with intent to accept `date >= previousCacheTime`, but placed it at the wrong precedence level. The commit message says: *"ix.date.isAfter(previousCacheTime) uses strict >, misses exact-time matches. Fix: also accept ix.date == previousCacheTime."*

**Intended expression:**
```dart
ix.contactId == prev.contactId &&
ix.source == InteractionSource.aiSuggested &&
(ix.date.isAfter(previousCacheTime) || ix.date == previousCacheTime),
```

**Practical impact:** Low but non-zero. `previousCacheTime` is a `DateTime` with microsecond precision from a prior `DateTime.now()` call. An interaction date matching it exactly is astronomically unlikely. However, the code is semantically wrong and could silently permit a false completion if any interaction happened to land on the exact microsecond. Cleaner fix: replace `isAfter || ==` with `!ix.date.isBefore(previousCacheTime)` (the idiomatic `>=` equivalent in Dart).

**Test gap:** No test covers the `ix.date == previousCacheTime` edge case with a non-aiSuggested or wrong-contactId interaction. The existing test *"completed card NOT emitted for manual source interaction"* has `ix.date = now - 30min` and `previousCacheTime = now - 1h` — these are not equal, so the `||` branch doesn't fire and the test passes. A test with `date == previousCacheTime` and `source = manual` would expose the bug.

---

### Note: Module-level `lastRecommendationList` can desync from cache on Provider disposal

**File:** `lib/src/state/memory/memory_providers.dart`, lines 253/311

```dart
List<Recommendation>? lastRecommendationList;   // line 253 — module-level
...
lastRecommendationList = list;                   // line 311 — set after every recomputation
```

And the cache-holder:
```dart
class _RecommendationsCacheHolder {
  _RecommendationsCache? cache;
}
```

**Problem:** `lastRecommendationList` is a module-level variable; `_RecommendationsCache` is scoped to a Riverpod Provider that is disposed on GoRouter navigation. When the Provider is recreated after navigation:

1. `holder.cache` = null (disposed)
2. `lastRecommendationList` = still the old list (module-level, survives disposal)
3. `previousCacheTime` = `now - 6h` (fallback, since cache is null)

Now `previousList` and `previousCacheTime` are **inconsistent**: the list was produced at some prior cache time T1, but the engine is told to look for interactions after `now - 6h`. The time window can be wrong in either direction:
- **Too wide:** if the user navigated away and returned quickly, `now - 6h` may be well before T1, potentially catching interactions that predate the original recommendations.
- **Too narrow:** if the user was away >6h, `now - 6h` may be after T1, potentially missing interactions in the gap.

**Practical impact:** Low. The UI flow has the AI Update screen pushed on the navigation stack (not a GoRouter route change), so the `recommendationsProvider` typically stays alive during the AI update flow. The desync mainly occurs if the user navigates away (triggering disposal) and then returns. Even then, the AI interaction must land in the window for a spurious completion to fire.

**Design smell:** The cache timestamp and the cached list should either both live at module level or both live in the cache holder. Having one survive disposal and the other not is fragile.

---

### Correct: Detection of contacts dropped from `previousList`

**File:** `lib/src/state/recommendation_engine.dart`, lines 105–108

```dart
final newContactIds = result.map((r) => r.contactId).toSet();
for (var i = 0; i < previousList.length; i++) {
  final prev = previousList[i];
  if (prev.isCompleted) continue;
  if (newContactIds.contains(prev.contactId)) continue;
```

Logic: build a set of contactIds in the new result (special + ranked), then iterate previousList in order. A contact is "dropped off" if its contactId is not in `newContactIds`. The `isCompleted` skip prevents re-detecting already-completed cards.

**Correct.** The set-lookup approach is O(n+m) and correctly identifies contacts that were recommended before but are absent from the new ranking. The guard against `isCompleted` cards prevents double-completion.

**Note on interaction with upcoming cards:** `result` includes `special` (upcoming-driven cards) before Maintenance Need cards. If a contact was previously ranked by Maintenance Need but now appears as an upcoming card, their contactId is still in `newContactIds` — they haven't truly "dropped off." This is correct behavior.

---

### Correct: `aiSuggested` source check (modulo the precedence bug above)

The constraint `ix.source == InteractionSource.aiSuggested` correctly gates completion detection to only AI-suggested interactions (the ones created by `AiUpdate.commit`). Manual interactions do not trigger completions.

**Verified by test:** *"completed card NOT emitted for manual source interaction"* at recommendation_engine_test.dart:1164–1206.

---

### Correct: Slot position preservation

**File:** `lib/src/state/recommendation_engine.dart`, lines 154–159

```dart
final insertAt = i.clamp(0, result.length);
final updated = <Recommendation>[...result];
updated.insert(insertAt, completed);
return updated.take(3).toList(growable: false);
```

The completed card is inserted at the original slot position `i` from `previousList`, clamped to the new result's length. The `take(3)` cap then truncates if the insertion overflows.

**Correct.** The insertion preserves the card's original ranking position, and clamping prevents index-out-of-range. The combine-insert-spread-take pattern is clean.

**Verified by test:** The first completion test (line 1098) asserts `ranked[0].contactId == 'a'` and `ranked[0].isCompleted`, confirming position-0 insertion.

---

### Correct: At most 1 completed card per recomputation

**File:** `lib/src/state/recommendation_engine.dart`, line 160

```dart
return updated.take(3).toList(growable: false);
```

The `for` loop returns on the first match (`return` inside the `if` block), so at most one completed card is emitted per call.

**Verified by test:** *"at most 1 completed card per recomputation"* at line 1253: two contacts both have new AI interactions and both drop off, but only one completed card emerges (`completed.length, 1`).

---

### Correct: `isCompleted` skip prevents double-completion

**File:** `lib/src/state/recommendation_engine.dart`, line 108

```dart
if (prev.isCompleted) continue;
```

If a completed card from a previous run is still in `lastRecommendationList`, the loop skips it. This prevents:
- A completed card at position 0 being re-evaluated as "dropped off"
- A completed card from a previous recomputation being re-detected

**Correct.** The loop only processes non-completed entries.

**Edge case not in tests:** If `previousList` is `[completed_A, B]` and B drops off, the loop skips A (completed), processes B (not completed), and emits a completion for B. This is the intended behavior. No test covers this specific ordering, but the logic handles it correctly.

---

### Correct: `isFresh` cache check correctly invalidates on state changes

**File:** `lib/src/state/memory/memory_providers.dart`, lines 271–277

```dart
final isFresh =
    cache != null &&
    now.difference(cache.computedAt) < recommendationsFreshness &&
    (memoryEpoch == null || !memoryEpoch.isAfter(cache.computedAt)) &&
    identical(cache.store, store) &&
    identical(cache.connections, connections) &&
    identical(cache.interactions, interactions);
```

Five invalidation triggers:
1. **No cache** → recompute
2. **6h elapsed** → recompute
3. **Memory written since cache** (`memoryEpoch.isAfter(cache.computedAt)`) → recompute
4. **Store identity changed** (auth swap) → recompute
5. **Connections or interactions list identity changed** → recompute

**Correct.** The `memoryEpoch == null` guard handles the initial state (no writes yet → no invalidation from memory). The `identical` checks correctly detect list reference changes from the Riverpod `select` pipeline. The combined check ensures the AI update's effects (memory write + new aiSuggested interaction) always trigger recomputation, which is load-bearing for completion detection.

---

### Correct: `previousCacheTime` fallback handles null cache

**File:** `lib/src/state/memory/memory_providers.dart`, lines 297–300

```dart
previousCacheTime:
    holder.cache?.computedAt ??
    now.subtract(recommendationsFreshness),
```

When `holder.cache` is null (first launch or post-disposal), `previousCacheTime` falls back to `now - 6h`. This is a reasonable default: the 6h window matches the freshness boundary, and on first launch there are no previous recommendations to diff against anyway.

---

### Correct: Empty `previousList` and null `previousCacheTime` guards

**File:** `lib/src/state/recommendation_engine.dart`, line 104

```dart
if (previousList != null && previousCacheTime != null) {
```

Both parameters are optional. When either is null, the completion detection block is entirely skipped, falling through to `return result.take(3)`. The engine function signature allows callers to omit these parameters (backward compatibility).

**Verified by test:** *"completed card NOT emitted without previousList"* at line 1319.

---

### Correct: Fallback `Connection` for deleted contacts

**File:** `lib/src/state/recommendation_engine.dart`, lines 119–134

```dart
final contact = connections.firstWhere(
  (c) => c.id == prev.contactId,
  orElse: () => Connection(
    id: prev.contactId,
    name: prev.contactId,
    ...
  ),
);
```

If a contact that was previously recommended has been deleted from the connections list, the engine synthesizes a placeholder `Connection` with `name == contactId`. The completed card would read *"✓ Reached out to <contactId>"* — the raw ID rather than a display name.

**Acceptable.** A deleted contact won't typically have a fresh AI-suggested interaction (they'd need to have been deleted *after* the AI update but *before* the next recomputation, which is a narrow window). The fallback prevents a crash on `.firstWhere` and produces a degraded-but-acceptable display.

---

### Correct: `lastRecommendationList` survives Provider disposal

**File:** `lib/src/state/memory/memory_providers.dart`, lines 249–253

```dart
/// Module-level memory of the last recommendation list returned.
/// Survives Provider disposal during GoRouter navigation so
/// completion detection always has a previous list to diff against.
///
/// Exposed for testing only — production code should not read this
/// directly.
List<Recommendation>? lastRecommendationList;
```

The comment explicitly documents the design intent: survival across Provider disposal during navigation. This is achieved (module-level variable), though with the desync caveat noted above.

**Also correct:** The rename from `debugLastReturnedRecommendations` to `lastRecommendationList` (commit `bfac070`) removes the misleading `debug` prefix. The variable name now accurately reflects production usage.

---

## Summary

| # | Finding | Severity | Location |
|---|---------|----------|----------|
| 1 | **Operator precedence bug**: `\|\| ix.date == previousCacheTime` escapes the `&&` chain, making it an independent condition | **Blocker** | `recommendation_engine.dart:132` |
| 2 | `lastRecommendationList` (module-level) can desync from `holder.cache` (Provider-scoped) after Provider disposal | Note | `memory_providers.dart:253,271,311` |
| 3 | No test covers `date == previousCacheTime` with non-aiSuggested or wrong-contact interaction | Note | `recommendation_engine_test.dart` |
| 4 | Drop-off detection, slot preservation, 1-card cap, `isCompleted` skip — all correct | Correct | `recommendation_engine.dart:105–169` |
| 5 | `isFresh` cache check (5-invariant) correctly invalidates on all state changes | Correct | `memory_providers.dart:271–277` |
| 6 | `previousCacheTime` fallback (`now - 6h` when cache null) is reasonable | Correct | `memory_providers.dart:299` |
| 7 | `lastRecommendationList` renaming removes misleading `debug` prefix | Correct | `memory_providers.dart:253` |
