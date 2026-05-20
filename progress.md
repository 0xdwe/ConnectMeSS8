# Progress

## Current status

**Pass 1 (home/people UI consistency)** — shipped, including review fixes.
**Pass 2 (contact profile redesign)** — shipped, including review fixes.
**Pass 3 (per-contact memory files with agentic AI)** — shipped on 2026-05-19. All 11 issues (#040–#050) merged to `main`.
**Test baseline** — full sweep: **289 passed, 0 failed**.

## Pass 3 summary

The architectural pivot from the v2 PRD (`docs/prd/2026-05-19-per-contact-memory-files-v2-prd.md`) replaced v1's parallel `MemoryUpdater` + `AiUpdateService` plan with a single `AiUpdate` module shaped around the user-level operation ("Update with AI on Sarah"). Memory is now persistent on disk, narrative grows on each AI update, and recommendations are produced by a real engine ranking the live connection list rather than three frozen constants.

Four-layer system shipped:
1. **Memory document** — `MemoryDocument` immutable model with frontmatter + `Summary`/`History`/`Preferences`/`Topics`/`Upcoming` sections, total parser via the `yaml` package, hand-written renderer, round-trip tested.
2. **Memory store** — `MemoryStore` async interface with two adapters (`InMemoryMemoryStore`, `FileMemoryStore`). File store uses atomic temp-file-then-rename writes; per-contact 64KB cap drops oldest history bullets.
3. **Unified AI update** — `AiUpdate` interface with one method `run` (purely constructive) and one method `commit` (memory then state, all-or-nothing rollback on failure). `MockAiUpdate` is the deterministic Pass 3 adapter; `LlmAiUpdate` is reserved for Pass 4.
4. **UI integration** — Riverpod providers (`memoryStoreProvider`, `aiUpdateProvider`, `memoryProvider`, `memoryTopicsProvider`, `recommendationsProvider`) drive the contact profile, the AI Update preview's "About <Name> ✨" delta section, and the Home recommendations list.

Bond-tier-weighted recency ranks recommendations with a 24h cooldown filter, top 3. Recommendations cache with dual invalidation (memory change OR 6h elapsed). Memory writes silently bump a `memoryEpochProvider` to invalidate the cache. Anti-shame guardrail enforced: no numeric day counts in user-visible copy.

## Issue status

### Pass 3 — done

- **#040** — `MemoryDocument` + `InMemoryMemoryStore` + `memoryProvider` + filesystem-inferred seed migration. Profile Person Summary swaps to `MemoryDocument.summary`. (commit `1e80d08`)
- **#041** — `FileMemoryStore` with atomic writes, per-contact 64KB cap, global 16MB soft cap. `path_provider` + `yaml` deps added. (commit `c14886d`)
- **#042** — Unified `AiUpdate` module replaces `AiUpdateService`. Three `AppController` AI methods removed. `deleteConnection` cascades to `MemoryStore.delete`. The Q1 architectural pivot. (commit `ed8a7d8`)
- **#043** — `ConversationTopics` module extracted from `crm_widgets.dart`. ~40-keyword substring topic extractor in `MockAiUpdate`. Pills read from memory; category defaults are the empty-state fallback. (commit `37f5b65`)
- **#044** — Templated suggestion fallback for memory-extracted topics with no curated entry. (commit `40026dd`)
- **#045** — AI Update preview gains read-only "About <Name> ✨" delta section. New topics highlighted; cancel discards both. (commit `a6cfee3`)
- **#046** — `AiUpdate` all-or-nothing failure contract. Test-injection knobs (`failOnRun` / `failOnSave` / `failOnApply`) prove the rollback path. AI Update screen surfaces a retry snackbar on failure. (commit `b1701ee`)
- **#047** — `RecommendationEngine` pure-function module. Q11 ranking. Hardcoded `state.recommendations` getter deleted. (commit `1752494`)
- **#048** — `recommendationsProvider` lazy with dual invalidation (memory change OR 6h elapsed). `clockProvider` for testable time. (commit `097e3d1`)
- **#049** — Engine surfaces "just got back from <trip>" / "trip starts tomorrow" cards from `MemoryDocument.upcoming`. Mock leaves `Upcoming` empty by design; engine logic is fixture-tested. (commit `3284ac2`)
- **#050** — `ContactInsight.summary` and `.why` deleted. Five additional dead fields and three dead widget classes (`RecommendedActionCard`, `CommunicationChannelsCard`, `InteractionFrequencyCard`) cleaned up. (commit `4ba3b69`)

### Pre-Pass-3 done (carried forward)

- **#001–#039** — earlier waves through the architecture-deepening review. See git history for details.

### Open and pickable

- **#037** — Orphaned `ProfileScreen` and `HeatmapCard`. Pick one of two paths: delete the orphan code, or restore an entry point on the shell. Severity: nice-to-have. Not on the critical path.
- **#039** — Architecture deferred cleanup candidates (`InteractionType` Flutter leak; by-id query providers shape). Both small refactors that earn their keep when their consumers move; not blocking.
- **#051** — `recommendationsProvider` does not yet load `MemoryStore.listAll()` into the engine's `memories` parameter. The engine's Q12 upcoming-driven cards are fixture-tested but cannot fire in the running app until that wiring lands. Surfaces naturally during Pass 4 when `LlmAiUpdate` starts populating `MemoryDocument.upcoming` for real. (Filed during Pass 3 wrap.)

### Pass 4 — not yet planned

- Real LLM provider integration (`LlmAiUpdate`). API key UX. Provider selection, retry, cancellation, network error handling. The unified `AiUpdate` seam from Q1 is the network-handling boundary — one adapter swap, not two.
- Firebase backend / multi-device sync. The `MemoryStore` interface is shaped to make a third `FirebaseMemoryStore` adapter cheap.
- Background recommendation scheduling (push notifications, cron). Pass 3's lazy + 6h dual invalidation is the in-app model; cross-device push is Firebase + Cloud Functions territory.

## Test baseline progression

| Date | Sweep result | Notes |
|------|--------------|-------|
| Pre-Pass-1 | typography suite hangs >9 min, never completes | `GoogleFonts.pendingFonts()` blocks |
| Pass 1 + Pass 2 ships | 133 passed, 12 failed (typography excluded) | Relaxed bar accepted per #032 |
| `077ab33` (Inter bundled) | 158 passed, 12 failed (typography included) | Hang fixed; same 12 fixture failures |
| `fff16ac` (#032 residual closed) | 169 passed, 0 failed | Drift/fixture/pre-existing all resolved |
| `c0efe08` (#038 closed) | 174 passed, 0 failed | Section title responsive layout |
| `1e80d08` (Pass 3 #040 merged) | 199 passed, 0 failed | +25 memory document/store/provider tests |
| `c14886d` (Pass 3 #041 merged) | 217 passed, 0 failed | +18 file store / atomic write tests |
| `ed8a7d8` (Pass 3 #042 merged) | 227 passed, 0 failed | +10 unified AiUpdate tests |
| `37f5b65` (Pass 3 #043 merged) | 243 passed, 0 failed | +16 conversation topics + extractor tests |
| `40026dd` (Pass 3 #044 merged) | 252 passed, 0 failed | +9 templated fallback tests |
| `a6cfee3` (Pass 3 #045 merged) | 258 passed, 0 failed | +6 preview delta tests |
| `b1701ee` (Pass 3 #046 merged) | 262 passed, 0 failed | +4 all-or-nothing rollback tests |
| `1752494` (Pass 3 #047 merged) | 275 passed, 0 failed | +13 recommendation engine + provider tests |
| `097e3d1` (Pass 3 #048 merged) | 281 passed, 0 failed | +6 dual-invalidation cache tests |
| `3284ac2` (Pass 3 #049 merged) | 289 passed, 0 failed | +8 upcoming-driven card tests |
| `4ba3b69` (Pass 3 #050 merged) | **289 passed, 0 failed** | Test rewrites kept count even after cleanup |

## Verification

- `flutter analyze`: 1 pre-existing info lint at `lib/src/features/ai_update_screen.dart:116` (`use_build_context_synchronously`). Out of scope per the Pass 3 PRD.
- `flutter test` (full sweep): **289 passed, 0 failed**.
- All 11 Pass 3 feature branches retained on the remote for traceability.

## Notes for the next session

- **Pass 4 is the natural next move.** `LlmAiUpdate` adapter is the load-bearing change; everything else around it (providers, store, document parser, UI surfaces) stays put per the Q1 pivot. API key UX, provider selection, and Firebase auth are all post-Pass-4 follow-ups.
- **#051 is the cheapest first task in Pass 4 territory.** Wiring `recommendationsProvider` to `MemoryStore.listAll()` lights up the upcoming-driven engine cards in production. Touches one Notifier method; engine logic and tests already exist.
- **The Mock topic extractor's keyword list is a known throwaway.** When `LlmAiUpdate` lands the keyword list goes away and the LLM does real semantic extraction. Don't grow the list further; let it die.
- **The `## Upcoming` section in memory format is currently empty in production** because `MockAiUpdate` doesn't populate it (extracting "tomorrow" / "for a week" deterministically is too brittle for a mock). Demo paths can hand-edit a memory file under `<app_documents>/memories/` to see the engine's special cards fire.
- **No background scheduler exists.** The Q2 dual-invalidation model assumes the user opens the app to trigger recompute. Push-style "we noticed you haven't talked to Mike" notifications are Pass 4+ Firebase work, not Pass 3.

## Pass 3 grilling outcomes (Q1–Q13, locked)

The v2 PRD captures these in full. Listed here as a quick reference:

- **Q1**: Unified `AiUpdate` module replaces parallel `MemoryUpdater` / `AiUpdateService` plan.
- **Q2**: Lazy `recommendationsProvider` with dual invalidation (memory change OR 6h).
- **Q3**: Carve out only `AiUpdate` from `AppController`; Contacts/Planner/Session stay.
- **Q4**: All-or-nothing failure contract on `AiUpdate.run`/`commit`.
- **Q5**: AI Update preview shows read-only "About <Name> ✨" delta; cancel discards both.
- **Q6**: Markdown + YAML frontmatter via `yaml` package.
- **Q7**: ~40 hand-curated keywords for mock topic extraction.
- **Q8**: Riverpod providers for store, AiUpdate, memory, topics, recs.
- **Q9**: Filesystem-inferred migration state, no `shared_preferences`.
- **Q10**: Delete `ContactInsight.summary` and `.why`.
- **Q11**: Bond-tier-weighted recency, 24h cooldown, top 3.
- **Q12**: `## Upcoming` section in memory format with engine-side reaction.
- **Q13**: Static map plus templated fallback for topic suggestions.
