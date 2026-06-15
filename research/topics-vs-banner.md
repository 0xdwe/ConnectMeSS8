# Conversation Topics vs Recommendation Banner — Update Mechanisms

## Research question

Why might the conversation topics panel update after an AI Update while the recommendation banner does not?

## Files Retrieved

1. `lib/src/widgets/crm_widgets.dart` (lines 1107–1510) — `AiInsightsCard`, `_AiInsightsCardState`, `_AiInsightsBody`, `_AiInsightsBodyState`, and `_InlineTopicDetails` — the full UI subtree that renders both the recommendation banner and the conversation topics
2. `lib/src/features/contact_profile_screen.dart` (lines 1–100) — `ContactProfileScreen` consumer widget that drives the top-level data fetch and passes `memory` down as a prop
3. `lib/src/state/memory/memory_providers.dart` (lines 15–380) — `memoryEpochProvider`, `memoryProvider`, `recommendationsProvider`, `_recommendationsCacheProvider`, `memoryTopicsProvider`, `aiUpdateProvider.onMemoryWritten`
4. `lib/src/state/recommendation_engine.dart` (lines 26–205) — `rankRecommendations()` with completion detection (fast path #117 + fallback #115)
5. `lib/src/state/conversation_topics.dart` (lines 16–130) — `topicsForContact()`, `preferredSuggestionsForTopic()`, `_preparedSuggestionsForTopic()` — all pure functions
6. `lib/src/ai/llm_ai_update.dart` (lines 366–396) — `LlmAiUpdate.commit()` showing the order: save → `onMemoryWritten` → `applyAiUpdateResult`
7. `lib/src/ai/mock_ai_update.dart` — located in `lib/src/ai/ai_update.dart` (lines 307–345) — `MockAiUpdate.commit()` follows the same order
8. `lib/src/state/app_state.dart` (lines 61–69, 815–871) — `lastAiUpdatedContactId` field, `applyAiUpdateResult()`, `clearLastAiUpdate()`

---

## How each section gets its data

### Conversation Topics (topic pills + inline suggestions)

**Data flow:** Synchronous prop-driven chain.

```
ContactProfileScreen (ConsumerWidget)
  → ref.watch(memoryProvider(contactId))          ← FutureProvider.family
  → passes resolved MemoryDocument? as prop
    ↓
AiInsightsCard (ConsumerStatefulWidget)
  → passes widget.memory as prop
    ↓
_AiInsightsBody (StatefulWidget)
  → passes widget.memory as prop
    ↓
topicsForContact(connection, widget.memory)       ← pure function (line 1344)
  → reads memory?.topics or falls back to category defaults
    ↓
_InlineTopicDetails (ConsumerWidget)               ← line 1839
  → preferredSuggestionsForTopic(memory: widget.memory, ...)  ← pure function
  → reads memory.topicSuggestions (prepared AI suggestions)
```

**Invalidation trigger for `memoryProvider(contactId)`** (line 353):
```dart
ref.watch(memoryEpochProvider); // Trigger automatic reload when memory epoch changes
```
When any memory is saved, `memoryEpochProvider` bumps → `memoryProvider` is invalidated → refetches `store.load(contactId)` → resolves with fresh `MemoryDocument` → `ContactProfileScreen` rebuilds → `AiInsightsCard` gets new `memory` prop → `_AiInsightsBody` gets new `widget.memory` → `topicsForContact` and `preferredSuggestionsForTopic` see new data.

**Key characteristics:**
- No caching layer — every invalidation → refetch → rebuild
- Single-document fetch (`store.load(contactId)`)
- Pure functions of `MemoryDocument?` — no async computation needed after data arrives
- Data flows through Flutter's standard prop-drilling

---

### Recommendation Banner

**Data flow:** Async, provider-driven with caching.

```
_AiInsightsBodyState.build()
  → Consumer widget                                 ← line 1350
    → ref.watch(recommendationsProvider)            ← FutureProvider
      → filters list for widget.connection.id
      → renders banner if found
```

**`recommendationsProvider` definition** (lines 256–321):
```dart
final recommendationsProvider = FutureProvider<List<Recommendation>>((ref) async {
  final holder = ref.watch(_recommendationsCacheProvider);
  final store = ref.watch(memoryStoreProvider);
  final connections = ref.watch(appControllerProvider.select((s) => s.connections));
  final interactions = ref.watch(appControllerProvider.select((s) => s.interactions));
  final memoryEpoch = ref.watch(memoryEpochProvider);       // invalidation trigger
  final clock = ref.read(clockProvider);
  final now = clock();

  // 5-condition cache freshness check
  final cache = holder.cache;
  final isFresh =
      cache != null &&
      now.difference(cache.computedAt) < recommendationsFreshness &&   // 6h window
      (memoryEpoch == null || !memoryEpoch.isAfter(cache.computedAt)) && // epoch check
      identical(cache.store, store) &&
      identical(cache.connections, connections) &&
      identical(cache.interactions, interactions);

  if (isFresh) return cache.list;           // ← Serves cache, no recompute

  // Cache is stale → reload all memories + rerank
  Map<String, MemoryDocument> memories;
  try {
    memories = await store.listAll();       // ← All docs, not single doc
  } catch (_) {
    memories = const {};
  }

  // Read one-shot completion signal
  final lastAiUpdatedContactId = ref.read(appControllerProvider).lastAiUpdatedContactId;

  final list = rankRecommendations(
    connections: connections,
    interactions: interactions,
    memories: memories,
    now: now,
    previousList: lastRecommendationList,           // module-level variable
    previousCacheTime: holder.cache?.computedAt ?? ...,
    lastAiUpdatedContactId: lastAiUpdatedContactId,  // completion signal
  );

  // Update cache
  holder.cache = _RecommendationsCache(
    computedAt: now, list: list,
    store: store, connections: connections, interactions: interactions,
  );
  lastRecommendationList = list;

  // Consume signal so it doesn't fire twice
  if (lastAiUpdatedContactId != null) {
    ref.read(appControllerProvider.notifier).clearLastAiUpdate();
  }

  return list;
});
```

**Cache holder** (lines 243–254) — survives provider auto-dispose:
```dart
class _RecommendationsCacheHolder { _RecommendationsCache? cache; }
final _recommendationsCacheProvider = Provider<_RecommendationsCacheHolder>(
  (_) => _RecommendationsCacheHolder(),
);
```

**Key characteristics:**
- Multi-condition cache (time, memory epoch, store identity, connections identity, interactions identity)
- ALL-document fetch (`store.listAll()`) — not just the updated contact
- Complex ranking pipeline: upcoming cards → maintenance need scoring → tie-breaking → completion detection
- Completion signal (`lastAiUpdatedContactId`) read once via `ref.read`, then consumed (`clearLastAiUpdate`)
- Module-level `lastRecommendationList` survives Provider disposal for cross-recomputation diffing

---

## Critical architectural differences

### 1. Synchronicity

| Aspect | Conversation Topics | Recommendation Banner |
|--------|-------------------|----------------------|
| Data resolution | Synchronous (pure function on `MemoryDocument?`) | Async (`FutureProvider` with `store.listAll()` + `rankRecommendations()`) |
| Post-invalidation | Resolved before widget renders | May be in `AsyncLoading` state during transition |
| Widget sees | Immediate new data | May briefly show loading/old state |

### 2. Data granularity

- **Topics**: reads ONE document — `store.load(contactId)` — the specific contact being viewed
- **Recommendations**: reads ALL documents — `store.listAll()` — then filters. If the `listAll()` result is stale (Firestore cache), recommendations for ALL contacts could be stale while the single `load()` returns fresh data. On the Firestore SDK, `get()` without `GetOptions(source: Source.server)` uses cache-first-then-server. Single-document reads (`DocumentReference.get()`) are more likely to hit a recently-written doc in cache than collection queries (`CollectionReference.get()`), though both should work.

### 3. Caching

- **Topics**: `memoryProvider` has NO application-level cache. Every invalidation → refetch.
- **Recommendations**: `recommendationsProvider` has a 5-condition cache check. The cache survives provider disposal (stored in `_recommendationsCacheProvider`). Cache is served if ALL conditions pass.

### 4. Widget subscription pattern

- **Topics**: Uses Flutter's standard prop-drilling chain. `ContactProfileScreen` rebuilds → all children rebuild with new data via `didUpdateWidget`.
- **Recommendations**: Uses Riverpod's `Consumer` widget inside a non-Consumer `StatefulWidget`. The `Consumer` independently subscribes to `recommendationsProvider`. Creates its own `WidgetRef` scope. This should work — `Consumer` is designed for this — but it's a separate subscription mechanism from the parent rebuild cycle.

### 5. Completion detection pipeline

The `recommendationsProvider` has a "fast path" completion detection (#117) that injects `isCompleted: true` cards into the list:
- Signal set by `applyAiUpdateResult()` → `lastAiUpdatedContactId`
- Signal consumed by `recommendationsProvider` via `ref.read` → then `clearLastAiUpdate()`
- This signal is ONE-SHOT: if `recommendationsProvider` recomputes a second time (e.g., due to another invalidation), the signal is already consumed and completion detection falls back to the #115 path (checking for `aiSuggested` interactions)

The conversation topics have no equivalent complexity — they simply read `memory.topics`.

### 6. Commit order in `AiUpdate.commit()`

Both `MockAiUpdate` (`ai_update.dart:324–331`) and `LlmAiUpdate` (`llm_ai_update.dart:380–381`) follow the same order:
```
1. memoryStore.save(memory)
2. onMemoryWritten?.call()    → bumps memoryEpochProvider
3. appController.applyAiUpdateResult(result) → sets lastAiUpdatedContactId
```

This means `memoryEpochProvider` bumps BEFORE `lastAiUpdatedContactId` is set. However, because `recommendationsProvider` recomputes asynchronously (inside a `FutureProvider`), by the time `rankRecommendations` runs, `lastAiUpdatedContactId` has been set. In practice this works correctly.

---

## Potential failure modes

### Scenario A: Cache serves stale data after epoch bump
If `recommendationsProvider` is recomputed between the memory save and the profile navigation (e.g., on the AI Update screen itself), the cache gets a `computedAt ≥ memoryEpoch`. Then on the profile screen, `memoryEpoch.isAfter(computedAt)` is false → cache is fresh → serves the (correct, re-computed) data. **This is actually desired behavior.**

If `recommendationsProvider` was NOT recomputed after the save, `memoryEpoch.isAfter(cache.computedAt)` is true → cache is stale → recomputes. **Also correct.**

### Scenario B: Firestore cache divergence
- `store.load(contactId)` for topics reads a single doc → likely hits recently-written cached doc
- `store.listAll()` for recommendations reads entire collection → may have different cache state

If the collection query's local cache didn't pick up the recently-written document, the `memories` map passed to `rankRecommendations` won't include the updated memory for this contact, and the recommendation won't reflect new topics. Meanwhile, `memoryProvider(contactId)` (single doc) DOES return fresh data.

### Scenario C: Consumer widget doesn't rebuild on provider update
The `Consumer` is inside `_AiInsightsBodyState.build()`, which extends `State<StatefulWidget>` (not `ConsumerState`). The `Consumer` widget creates its own `WidgetRef` scope. Riverpod's `Consumer` tracks subscriptions and rebuilds when watched providers emit. This is standard and should work. However, there is a subtle difference in **when** the builder is called relative to the parent's `build()`: the `Consumer`'s rebuild is driven by Riverpod notifications, not by the parent's Flutter rebuild cycle.

### Scenario D: Completion signal race
If `recommendationsProvider` is recomputed twice (e.g., once on the AI Update screen, once on the profile), the first recomputation consumes `lastAiUpdatedContactId` via `clearLastAiUpdate()`. The second recomputation sees `null` and falls back to #115 (checking for `aiSuggested` interactions). If the new interaction hasn't reached the snapshot listener yet (because `applyAiUpdateResult` wrote through `BatchedWrites` and the snapshot listener hasn't emitted), the fallback won't find it → no completed card. The banner would show a non-completed recommendation (or no recommendation if the contact's maintenance need changed).

---

## Start Here

Open `lib/src/state/memory/memory_providers.dart` at line 256 (`recommendationsProvider`). This is the most complex piece — the 5-condition cache check, the `store.listAll()` call, the `lastAiUpdatedContactId` consumption, and the `rankRecommendations` call. Understanding the cache freshness logic is key to diagnosing any divergence between topics and recommendations.

Then open `lib/src/widgets/crm_widgets.dart` at line 1339 (`_AiInsightsBodyState.build`) to see how the `Consumer` watches `recommendationsProvider` in the same widget that also uses `topicsForContact(widget.memory)`.
