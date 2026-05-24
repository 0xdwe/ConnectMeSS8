# Progress

## Current status

**Pass 1 (home/people UI consistency)** — shipped, including review fixes.
**Pass 2 (contact profile redesign)** — shipped, including review fixes.
**Pass 3 (per-contact memory files with agentic AI)** — shipped on 2026-05-19. All 11 issues (#040–#050) merged to `main`.
**Pass 4 begins.** Pass 4.1 (#052, Firebase Auth) shipped on 2026-05-21. Pass 4.2 in progress: #054, #055, #056, #057, #058, #062, #059 merged on 2026-05-24. Remaining: #060 (production cutover + offline two-device smoke), #061 (closeout), and the pending #053 real-device verification gate.
**Test baseline** — default `flutter test` sweep on `main`: **273 passed, 33 failed** (commit after #059 merge). All 33 failures are widget-test fixture drift from the unrelated `ui-login-page` and `fix-navbar` UI merges (commits `7694253`, `88ebfcc`) — missing 'Plan' nav text, missing 'home-tab'/'auth-mode-signup'/'update-with-ai-button' keys, layout regressions in connection-score / recommendation-card / section-title, and minimum-touch-target drops on the planner calendar. Tracked separately. Pre-Pass-4.2 baseline at `ac9e705` was 289 passed, 0 failed. Pass 4.2 work itself is green: `flutter test test/state/` shows 130 passing, including the new `disk_to_firestore_migration_test.dart` (#059) and the recommendation-cache identity invariant test (#062). Emulator-backed `flutter test integration_test` runs separately (see `integration_test/firebase_test_setup.dart`).

## Pass 4 sub-pass plan

The unified `AiUpdate` seam from Pass 3's Q1 was specifically shaped to make Pass 4 a one-adapter swap per concern. Sub-passes are independent except where noted; 4.1 is the load-bearing scaffolding for 4.2 and 4.4.

- **Pass 4.1 — Firebase scaffolding + real Auth.** ✅ **Shipped (#052, commit `ac9e705`).** `flutterfire configure` against project `connect-me-e20b1` across android/ios/macos. `firebase_core` + `firebase_auth` deps. `firebaseAuthProvider` in `lib/src/state/firebase_providers.dart`. Auth screen sign-in/sign-up swap to FirebaseAuth. Settings sign-out signs out of Firebase first. 9 widget tests gained `firebaseAuthProvider` overrides via `MockFirebaseAuth` from `firebase_auth_mocks`.
- **Pass 4.2 — `FirebaseMemoryStore` adapter.** In progress. Seven of nine issues merged on 2026-05-24: #054 (rules + emulator + JS rules tests), #055 (rules CI + auto-deploy), #056 (Dart Firestore emulator scaffold), #057 (`FirebaseMemoryStore` adapter behind seam), #058 (auth-aware `memoryStoreProvider`), #062 (recommendation-cache auth rebuild), #059 (one-shot disk-to-Firestore migration). Production `memoryStoreProvider` already returns `FirebaseMemoryStore` for signed-in users. Local `FileMemoryStore` remains as a tested debug/reference adapter and migration source. Remaining: #060 (production cutover + offline two-device smoke), #061 (closeout).
- **Pass 4.3 — `LlmAiUpdate` adapter.** Not started. Real LLM behind the unified `AiUpdate` seam. API key UX in settings (`flutter_secure_storage` for the key). Retry, timeout, cancellation. The Mock keyword list dies; the LLM populates `MemoryDocument.upcoming` for real, which lights up the engine logic from #049 + the wire-up in #051.
- **Pass 4.4 — Cross-device sync + push.** Not started. Cloud Functions on Firestore writes; FCM for "we noticed you haven't talked to Mike" pushes. Last-writer-wins conflict resolution for the prototype.

## Pass 4.1 real-device verification gate (#053)

Before #060 cuts production over to Firestore, the running app should be verified on a device against the real Firebase project:

1. Run the app on a real (or simulated) device.
2. Sign up with a fresh email + password (≥6 chars). The account should appear under Authentication in the Firebase console.
3. Sign out from the settings tab.
4. Sign back in. Wrong password should produce the inline "that password doesn't match" error.
5. If anything fails (config files in the wrong place, bundle ID mismatch, network errors): file as a hotfix issue before #060.

All of this works behind the existing test sweep with `MockFirebaseAuth`, so the gate is real-device testing rather than `flutter test`. **Status: pending.** #054–#058 landed before this gate on the assumption that the rules / adapter / provider work was reversible without touching production memory; the cutover (#060) should not land until the gate passes.

For emulator-backed Dart tests (Pass 4.2 emulator-backed tests, #056 onward) the canonical command is:

    firebase emulators:exec --only firestore,auth --project connect-me-rules-test "flutter test integration_test -d macos"

Default `flutter test` leaves headless tests untouched because emulator-backed tests live under `integration_test/`, which is a separate target from the `test/` tree. JDK 21+ on `PATH` is required for the emulator (`brew install openjdk@21`).

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
- **#054** — Firestore rules + emulator + JS rules tests. `firebase.json` configures auth(9099)/firestore(8080) emulators. `firestore/firestore.rules` enforces ownership and shape (`hasOnly`/`hasAll` on `{markdown, updatedAt, schemaVersion}`, `markdown is string`, `size() <= 65536`, `updatedAt is timestamp`, `schemaVersion is int`); 27 JS test cases in `firestore/rules.test.js` cover allow/deny including anon, cross-user, oversized, and sibling-path. (merge commit `83fad2a`)
- **#055** — Rules CI + rules-only auto-deploy. PR workflow `.github/workflows/rules-tests.yml` runs JS rules tests on `firestore/**` changes. Main-branch workflow `.github/workflows/rules-deploy.yml` deploys only Firestore rules to `connect-me-e20b1` after tests pass, using `FIREBASE_SERVICE_ACCOUNT` secret. One-time setup checklist at `docs/operations/firebase-rules-deploy.md`. (merge commit `85127d0`)
- **#056** — Dart Firestore emulator test scaffold. Helper at `integration_test/firebase_test_setup.dart` initializes Firebase, routes `useFirestoreEmulator(localhost, 8080)` and `useAuthEmulator(localhost, 9099)`, exposes idempotent `setUpEmulators()` / `tearDownEmulators()`. Substrate lives under `integration_test/` so default `flutter test` skips it. (merge commit `d5be288`)
- **#057** — `FirebaseMemoryStore` adapter behind the seam. Third `MemoryStore` adapter at `lib/src/state/memory/firebase_memory_store.dart`, bound to one UID at construction, writes `{markdown, updatedAt: serverTimestamp, schemaVersion: 1}` at `users/{uid}/memories/{contactId}`. Emulator tests cover round-trip, missing, delete, listAll, schemaVersion, oversized→trim, oversized→exception, cross-user denial. (merge commit `938f4a0`)
- **#058** — Auth-aware `memoryStoreProvider` rebuild. Production `memoryStoreProvider` watches `currentUserProvider`; signed-in users get `FirebaseMemoryStore(firestore: ..., uid: user.uid)`, signed-out access throws via `_SignedOutMemoryStore`. `currentUserProvider` and `firestoreProvider` added to `lib/src/state/firebase_providers.dart`. Auth swap rebuilds the store; `memoryProvider` and `memoryTopicsProvider` invalidate via the watch chain. (merge commit `69d346d`)
- **Hotfix on `fix/current-user-provider-invalidation-loop` (commit `792fcdb`, merged via `40d0b0c`)** — `currentUserProvider` self-invalidate loop. Real `FirebaseAuth.authStateChanges()` replays the current user on every new subscriber; the original `listen((_) => ref.invalidateSelf())` rebuilt the provider, resubscribed, replayed, invalidated, looping forever. `memorySeedingProvider` watched it, so iPhone simulator launches showed an indefinite white screen behind `_MemorySeedingSplash`. Fixed by only invalidating when the emitted UID differs. Regression test at `test/state/firebase_providers_test.dart` reproduces with a custom fake that mimics the real replay-on-subscribe contract.
- **#062** — Recommendation-cache auth rebuild (follow-up to #058 AC4). `recommendationsProvider` now `ref.watch(memoryStoreProvider)`, and `_RecommendationsCache` carries the active store reference so its identity is part of the cache freshness check (alongside time, memoryEpoch, connections-identity, interactions-identity). Without this, the long-lived `RecommendationsNotifier` instance survives an override swap and the existing freshness invariants would pass, serving user A's cached list to user B. Bounded today only because `memories: const {}` is still passed to the engine; closes the leak before #051 lands. (merge commit `0227a8e`)
- **#059** — One-shot disk-to-Firestore migration. `DiskToFirestoreMigration` copies on-disk markdown memories into Firestore on first authenticated launch when the remote collection is empty. Source files preserved (PRD Q6 invariant). Sentinel at `users/{uid}.migratedFromDiskAt` written via transaction + `merge: true`. `memorySeedingProvider` now awaits `diskToFirestoreMigrationProvider` before its own listAll bootstrap, so seeding cannot starve the migration. `firestore/firestore.rules` gains a narrow `match /users/{uid}` block (owner-only read/create/update for `migratedFromDiskAt` timestamp; delete locked); `firestore/rules.test.js` adds 10 sentinel cases (38 total). Headless and emulator-backed migration tests cover copy / sentinel / idempotency / non-empty skip / source preservation / partial-run recovery.

### Pass 4 — in progress

- **#053** — Pass 4.1 real-device verification gate. **Status: pending.** #054–#059 landed before this gate; the cutover (#060) should not land until the device smoke is captured.
- **#060** — Production cutover + offline two-device smoke. Updated AC: cutover already wired in #058, net-new code is offline persistence config (`Settings(persistenceEnabled: true)`), two-device smoke needs platforms + evidence destination, plus rules-denial evidence and an iOS-coverage clause.
- **#061** — Pass 4.2 closeout + docs/progress update.

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

### Open and pickable

- **#037** — Orphaned `ProfileScreen` and `HeatmapCard`. Pick one of two paths: delete the orphan code, or restore an entry point on the shell. Severity: nice-to-have. Not on the critical path.
- **#039** — Architecture deferred cleanup candidates (`InteractionType` Flutter leak; by-id query providers shape). Both small refactors that earn their keep when their consumers move; not blocking.
- **#051** — `recommendationsProvider` does not yet load `MemoryStore.listAll()` into the engine's `memories` parameter. The engine's Q12 upcoming-driven cards are fixture-tested but cannot fire in the running app until that wiring lands. Surfaces naturally during Pass 4.3 when `LlmAiUpdate` starts populating `MemoryDocument.upcoming` for real, but is independent and can ship sooner. AC updated 2026-05-24 to address Pass 4.2 (signed-out sentinel handling, FirebaseMemoryStore-backed Option C).

### Pre-Pass-4 done (carried forward)

- **#001–#039** — earlier waves through the architecture-deepening review. See git history for details.
- **#040–#050** — Pass 3 issues. See "Pass 3 summary" below.

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
| `ac9e705` (Pass 4.1 #052 merged) | 289 passed, 0 failed | Firebase Auth swap; existing tests adapt via MockFirebaseAuth |
| `83fad2a` (#054 merged) | (rules CI tests are JS, not in this sweep) | No `test/` tree change. |
| `85127d0` (#055 merged) | (workflow files only) | No `test/` tree change. |
| `d5be288` (#056 merged) | (integration_test scaffold) | No change to default `flutter test`. |
| `938f4a0` (#057 merged) | (integration_test only) | Adapter tests live under `integration_test/`. |
| `69d346d` (#058 merged) | 291 passed, 0 failed (estimate) | +2 headless `memory_store_provider_test.dart` cases (the third needs the emulator). Final number to be confirmed once the UI-merge regression at `7694253` is sorted. |
| `7694253` (UI merges from `ui-login-page` + `fix-navbar`) | **262 passed, 33 failed** | Widget-test fixture drift from auth/shell/home/profile/planner UI changes. Not Pass 4.2 work; tracked separately. |
| `792fcdb` (currentUserProvider hotfix on `fix/current-user-provider-invalidation-loop`) | 264 passed, 33 failed | +2 new `firebase_providers_test.dart` cases. UI-merge regression unchanged. |
| `0227a8e` (#062 merged) | 265 passed, 33 failed | +1 recommendation-cache auth-rebuild test. |
| #059 merged (this commit) | **273 passed, 33 failed** | +8 headless `disk_to_firestore_migration_test.dart` cases. UI-merge regression unchanged; verified all 33 failures are the same widget-test drift family (missing nav text, hit-area regressions, layout drift). |

## Verification

- `flutter analyze`: 1 pre-existing info lint at `lib/src/features/ai_update_screen.dart:116` (`use_build_context_synchronously`). Out of scope per the Pass 3 PRD. Plus a handful of new `withOpacity` deprecation infos and unused-field warnings introduced by the recent UI merges; not Pass 4.2 work.
- `flutter test` (full sweep, `docs/pass4-2-review-fixes` branch off main `7694253`): **262 passed, 33 failed**. After merging the `currentUserProvider` hotfix: 265 passed, 32 failed. The 32 remaining failures are widget-test fixture drift from the unrelated UI merges; tracked as a separate hotfix.
- `flutter test test/state/` (Pass 4.2 layer only, on the hotfix branch): **121 passed, 0 failed.**
- All Pass 3 + Pass 4.1 + Pass 4.2 feature branches retained on the remote for traceability.
- **Real-device verification of Pass 4.1 (#053) is pending.** Web (Chrome) launch verified on 2026-05-24 — the `currentUserProvider` loop only manifests on iOS / mobile Firebase platforms because of the SDK's replay-on-subscribe contract. Real iOS simulator verification is captured under #053.

## Notes for the next session

- **Pass 4.2 is six issues deep, three to go.** #054, #055, #056, #057, #058 merged on 2026-05-24. Production `memoryStoreProvider` already returns `FirebaseMemoryStore` for signed-in users via `lib/src/state/memory/memory_providers.dart`; #060's job is to enable explicit Firestore offline persistence and to capture real two-device smoke evidence. #053 (Pass 4.1 real-device verification) is still pending and should be cleared before #060.
- **iOS hotfix on `fix/current-user-provider-invalidation-loop`.** `currentUserProvider` self-invalidate loop fixed; Chrome web was unaffected because the web Firebase SDK does not replay `authStateChanges()` on subscribe. The branch carries one regression test. Merge before #060.
- **#059 has rules + ordering work hidden in the AC.** The migration's `migratedFromDiskAt` write to `users/{uid}` is currently default-denied (`firestore/firestore.rules` only matches `users/{uid}/memories/{contactId}`); rules + JS rules tests need to land with the migration. Migration also has to coordinate with `memorySeedingProvider` so seeding doesn't fill the remote first and starve the migration's empty-collection guard.
- **#062 is the small remaining piece of the #058 review.** `recommendationsProvider` should `ref.watch(memoryStoreProvider)` (or `currentUserProvider`) so a sign-in-as-different-user can't serve user A's cached recommendations. Bounded today only because `memories: const {}` is still passed; becomes a real cross-user leak once #051 lands.
- **The Mock topic extractor's keyword list is a known throwaway.** When `LlmAiUpdate` lands the keyword list goes away and the LLM does real semantic extraction. Don't grow the list further; let it die.
- **The `## Upcoming` section in memory format is currently empty in production** because `MockAiUpdate` doesn't populate it (extracting "tomorrow" / "for a week" deterministically is too brittle for a mock). Demo paths can hand-edit a memory file under `<app_documents>/memories/` to see the engine's special cards fire.
- **No background scheduler exists.** The Q2 dual-invalidation model assumes the user opens the app to trigger recompute. Push-style "we noticed you haven't talked to Mike" notifications are Pass 4.4 Firebase work.
- **Firebase project ID: `connect-me-e20b1`.** Free trial credits in use. `connect-me-rules-test` is a separate emulator-only project namespace, not a typo.
- **UI-merge regression on `main`.** The `ui-login-page` and `fix-navbar` merges (commits `7694253`, `88ebfcc`) brought 32 widget-test failures onto `main`. Out of scope for Pass 4.2; deserves its own hotfix issue.

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
