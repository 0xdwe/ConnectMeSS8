# Progress

## Status
Shipped #122–#126 (Delete Activity Log + Rebuild Memory feature chain)

## Tasks

- [x] #122 — Add `bondScoreDelta` to `CrmInteraction` and populate on AI Update
- [x] #123 — Delete Activity Log Row with Confirmation, Undo, and Connection Recalculation
- [x] #124 — `MemoryRebuilder` Seam and Full Memory Rebuild on Delete
- [x] #125 — AI Insights Spinner for Pending Memory Rebuild
- [x] #126 — Offline/Error Handling for Activity Log Deletion

## Files Changed

### #122 (bondScoreDelta on CrmInteraction)
- `lib/src/models/social_models.dart` — Added `bondScoreDelta` field (default 0) + `copyWith` to `CrmInteraction`
- `lib/src/state/connections/firebase_interaction_store.dart` — Encode/decode `bondScoreDelta` with backward-compatible fallback to 0
- `lib/src/ai/ai_update_commit_plan.dart` — Propagate `bondScoreDelta` from `AiUpdateResult` to interaction via `copyWith`
- `lib/src/state/app_state.dart` — Explicit `bondScoreDelta: 0` in `logInteraction`
- `firestore/firestore.rules` — Added `bondScoreDelta` to `isWellFormedInteraction` hasOnly + type guard
- `firestore/rules.test.js` — 3 new tests for `bondScoreDelta` rules (optional, int, wrong-type)
- `test/ai/ai_update_commit_plan_test.dart` — New test for propagation
- `test/state/connections/interaction_store_test.dart` — New test for round-trip

### #123 (Delete Activity Log Row)
- `lib/src/state/app_state.dart` — New `deleteInteraction` method: delete from store, recalculate `lastContact`/`bondScore`, single connection save
- `lib/src/features/contact_profile_screen.dart` — Extracted `_ActivityLogSection` widget with delete icon, confirmation dialog, 4-second undo SnackBar, disabled state during processing, timer race-condition fix
- `test/state/app_state_test.dart` — 7 new unit tests (delete, recalc lastContact, subtract bondScoreDelta, clamp-to-0, fallback, not-found, rebuild-failure)
- `test/features/activity_log_delete_test.dart` — 5 widget tests (delete button, dialog, undo, disabled, row removal)

### #124 (MemoryRebuilder Seam)
- `lib/src/ai/memory_rebuilder.dart` (NEW) — `MemoryRebuilder` interface + `MemoryRebuildResult` type
- `lib/src/ai/fake_memory_rebuilder.dart` (NEW) — Deterministic test adapter with `rebuildCallCount` + `nextResult` injection
- `lib/src/ai/llm_memory_rebuilder.dart` (NEW) — Production stub (throws `UnimplementedError`; full LLM prompt deferred)
- `lib/src/state/memory/memory_rebuilder_providers.dart` (NEW) — Auth-aware `memoryRebuilderProvider` (signed-in → LLM stub, signed-out → sentinel)
- `lib/src/state/app_state.dart` — `deleteInteraction` now calls `MemoryRebuilder.rebuild`, saves rebuilt memory, updates `nextStep`, bumps epoch, clears cache; single connection save (review fix); sets `pendingMemoryRebuildProvider`
- `test/ai/memory_rebuilder_test.dart` (NEW) — 4 tests for FakeMemoryRebuilder
- `test/state/app_state_test.dart` — 5 new integration tests (rebuild, nextStep, epoch, cache, non-fatal failure + throwing rebuilder test)

### #125 (AI Insights Rebuild Spinner)
- `lib/src/state/memory/memory_providers.dart` — Added `PendingMemoryRebuildNotifier` + `pendingMemoryRebuildProvider`
- `lib/src/state/app_state.dart` — `deleteInteraction` sets provider before rebuild, clears after
- `lib/src/widgets/crm_widgets.dart` — `AiInsightsCard` watches `pendingMemoryRebuildProvider`, shows spinner on match
- `test/state/memory/pending_memory_rebuild_provider_test.dart` (NEW) — 4 provider tests
- `test/state/app_state_test.dart` — 2 new tests (provider set during rebuild, cleared on failure)
- `test/widgets/ai_insights_card_test.dart` — 4 widget tests (spinner shows, clears, different contact, manual refresh independent)

### #126 (Offline/Error Handling)
- `lib/src/state/app_state.dart` — `deleteInteraction` returns `Future<bool>` (rebuild success indicator); `catch` block sets `rebuildSucceeded = false`
- `lib/src/features/contact_profile_screen.dart` — Shows SnackBar "AI Insights could not be refreshed. Try refreshing manually later." on rebuild failure
- `test/state/app_state_test.dart` — Updated 3 tests to verify return values (`isTrue`/`isFalse`)
- `test/features/activity_log_delete_test.dart` — 1 new widget test (rebuild failure path)

## Notes

### 2026-06-15: #122–#126 Delete Activity Log + Rebuild Memory feature chain

Shipped the full dependency chain #122 → #123 → #124 → #125 → #126. Each issue was implemented with TDD (vertical-slice), reviewed by @oracle, and merged to `main` with `--no-ff`.

**Key architectural decisions:**
- `bondScoreDelta` defaults to 0 on `CrmInteraction` for backward compatibility; AI Update commits populate it via `copyWith` in `buildAiUpdateCommitPlan`
- `deleteInteraction` is an orchestration method on `AppController` (mirrors `deleteConnection`/`deleteEvent` shape)
- `MemoryRebuilder` is a separate seam from `AiUpdate` (user-input/preview driven) and `MemoryTopicEnricher` (topic-only enrichment)
- `LlmMemoryRebuilder` is a stub throwing `UnimplementedError`; full LLM prompt is deferred to a follow-up
- Single connection save in `deleteInteraction` (review fix from #124 — avoids double-write exposing intermediate state to snapshot listeners)
- `pendingMemoryRebuildProvider` is separate from `pendingAiInsightsRefreshProvider` — the former triggers the full rebuild spinner, the latter triggers topic-only enrichment
- `deleteInteraction` returns `Future<bool>` — `true` if rebuild succeeded, `false` if it failed (interaction/connection still updated)
- Timer race condition fix in `_ActivityLogSection` — cancel previous timer before starting a new one

**Known follow-ups (not in this chain):**
- `LlmMemoryRebuilder` full prompt implementation (currently a stub)
- `AppUser` cleanup (deferred per AGENTS.md)
- The 33 widget test failures on `main` from `ui-login-page` + `fix-navbar` UI merges (out of Pass 4 scope)
- Cross-device evidence chain (deferred per ADR-0003)

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