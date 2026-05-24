# Progress

## Current status

**Pass 1 (home/people UI consistency)** — shipped, including review fixes.
**Pass 2 (contact profile redesign)** — shipped, including review fixes.
**Pass 3 (per-contact memory files with agentic AI)** — shipped on 2026-05-19. All 11 issues (#040–#050) merged to `main`.
**Pass 4 begins.** Pass 4.1 (#052, Firebase Auth) shipped on 2026-05-21. Pass 4.2–4.4 not yet started.
**Test baseline** — full sweep: **289 passed, 0 failed**.

## Pass 4 sub-pass plan

The unified `AiUpdate` seam from Pass 3's Q1 was specifically shaped to make Pass 4 a one-adapter swap per concern. Sub-passes are independent except where noted; 4.1 is the load-bearing scaffolding for 4.2 and 4.4.

- **Pass 4.1 — Firebase scaffolding + real Auth.** ✅ **Shipped (#052, commit `ac9e705`).** `flutterfire configure` against project `connect-me-e20b1` across android/ios/macos. `firebase_core` + `firebase_auth` deps. `firebaseAuthProvider` in `lib/src/state/firebase_providers.dart`. Auth screen sign-in/sign-up swap to FirebaseAuth. Settings sign-out signs out of Firebase first. 9 widget tests gained `firebaseAuthProvider` overrides via `MockFirebaseAuth` from `firebase_auth_mocks`.
- **Pass 4.2 — `FirebaseMemoryStore` adapter.** Not started. Third implementation of `MemoryStore`. Per-contact memory docs to Firestore keyed by `userId/contactId`. Atomic temp-then-rename contract carries forward as Firestore atomic writes. Real security rules replace the Pass 4.1 "test mode" rules. Production `memoryStoreProvider` swaps from `FileMemoryStore`; local store stays as offline cache or test-only.
- **Pass 4.3 — `LlmAiUpdate` adapter.** Not started. Real LLM behind the unified `AiUpdate` seam. API key UX in settings (`flutter_secure_storage` for the key). Retry, timeout, cancellation. The Mock keyword list dies; the LLM populates `MemoryDocument.upcoming` for real, which lights up the engine logic from #049 + the wire-up in #051.
- **Pass 4.4 — Cross-device sync + push.** Not started. Cloud Functions on Firestore writes; FCM for "we noticed you haven't talked to Mike" pushes. Last-writer-wins conflict resolution for the prototype.

## Pass 4 verification before 4.2

Before 4.2 starts touching Firestore, the running app should be verified on a device against the real Firebase project:

1. Run the app on a real (or simulated) device.
2. Sign up with a fresh email + password (≥6 chars). The account should appear under Authentication in the Firebase console.
3. Sign out from the settings tab.
4. Sign back in. Wrong password should produce the inline "that password doesn't match" error.
5. If anything fails (config files in the wrong place, bundle ID mismatch, network errors): file as a hotfix issue before 4.2.

All of this works behind the existing test sweep with `MockFirebaseAuth`, so the gate is real-device testing rather than `flutter test`.

## Pass 3 summary

The architectural pivot from the v2 PRD (`docs/prd/2026-05-19-per-contact-memory-files-v2-prd.md`) replaced v1's parallel `MemoryUpdater` + `AiUpdateService` plan with a single `AiUpdate` module shaped around the user-level operation ("Update with AI on Sarah"). Memory is now persistent on disk, narrative grows on each AI update, and recommendations are produced by a real engine ranking the live connection list rather than three frozen constants.

Four-layer system shipped:
1. **Memory document** — `MemoryDocument` immutable model with frontmatter + `Summary`/`History`/`Preferences`/`Topics`/`Upcoming` sections, total parser via the `yaml` package, hand-written renderer, round-trip tested.
2. **Memory store** — `MemoryStore` async interface with two adapters (`InMemoryMemoryStore`, `FileMemoryStore`). File store uses atomic temp-file-then-rename writes; per-contact 64KB cap drops oldest history bullets.
3. **Unified AI update** — `AiUpdate` interface with one method `run` (purely constructive) and one method `commit` (memory then state, all-or-nothing rollback on failure). `MockAiUpdate` is the deterministic Pass 3 adapter; `LlmAiUpdate` is reserved for Pass 4.3.
4. **UI integration** — Riverpod providers (`memoryStoreProvider`, `aiUpdateProvider`, `memoryProvider`, `memoryTopicsProvider`, `recommendationsProvider`) drive the contact profile, the AI Update preview's "About <Name> ✨" delta section, and the Home recommendations list.

Bond-tier-weighted recency ranks recommendations with a 24h cooldown filter, top 3. Recommendations cache with dual invalidation (memory change OR 6h elapsed). Memory writes silently bump a `memoryEpochProvider` to invalidate the cache. Anti-shame guardrail enforced: no numeric day counts in user-visible copy.

## Issue status

### Pass 4 — done

- **#052** — Pass 4.1: Firebase scaffolding + real Auth replaces mock sign-in/sign-up. `firebase_core` + `firebase_auth` deps; `flutterfire configure` against `connect-me-e20b1` across android/ios/macos; `firebaseAuthProvider` provides `FirebaseAuth.instance` (test override is `MockFirebaseAuth` from `firebase_auth_mocks`); auth screen handlers call FirebaseAuth with inline error messages keyed off Firebase error codes, written in the app's voice; settings sign-out signs out of Firebase first. (commit `ac9e705`)

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
- **#051** — `recommendationsProvider` does not yet load `MemoryStore.listAll()` into the engine's `memories` parameter. The engine's Q12 upcoming-driven cards are fixture-tested but cannot fire in the running app until that wiring lands. Surfaces naturally during Pass 4.3 when `LlmAiUpdate` starts populating `MemoryDocument.upcoming` for real, but is independent and can ship sooner.

### Pass 4 — in progress

- **Pass 4.2** — not started. `FirebaseMemoryStore` adapter. Per-contact memory docs to Firestore keyed by `userId/contactId`. Real security rules replace test mode.
- **Pass 4.3** — not started. `LlmAiUpdate` adapter. API key UX. Real LLM populates `MemoryDocument.upcoming` for real (lights up #051).
- **Pass 4.4** — not started. Cloud Functions + FCM for cross-device push. Multi-device conflict resolution.
- **#055** (rules CI + rules-only auto-deploy) shipped on a feature branch. One-time setup checklist at `docs/operations/firebase-rules-deploy.md`.

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
| `4ba3b69` (Pass 3 #050 merged) | 289 passed, 0 failed | Test rewrites kept count even after cleanup |
| `ac9e705` (Pass 4.1 #052 merged) | **289 passed, 0 failed** | Firebase Auth swap; existing tests adapt via MockFirebaseAuth |

## Verification

- `flutter analyze`: 1 pre-existing info lint at `lib/src/features/ai_update_screen.dart:116` (`use_build_context_synchronously`). Out of scope per the Pass 3 PRD.
- `flutter test` (full sweep): **289 passed, 0 failed**.
- All 11 Pass 3 feature branches plus the Pass 4.1 branch retained on the remote for traceability.
- **Real-device verification of Pass 4.1 is pending** — see "Pass 4 verification before 4.2" above. Firebase Auth has not been exercised against a real device yet; the test sweep validates the Dart-side wiring through `MockFirebaseAuth`.

## Notes for the next session

- **Pass 4.1 is shipped behind a real-device verification gate.** Before starting Pass 4.2, run the app on iOS/Android/macOS and exercise sign-up, sign-out, sign-in, and a wrong-password attempt against the live `connect-me-e20b1` project. If any of those fail (config files mislocated, bundle ID mismatch, network errors), fix as a hotfix issue before touching Firestore.
- **Pass 4.2 is the natural next move.** `FirebaseMemoryStore` adapter. Production `memoryStoreProvider` swaps from `FileMemoryStore`. The Pass 4.1 "test mode" Firestore rules need to flip to real rules (read/write to `users/{uid}/memories/{contactId}` only when `request.auth.uid == uid`). Local file store stays as offline cache or test-only.
- **Pass 4.3 is independent of Pass 4.2** and could ship in parallel if the LLM API key UX is more interesting than the Firestore migration. The Pass 4.1 unified `AiUpdate` seam is what makes this a single-adapter swap.
- **#051 wiring lights up best alongside Pass 4.3** because that's when `MemoryDocument.upcoming` actually gets populated. Independent though, and can ship sooner.
- **The Mock topic extractor's keyword list is a known throwaway.** When `LlmAiUpdate` lands the keyword list goes away and the LLM does real semantic extraction. Don't grow the list further; let it die.
- **The `## Upcoming` section in memory format is currently empty in production** because `MockAiUpdate` doesn't populate it (extracting "tomorrow" / "for a week" deterministically is too brittle for a mock). Demo paths can hand-edit a memory file under `<app_documents>/memories/` to see the engine's special cards fire.
- **No background scheduler exists.** The Q2 dual-invalidation model assumes the user opens the app to trigger recompute. Push-style "we noticed you haven't talked to Mike" notifications are Pass 4.4 Firebase work, not Pass 3.
- **Firebase project ID: `connect-me-e20b1`.** Free trial credits in use.

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
