# Progress

## Status
In Progress

## Tasks

## Files Changed

## Notes

### 2026-06-15: AiInsightsCard widget rebuild / state retention investigation
Scouted `lib/src/widgets/crm_widgets.dart`, `lib/src/features/contact_profile_screen.dart`, `lib/src/app/connect_me_app.dart`, `lib/src/state/memory/memory_providers.dart`, `lib/src/features/ai_update_screen.dart`, `lib/src/features/tabs/home_tab.dart`, `lib/src/features/shell_screen.dart`.  
Findings written to `research/widget-rebuild-issues.md`.

Key issues found:
1. **_selectedTopic stale state** (line 1340 of crm_widgets.dart) — `late` field never updates on `didUpdateWidget`
2. **Recommendation banner flashes during async recomputation** — Consumer returns `SizedBox.shrink()` during loading
3. **No key on AiInsightsCard** — low risk but worth adding `ValueKey(contactId)`
4. **Mixed watch patterns** — ConsumerState that doesn't watch in build + inner Consumer widget

### 2026-06-15: Conversation topics vs recommendation banner update mechanisms
Scouted the full data flow for both UI sections across 8 files.
Findings written to `research/topics-vs-banner.md`.

Key insight: Topics and recommendations read from different providers with fundamentally different data resolution strategies:
- **Topics**: `memoryProvider(contactId)` — single-doc fetch, no cache, pure function of `MemoryDocument?`, synchronous prop chain
- **Recommendations**: `recommendationsProvider` — all-docs fetch (`store.listAll()`), 5-condition cache, async `rankRecommendations()` pipeline with completion detection (#117)

Both watch `memoryEpochProvider` for invalidation, but the recommendation path is significantly more complex (cache, completion signal consumption via `lastAiUpdatedContactId`, module-level `lastRecommendationList`). The most likely divergence point is Firestore's cache-first behavior differing between single-doc `get()` and collection `get()`.

### 2026-06-15: AI Update → AiInsightsCard banner data flow trace (root cause found)
Scouted 12 files across the full commit→provider→Consumer chain.
Findings written to `research/trace-banner-update.md`.

**Root cause:** Race condition in `recommendationsProvider` cache invalidation (`lib/src/state/memory/memory_providers.dart`, lines 218–227).

The `onMemoryWritten` callback (bumping `memoryEpochProvider`) fires BEFORE `applyAiUpdateResult` in `commit()`. This triggers `recommendationsProvider` to recompute as a microtask *during* the `await` in `applyAiUpdateResult` — before the batch write completes and before `lastAiUpdatedContactId` is set. The recomputation runs with **stale** connections/interactions (snapshot listeners haven't fired yet) and **null** `lastAiUpdatedContactId`. The resulting cache has `computedAt > memoryEpoch` (because the recomputation happens after the epoch bump), so the `!memoryEpoch.isAfter(cache.computedAt)` freshness check passes. With identical connections/interactions (snapshot not fired), all 5 `isFresh` conditions pass — the stale cache is served as "fresh" to the Consumer.

**Sequence:**
1. `onMemoryWritten()` bumps `memoryEpoch` at T_epoch
2. `recommendationsProvider` recomputes at T_compute > T_epoch with stale data
3. Cache: `computedAt = T_compute`, `memoryEpoch.isAfter(T_compute)` = false → passes freshness check
4. Consumer reads stale cache → banner frozen

**Recommended fix:** Clear `_recommendationsCacheHolder.cache` directly in `applyAiUpdateResult` after the batch write succeeds, forcing a full recomputation on the next read with fresh data and `lastAiUpdatedContactId` properly set. Alternatively, reorder `commit()` to bump `memoryEpoch` AFTER `applyAiUpdateResult` completes.
