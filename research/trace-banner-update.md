# Data Flow Trace: AI Update Completion → AiInsightsCard Banner

## Executive Summary

After an AI Update on a recommended contact, the conversation topics update dynamically but the recommendation banner stays frozen. Root cause: a race condition in `recommendationsProvider`'s dual-invalidation cache check. The `memoryEpoch`-triggered recomputation runs before the Firestore snapshot listeners deliver the updated connection/interaction data. The resulting stale cache passes all `isFresh` checks because `computedAt > memoryEpoch` and the list identities haven't changed yet. The Consumer serves the stale cache, so the banner shows the old recommendation until the snapshot listener eventually fires and triggers a second recomputation.

---

## Files Retrieved

1. **`lib/src/state/memory/memory_providers.dart`** (lines 1–313) — `recommendationsProvider`, `memoryEpochProvider`, `_RecommendationsCache`, cache invalidation logic
2. **`lib/src/state/app_state.dart`** (lines 1–500+) — `AppState`, `AppController.build()`, snapshot listeners, `applyAiUpdateResult`, `clearLastAiUpdate`
3. **`lib/src/ai/ai_update.dart`** (lines 100–340) — `MockAiUpdate.commit()`: memory save → onMemoryWritten → applyAiUpdateResult
4. **`lib/src/ai/llm_ai_update.dart`** (lines 360–410) — `LlmAiUpdate.commit()`: identical commit sequence
5. **`lib/src/ai/ai_update_commit_plan.dart`** (full, ~50 lines) — `buildAiUpdateCommitPlan`: builds the updated connection + interaction
6. **`lib/src/state/connections/batched_writes.dart`** (full, ~290 lines) — `FirebaseBatchedWrites.commitAiUpdate` and `InMemoryBatchedWrites.commitAiUpdate`
7. **`lib/src/widgets/crm_widgets.dart`** (lines 1200–1508) — `AiInsightsCard`, `_AiInsightsBody`, Consumer watching `recommendationsProvider`
8. **`lib/src/features/contact_profile_screen.dart`** (lines 60–320) — `ContactProfileScreen.build()`: wires `AiInsightsCard` with props from providers
9. **`lib/src/features/ai_update_screen.dart`** (lines 230–310) — `_AiUpdateScreenState.save()`: calls commit, then `Navigator.pop`
10. **`lib/src/app/connect_me_app.dart`** (lines 18–46) — GoRouter: flat `GoRoute` entries, no `ShellRoute` (pushed routes keep prior page alive)
11. **`lib/src/state/recommendation_engine.dart`** (full, ~300 lines) — `rankRecommendations`: completion detection fast path (#117) and fallback (#115)
12. **`lib/src/state/relationship_maintenance_policy.dart`** (full, ~180 lines) — `RelationshipMaintenancePolicy.evaluate`: `MaintenanceNeed.none` for ratio < 0.75

---

## Key Code

### 1. The `memoryEpochProvider` bump (memory_providers.dart:25–37)

```dart
// lib/src/state/memory/memory_providers.dart, lines 25-37
class MemoryEpochNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;
  void bump(DateTime now) => state = now;
}

final memoryEpochProvider = NotifierProvider<MemoryEpochNotifier, DateTime?>(
  MemoryEpochNotifier.new,
);
```

### 2. Where `onMemoryWritten` is wired (memory_providers.dart:122–130)

```dart
// lib/src/state/memory/memory_providers.dart, lines 122-130
final aiUpdateProvider = Provider<AiUpdate>((ref) {
  // ...
  return LlmAiUpdate(
    // ...
    onMemoryWritten: () {
      final clock = ref.read(clockProvider);
      ref.read(memoryEpochProvider.notifier).bump(clock());
    },
  );
});
```

### 3. The `commit()` sequence — LlmAiUpdate (llm_ai_update.dart:368–400)

```dart
// lib/src/ai/llm_ai_update.dart, lines 368-400
@override
Future<void> commit(AiUpdateResult result) async {
  final memory = result.memoryDocument;
  final priorMemory = memory == null ? null : await memoryStore.load(memory.contactId);

  if (memory != null) {
    await memoryStore.save(memory);          // STEP 1: save memory to Firestore
    onMemoryWritten?.call();                  // STEP 2: bump memoryEpochProvider
  }

  try {
    await appController.applyAiUpdateResult(result);  // STEP 3: write interaction + connection
  } catch (e) {
    // rollback...
    rethrow;
  }
}
```

### 4. `applyAiUpdateResult` (app_state.dart:328–348)

```dart
// lib/src/state/app_state.dart, lines 328-348
Future<void> applyAiUpdateResult(AiUpdateResult result) async {
  final plan = buildAiUpdateCommitPlan(result: result, connection: connection, now: DateTime.now());
  await ref.read(batchedWritesProvider).commitAiUpdate(       // STEP 3a: Firestore batch write
    interaction: plan.interaction,
    updatedConnection: plan.updatedConnection,
  );
  state = state.copyWith(                                       // STEP 3b: synchronous local state
    lastAiSummary: plan.summary,
    lastAiUpdatedContactId: result.contactId,                  // ← completion signal for #117
    lastAiUpdatedAt: DateTime.now(),
  );
}
```

### 5. The `recommendationsProvider` cache (memory_providers.dart:195–253)

```dart
// lib/src/state/memory/memory_providers.dart, lines 195-253
final recommendationsProvider = FutureProvider<List<Recommendation>>((ref) async {
  final holder = ref.watch(_recommendationsCacheProvider);
  final store = ref.watch(memoryStoreProvider);
  final connections = ref.watch(appControllerProvider.select((state) => state.connections));
  final interactions = ref.watch(appControllerProvider.select((state) => state.interactions));
  final memoryEpoch = ref.watch(memoryEpochProvider);
  final clock = ref.read(clockProvider);
  final now = clock();

  final cache = holder.cache;
  final isFresh =
      cache != null &&
      now.difference(cache.computedAt) < recommendationsFreshness &&
      (memoryEpoch == null || !memoryEpoch.isAfter(cache.computedAt)) &&  // ← line 221
      identical(cache.store, store) &&
      identical(cache.connections, connections) &&
      identical(cache.interactions, interactions);

  if (isFresh) {
    return cache.list;  // ← serves stale data if snapshot listeners haven't fired yet
  }

  // ... recompute with current data ...
  final appState = ref.read(appControllerProvider);
  final lastAiUpdatedContactId = appState.lastAiUpdatedContactId;  // ← one-time read, not watched

  final list = rankRecommendations(
    connections: connections,
    interactions: interactions,
    memories: memories,
    now: now,
    previousList: lastRecommendationList,
    previousCacheTime: holder.cache?.computedAt ?? now.subtract(recommendationsFreshness),
    lastAiUpdatedContactId: lastAiUpdatedContactId,
  );

  holder.cache = _RecommendationsCache(
    computedAt: now,  // ← set to clock(), which is AFTER memoryEpoch bump time
    list: list,
    store: store,
    connections: connections,
    interactions: interactions,
  );

  if (lastAiUpdatedContactId != null) {
    ref.read(appControllerProvider.notifier).clearLastAiUpdate();  // ← consumes the signal
  }
  return list;
});
```

### 6. The Consumer in `_AiInsightsBodyState` (crm_widgets.dart:1345–1360)

```dart
// lib/src/widgets/crm_widgets.dart, lines 1345-1360
Consumer(
  builder: (context, ref, child) {
    final recommendationsAsync = ref.watch(recommendationsProvider);
    final recForThisContact = recommendationsAsync.maybeWhen(
      data: (list) => list.where((r) => r.contactId == widget.connection.id).firstOrNull,
      orElse: () => null,  // ← returns null during loading → SizedBox.shrink()
    );
    if (recForThisContact == null) {
      return const SizedBox.shrink();
    }
    // ... render recommendation banner ...
  },
),
```

### 7. Snapshot listeners that update connections/interactions (app_state.dart:178–198)

```dart
// lib/src/state/app_state.dart, lines 178-198
_connectionsSub = connectionStore.snapshot().listen((snapshot) {
  state = state.copyWith(connections: snapshot.values.toList());  // ← new list identity
  _hasConnectionsSnapshot = true;
  _scheduleBondDriftCheck();
});

_interactionsSub = interactionStore.snapshot().listen((snapshot) {
  final values = snapshot.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  state = state.copyWith(interactions: values);  // ← new list identity
  _hasInteractionsSnapshot = true;
  _scheduleBondDriftCheck();
});
```

---

## Architecture: Complete Data Flow

### From AI Update "Save" tap to banner re-render

```
AiUpdateScreen.save() [ai_update_screen.dart:230]
  │
  ├─ await ref.read(aiUpdateProvider).commit(editedResult)
  │   │
  │   ├─ LlmAiUpdate.commit() [llm_ai_update.dart:369]
  │   │   │
  │   │   ├─ STEP 1: await memoryStore.save(memory)          // Firestore write
  │   │   │
  │   │   ├─ STEP 2: onMemoryWritten?.call()                 // bumps memoryEpochProvider
  │   │   │   │
  │   │   │   └─ memoryEpochProvider.state = clock()         // T_epoch
  │   │   │       │
  │   │   │       └─ recommendationsProvider is INVALIDATED  // via ref.watch(memoryEpochProvider)
  │   │   │           │
  │   │   │           └─── SCHEDULED AS MICROTASK ───┐       // runs after current await yields
  │   │   │                                            │
  │   │   ├─ STEP 3: await appController.applyAiUpdateResult(result)
  │   │   │   │                                          │
  │   │   │   ├─ STEP 3a: await batchedWrites.commitAiUpdate(...)  // Firestore batch write
  │   │   │   │   │                                      │
  │   │   │   │   │   SUSPENDS (await) ─────────────┐    │
  │   │   │   │   │                                  │    │
  │   │   │   │   │   MICROTASK QUEUE RUNS ─────────┐│    │
  │   │   │   │   │                                  ▼▼    │
  │   │   │   │   │   recommendationsProvider recomputation START
  │   │   │   │   │     │
  │   │   │   │   │     ├─ ref.watch(select: connections)  → STALE (snapshot not fired yet)
  │   │   │   │   │     ├─ ref.watch(select: interactions) → STALE
  │   │   │   │   │     ├─ ref.watch(memoryEpochProvider)  → T_epoch (fresh)
  │   │   │   │   │     ├─ ref.read(appControllerProvider) → lastAiUpdatedContactId is NULL
  │   │   │   │   │     │   (step 3b hasn't run yet!)
  │   │   │   │   │     │
  │   │   │   │   │     ├─ cache check: memoryEpoch.isAfter(cache.computedAt?) 
  │   │   │   │   │     │   Old cache: YES → recompute
  │   │   │   │   │     │
  │   │   │   │   │     ├─ await store.listAll() → fresh memory ✓
  │   │   │   │   │     ├─ rankRecommendations(connections=STALE, interactions=STALE,
  │   │   │   │   │     │   lastAiUpdatedContactId=NULL)
  │   │   │   │   │     │   → fast path NOT fired (lastAiUpdatedContactId is null)
  │   │   │   │   │     │   → fallback NOT fired (no new AI interaction in stale list)
  │   │   │   │   │     │   → maintenance need computed with STALE lastContact/bondScore
  │   │   │   │   │     │
  │   │   │   │   │     ├─ holder.cache = _RecommendationsCache(
  │   │   │   │   │     │     computedAt: clock(),  // T_compute > T_epoch
  │   │   │   │   │     │     connections: STALE,
  │   │   │   │   │     │     interactions: STALE,
  │   │   │   │   │     │   )
  │   │   │   │   │     │   ← CACHE SET WITH STALE DATA
  │   │   │   │   │     │
  │   │   │   │   │     └─ clearLastAiUpdate() → SKIPPED (lastAiUpdatedContactId was null)
  │   │   │   │   │
  │   │   │   │   │   RECOMPUTATION COMPLETES ────── returns stale result
  │   │   │   │   │
  │   │   │   │   ▼   (Firestore batch write resolves)
  │   │   │   ├─ STEP 3b: state = state.copyWith(lastAiUpdatedContactId: contactId)
  │   │   │   │   // AppState now has lastAiUpdatedContactId, but connections/interactions are still stale
  │   │   │   │
  │   │   │   ▼   (commit returns)
  │   │   │
  │   │   ▼
  │   ├─ commit() returns successfully
  │
  ├─ Navigator.pop(context)  // return to contact profile
  │
  ▼
ContactProfileScreen becomes visible
  │
  ├─ ContactProfileScreen.build() [contact_profile_screen.dart:30]
  │   ├─ ref.watch(contactByIdProvider(contactId)) → person with STALE bondScore
  │   ├─ ref.watch(memoryProvider(contactId)) → reloaded (memoryEpoch bumped) → FRESH ✓
  │   ├─ AiInsightsCard(connection: person, memory: memory, ...)
  │
  ├─ _AiInsightsCardState.build() [crm_widgets.dart:1280]
  │   └─ _AiInsightsBody(connection: widget.connection, ...)
  │
  ├─ _AiInsightsBodyState.build() [crm_widgets.dart:1345]
  │   └─ Consumer(builder: (context, ref, child) {
  │         final recommendationsAsync = ref.watch(recommendationsProvider);
  │         // ↑ Provider has STALE CACHE
  │         // Cache freshness check:
  │         //   cache.computedAt = T_compute (set by stale recomputation)
  │         //   memoryEpoch = T_epoch
  │         //   memoryEpoch.isAfter(T_compute)? → T_epoch.isAfter(T_compute)? → NO (T_compute > T_epoch)
  │         //   → condition passes (cache deemed fresh)
  │         //   identical(connections)? → YES (snapshot hasn't fired)
  │         //   identical(interactions)? → YES
  │         //   → isFresh = TRUE → serves stale cache
  │         //
  │         // Banner shows OLD recommendation ← BUG!
  │       })
  │
  ▼ (sometime later: 100ms-2s)
  
Firestore snapshot listeners fire [app_state.dart:178-198]
  │
  ├─ _connectionsSub fires → state.copyWith(connections: newList) 
  │   → appControllerProvider.select(s => s.connections) notifies
  ├─ _interactionsSub fires → state.copyWith(interactions: newList)
  │   → appControllerProvider.select(s => s.interactions) notifies
  │
  ▼
recommendationsProvider is INVALIDATED (via select watches)
  │
  ├─ cache check: identical(cache.connections, connections)? → NO (new list)
  │   → isFresh = FALSE → recompute
  │
  ├─ rankRecommendations with FRESH connections/interactions
  │   ├─ lastAiUpdatedContactId IS set (step 3b already ran)
  │   ├─ Fast path #117 fires → completed card inserted
  │   ├─ clearLastAiUpdate() IS called
  │   └─ New cache set with CORRECT data
  │
  ▼
Consumer rebuilds → banner shows correct recommendation
```

---

## Root Cause

### Primary: Race condition — stale cache passes freshness check

**File:** `lib/src/state/memory/memory_providers.dart`, lines 218–227

The `recommendationsProvider` dual-invalidation cache uses this check to decide if the cache is fresh:

```dart
(memoryEpoch == null || !memoryEpoch.isAfter(cache.computedAt))
```

This check works correctly when the **old cache** predates the `memoryEpoch` bump: `memoryEpoch.isAfter(old_computedAt)` → TRUE → cache invalid.

But after the `memoryEpoch`-triggered recomputation finishes (at `T_compute > T_epoch`), a **new cache** is set with `computedAt = T_compute`. The check `memoryEpoch.isAfter(T_compute)` is FALSE because `T_compute > T_epoch`. So the new (stale) cache passes this check.

The `identical(cache.connections, connections)` and `identical(cache.interactions, interactions)` guards should catch this, but they only fail when the snapshot listener fires — which happens asynchronously AFTER the batch write, AFTER the first recomputation finished.

**Sequence:**
1. `memoryEpoch` bumped at `T_epoch` (commit step 2)
2. `recommendationsProvider` recomputes at `T_compute > T_epoch` with **stale** connections/interactions
3. Cache set: `computedAt = T_compute`, connections=STALE, interactions=STALE
4. `isFresh` check on next read: `memoryEpoch.isAfter(T_compute)` → FALSE → passes
5. `identical(stale_connections, current_connections)` → TRUE (snapshot not fired) → passes
6. Cache served with stale data → banner frozen

### Secondary: `lastAiUpdatedContactId` not set during first recomputation

**File:** `lib/src/state/app_state.dart`, line 344

The synchronous completion signal `lastAiUpdatedContactId` is set in `applyAiUpdateResult` at step 3b, which happens AFTER the `memoryEpoch` bump (step 2) that triggered the first recomputation. The recomputation starts as a microtask during the `await` in step 3a, before step 3b runs. So `lastAiUpdatedContactId` is NULL during the first recomputation — the fast path completion detection (#117) is neutered.

### Tertiary: Consumer hides banner during loading

**File:** `lib/src/widgets/crm_widgets.dart`, lines 1350–1358

```dart
recommendationsAsync.maybeWhen(
  data: (list) => ...,
  orElse: () => null,  // during loading → null → SizedBox.shrink()
);
```

During async recomputation, the provider is in `AsyncLoading` state. `maybeWhen` with `orElse: () => null` returns null, and the Consumer renders `SizedBox.shrink()`. The banner flashes out during recomputation.

---

## Start Here

Open **`lib/src/state/memory/memory_providers.dart`** at line 215 (`final recommendationsProvider = FutureProvider<List<Recommendation>>(...`) — this is where the cache invalidation logic lives and where the fix should be applied.

---

## Suggested Fix Approaches

### Approach A: Bump `memoryEpochProvider` AFTER the batch write (reorder commit)

Move `onMemoryWritten?.call()` to AFTER `appController.applyAiUpdateResult()` in both `MockAiUpdate.commit()` and `LlmAiUpdate.commit()`. This ensures the `recommendationsProvider` recomputation starts only after connections/interactions have been written to Firestore AND `lastAiUpdatedContactId` has been set.

**Files to change:**
- `lib/src/ai/llm_ai_update.dart`, lines 378–382: move `onMemoryWritten?.call()` after `appController.applyAiUpdateResult(result)`
- `lib/src/ai/ai_update.dart`, lines 327–335: same in `MockAiUpdate.commit()`

**Risk:** The rollback path (if `applyAiUpdateResult` throws after `onMemoryWritten`) would need to undo the epoch bump or re-bump to the same value. Treat as no-op since the epoch bump is a transient signal.

### Approach B: Use `lastAiUpdatedContactId` as additional cache freshness gate

Add `lastAiUpdatedContactId` to the `_RecommendationsCache` and check `appState.lastAiUpdatedContactId != cache.lastAiUpdatedContactId` in the `isFresh` check.

### Approach C: Use both `memoryEpoch` bump time comparison correctly

Store `memoryEpochBumpedAt` in addition to `memoryEpoch`, and in the `isFresh` check, compare `cache.computedAt` to `memoryEpochBumpedAt` rather than `memoryEpoch`:
```
cache.computedAt < memoryEpochBumpedAt → stale → recompute
```

This avoids the race because `memoryEpochBumpedAt` is set at the exact moment of the bump (T_epoch), and `cache.computedAt` (T_compute) will always be ≥ T_epoch, so the check `T_compute < T_epoch` correctly detects staleness when the cache was computed BEFORE the epoch bump... but this has the same problem: if the stale recomputation sets `computedAt` after `T_epoch`, the check still passes.

### Approach D (Recommended): Invalidate cache directly in `applyAiUpdateResult`

After the batch write succeeds and `lastAiUpdatedContactId` is set, explicitly clear the `_recommendationsCacheHolder` cache:

```dart
// In applyAiUpdateResult, after state.copyWith(...):
ref.read(_recommendationsCacheProvider).cache = null;
```

This forces a full recomputation on the next read of `recommendationsProvider`, with all fresh data and `lastAiUpdatedContactId` properly set.

**File to change:** `lib/src/state/app_state.dart`, `applyAiUpdateResult` method (~line 348)

**Risk:** Low. The cache will be repopulated on the next read. The `lastRecommendationList` module-level variable is not cleared (so completion detection still has context).

---

## Additional Notes

- The `_AiInsightsBodyState` has a stale-state bug with `_selectedTopic` (line 1340, `late String? _selectedTopic = widget.initialSelectedTopic`) — no `didUpdateWidget` override. This is unrelated to the banner freeze but documented in `research/widget-rebuild-issues.md`.

- The Consumer's `orElse: () => null` pattern causes the banner to flash out during async recomputation. Consider adding a `loading:` branch to `maybeWhen` to show a skeleton/shimmer instead.

- The GoRouter uses flat `GoRoute` entries (no `ShellRoute`). `context.push('/ai-update/:id')` pushes the AI Update screen onto the Navigator stack; the contact profile screen stays alive but hidden. Widget states and Riverpod subscriptions survive across the navigation.
