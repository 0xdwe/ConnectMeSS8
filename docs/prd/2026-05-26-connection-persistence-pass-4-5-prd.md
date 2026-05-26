# Pass 4.5 — Connection / Interaction / Event Persistence (post-grilling)

Labels: prd, ready-for-issues

> Builds on: Pass 4.2 `FirebaseMemoryStore` seam (#057, #058) and the disk-to-Firestore migration pattern (#059).
> Carries the same Firestore project (`connect-me-e20b1`), the same auth-aware provider pattern, the same emulator + JS rules test substrate.
> Status: **post-grilling.** Implementation decisions below incorporate adversarial review feedback.

## Problem Statement

Pass 4.2 made per-contact relationship memory durable across devices. The AI summary, history, topics, and upcoming events for each person now live at `users/{uid}/memories/{contactId}` and follow the user across sign-in, sign-out, app reinstall, and second devices.

The connections those memories are keyed against do not. The list of who the user knows — and the interactions and planner events tied to those connections — still lives in `AppController` state in memory, seeded from a hardcoded list (Mike, Sarah, Emily, David), reset to that seed on every sign-out (until the prototype hotfix that just shipped), and never persisted anywhere durable.

The user-visible failure mode is severe: a user can remove the sample contacts, add their real friends and family, log interactions, schedule events, and lose all of it the moment they sign out and back in. The prototype hotfix (sign-out preserves user-added connections on the same device) lowers the immediate pain but does not fix the cross-device promise. Sign in on a second device, you see no connections at all. Reinstall the app, your contact list is gone.

This is the Pass 4.2 PRD's blind spot. Pass 4.2 stated "memory follows the user, not the install" and shipped the per-contact memory side of that promise. The connection list itself was never named — neither in scope nor in "Out of Scope." Pass 4.3 (`LlmAiUpdate`) and Pass 4.4 (Cloud Functions + FCM push) both assume durable user data; making the AI smarter does not help if your contacts vanish on sign-out, and pushing notifications about people you no longer "have" in the app is worse.

The architectural cost of fixing this is moderate, not large. Pass 4.2 already paid the seam cost: auth-aware provider rebuild, signed-out sentinel, Firestore rules with shape validation, emulator-backed adapter tests, JS rules tests in CI, one-shot disk-to-Firestore migration, rules-only auto-deploy. Pass 4.5 walks the same path for a different document family.

## Solution

Pass 4.5 introduces three new Firestore-backed stores mirroring `MemoryStore` from Pass 3 / 4.2:

- `ConnectionStore` — `users/{uid}/connections/{contactId}` (one document per connection).
- `InteractionStore` — `users/{uid}/interactions/{interactionId}`.
- `EventStore` — `users/{uid}/events/{eventId}`.

Each store has the same shape as `MemoryStore`: an interface, two adapters (`InMemoryConnectionStore` for tests, `FirebaseConnectionStore` for production), an auth-aware provider that swaps based on `currentUserProvider`, a one-shot migration from `AppController` seeded state on first authenticated launch, and Firestore rules that enforce ownership + shape.

`AppController` becomes thin. The 10+ mutating methods (`addConnection`, `deleteConnection`, `updateConnection`, `logInteraction`, `addEvent`, etc.) write through the appropriate store first, then update Riverpod state to reflect the write. The same write-then-state contract from `AiUpdate.commit` (Pass 3 Q4 / Pass 4.2 Q8) extends across the whole app.

Sign-out drops the in-memory mirror; sign-in rebuilds the mirror from Firestore. The hotfix path (preserve non-sample on sign-out) goes away because there is no longer any reason to preserve in-memory state — the durable record is in Firestore.

The migration runs once per Firebase account on first authenticated launch when the user's `users/{uid}/connections` collection is empty. It seeds Mike, Sarah, Emily, David, plus their interactions and events (the existing demo content) only for accounts that opted in, or it leaves the account empty for users who want a clean start. The exact migration semantics are an open grilling question — see Q5 below.

Pass 4.5 also reconciles the orphan-memory case from Pass 4.2: memory documents at `users/{uid}/memories/{contactId}` whose `contactId` no longer appears in `users/{uid}/connections`. The reconciliation runs on sign-in alongside the migration and is a question for grilling — see Q9.

## User Stories

1. As a ConnectMe user, I want my contact list to follow my login, so that signing in on a second device shows the same people.
2. As a busy professional, I want a connection I added on my phone to be available later on my laptop.
3. As a user with ADHD, I want signing out and back in to NOT wipe my contacts; I have already lost too much in life.
4. As a user, I want interactions I log on Mike to follow Mike across devices.
5. As a user, I want planner events I schedule with Sarah to be there when I sign in on a second device.
6. As a user, I want the app to NOT mix my partner's contacts into my list when we share a device.
7. As a user, I want my contacts to be deleted across all my devices when I delete one on this device.
8. As a user, I want to start with the sample contacts (Mike, Sarah, Emily, David) only if I want a guided tour, and I want to be able to start fresh otherwise.
9. As a user, I want an interaction to be saved to the cloud the moment I confirm it, not when the app feels like syncing.
10. As any user, I want the app to keep working when my network is unreliable; offline writes should queue and replicate.
11. As any user, I want to prevent another signed-in user from reading my contacts.
12. As any user, I want the app to reject malformed contact writes at the backend, so a buggy client cannot poison my account.
13. As a developer, I want connections + interactions + events stored under the same `users/{uid}/...` UID-scoped tree as memories, so the auth-aware provider story stays uniform.
14. As a developer, I want the existing `AiUpdate.commit` write-then-state contract to extend to connection mutations, so the rollback semantics stay consistent across the app.
15. As a developer, I want existing widget tests to keep using `InMemory*Store` overrides so the UI suite stays fast.
16. As a developer, I want the migration semantics (sample-or-empty on first sign-in) decided in the grilling phase before code starts, not after.
17. As a developer, I want orphan memory documents reconciled on sign-in, so a user who deleted Sarah on device 1 doesn't see Sarah's memory document referenced from a phantom card on device 2.

## Implementation Decisions (tentative — pending grilling)

### Q1 — Scope: connections, interactions, events; or just connections?

Three separate stores, sharing infrastructure but with distinct schemas. Tentative: ship all three together because they always travel together — a contact card without its events / interactions is useless for the user. Splitting them across passes adds artificial coupling between in-memory connections and Firestore-backed interactions.

Counter-argument worth grilling: ship connections first to limit the blast radius, then interactions + events as Pass 4.5.1.

### Q2 — Document model

Tentative: each `Connection`, `CrmInteraction`, and `PlannerEvent` becomes one Firestore document. Field names match the existing Dart models. `schemaVersion: 1` on all three.

Connection document shape (~12 fields including: name, email, category, avatar, bondScore, nextStep, lastContact, notes, knownSince, preferredChannels, isSample). Approx 1-2 KB per doc. Worst case 10 KB.

Open question for grilling: does `bondScore` (computed from interactions) live as a denormalized field on the connection doc, or does the client compute it from interactions on every load?

### Q3 — Auth-aware providers

Same pattern as `memoryStoreProvider`: `connectionStoreProvider`, `interactionStoreProvider`, `eventStoreProvider`. Each watches `currentUserProvider`. Signed-out access throws via a sentinel. The `RecommendationsCache` identity-pinning trick from #062 extends to connection / interaction stores: pin store identity into any cache invariant tuple that crosses an auth swap.

### Q4 — `AppController` rewrite

`AppController` becomes a thin ViewModel over the three stores. Methods that previously did `state = state.copyWith(connections: [...])` become async: `await _connectionStore.save(connection); state = state.copyWith(connections: (await _connectionStore.listAll()).values.toList());` (or via a snapshot listener mirror — see Q6).

The rewrite is the largest single piece of work in the pass. Counted against `lib/src/state/app_state.dart`: **13 mutating methods** touch connection / interaction / event state today.

1. `addConnection` (line 385)
2. `updateConnection` (line 386)
3. `deleteConnection` (line 395) — cascades connections + events + interactions + memory delete (multi-store)
4. `removeSampleConnections` (line 417) — cascades connections + events + interactions (multi-store)
5. `logInteraction` (line 439)
6. `addEvent` (line 456) — delegates to `saveEvent`
7. `saveEvent` (line 475)
8. `deleteEvent` (line 488)
9. `restoreEvent` (line 501)
10. `applyAiUpdateResult` (line 560) — mutates interactions + connection.bondScore (multi-store)
11. `renameEventType` (line 521) — cascades to events
12. `deleteEventType` (line 539) — cascades to events
13. `signOut` (line 312) — collapses to trivial under Pass 4.5 (the hotfix preservation goes away)

The two costly methods are `deleteConnection` and `applyAiUpdateResult`. Both mutate two collections in the same logical operation. The Pass 3 / Pass 4.2 `AiUpdate.commit` write-then-state contract was single-document. Pass 4.5 has multi-store-multi-document writes, and the rollback path is harder.

Multi-store atomic write contract (extends Pass 3 Q4):

- For `deleteConnection`: Firestore batched write across `connections/{id}` (delete) + `interactions/{id}` (filtered delete) + `events/{id}` (filtered delete) + `memories/{id}` (delete). Firestore batched writes are atomic for documents in the same project, so all-or-nothing holds.
- For `applyAiUpdateResult`: Firestore batched write across `interactions/{newId}` (create) + `connections/{contactId}` (update bondScore + lastContact). Atomic per the same batch.
- On batch failure: the existing `AiUpdate.commit` retryable error path runs; the in-memory state is not advanced.

### Q5 — First-sign-in: seed samples or start empty?

Three options:

- **A.** Always seed Mike/Sarah/Emily/David on first sign-in. Matches today's behavior. Sample contacts are demo data and a new user expects to see them.
- **B.** Always start empty. New users build their own list from zero. Discoverable via an "Add sample contacts" button in onboarding.
- **C.** Ask once at sign-up. Onboarding offers "Start with sample contacts" or "Start fresh."

**Decided: C.** Forces the decision into the user's hands, makes the seed sample explicit (not a thing the app silently injects), and avoids the awkward "I deleted the samples but they came back when I reinstalled" failure mode the Pass 4.2 grilling missed.

**Onboarding placement.** The prompt fires on the auth screen's `_AuthMode.signup` flow, AFTER `signUp()` succeeds and BEFORE the first navigation to the shell. It does NOT fire on `_AuthMode.login` — a user signing in to an existing account either has connections in Firestore (no seeder runs) or has the sentinel set with no connections (the user picked "Start fresh" on a previous device).

**Empty-state UX.** A user who picked "Start fresh," or who signs in on a second device to an account that picked fresh, sees an empty People tab and an empty Home recommendations list. Pass 4.5 ships an empty-state on the People tab with a "Add your first contact" CTA and on the Home recommendations list with a calmer placeholder. The empty-state copy is in scope for Pass 4.5.

### Q6 — Read shape: pull-on-mutation vs. snapshot listener

Two ways to keep `AppController.state.connections` in sync with Firestore:

- **A.** Pull-on-mutation. Each `add`/`update`/`delete` re-reads `listAll()`. Simple, but every mutation does a full collection read.
- **B.** Snapshot listener. The store opens a `snapshots()` subscription to `users/{uid}/connections` at construction; updates flow through Firestore's local cache and into a mirror `Map<String, Connection>` that `AppController.state` reads from.

**Decided: B.** Aligns with Firestore's intended shape, lights up cross-device sync automatically (a write on device A propagates to device B's listener), avoids the "I added a connection on phone, switched to laptop, didn't see it until I added another connection" failure mode.

**Honest cost.** Pass 4.2's `FirebaseMemoryStore` is request-response: pure `.get()` / `.set()` / `.delete()` per call, no listener, no mirror. Pass 4.5 introduces a NEW pattern, not a reused one. The new code includes:

- A `snapshots()` subscription opened at store construction.
- A mirror `Map<String, T>` updated on each snapshot event.
- Lifetime management: subscription tears down on sign-out via the auth-aware provider rebuild's `onDispose`; re-establishes on sign-in via store reconstruction.
- Listener-error handling (network errors, permission errors during sign-out race).
- A new test surface: fake snapshot streams in headless tests, real subscription verification in emulator tests.

**Subscription mirror placement.** The mirror lives inside the store. `ConnectionStore.snapshot()` returns the current `Map<String, Connection>` synchronously. `AppController` reads the mirror via the store; Riverpod sees the store rebuild via `currentUserProvider`, but the inner subscription is the store's responsibility, not Riverpod's. This keeps `AppController` testable with `InMemory*Store` fakes that don't open subscriptions.

### Q7 — Initialization (not migration) semantics

The word "migration" misleads here. Pass 4.2's `DiskToFirestoreMigration` was a real disk-source → cloud-target copy of `FileMemoryStore` documents that existed on the user's device. Pass 4.5's connection data was never on disk — it was always RAM, seeded from constants. So this is a one-shot **seeder** (or "first-launch initializer"), not a migration. Class names and tests reflect that: `ConnectionSeeder`, not `ConnectionMigration`.

The seeder is gated on the empty-remote check exactly like the Pass 4.2 migration. Sentinel writes go to three separate timestamp fields on `users/{uid}` (NOT a combined map):

- `connectionsSeededAt`
- `interactionsSeededAt`
- `eventsSeededAt`

Three separate fields mirror Pass 4.2's `migratedFromDiskAt` exactly and avoid Map shape validation in rules.

**Source semantics.** The seeder writes the seeded sample list (Mike/Sarah/Emily/David + their interactions and events from `AppState.seeded()`) IF the user picked "Start with sample contacts" in Q5's onboarding. If the user picked "Start fresh," the seeder is a sentinel-only no-op: `connectionsSeededAt` is set, the collections stay empty, future runs short-circuit on the sentinel.

**Hotfix-era data loss is accepted, with a one-time reconciliation.** A user on the hotfix build today has user-added connections in `AppController` state RAM. When they upgrade to the Pass 4.5 build, the app process restarts and that RAM is gone before Pass 4.5 code runs. The seeder cannot recover them. The PRD explicitly accepts this loss: hotfix-era user-added connections are not preserved across the Pass 4.5 upgrade. The hotfix was a single-device emergency stop-gap, not a durable persistence mechanism.

To reduce the surprise, Pass 4.5's first-sign-in path on the Pass 4.5 build emits a **one-time "data persistence has been upgraded"** notice in the UI when both: (a) `connectionsSeededAt` was just written, and (b) the auth account already existed before the Pass 4.5 build. The notice copy is in scope for Pass 4.5.

Alternative considered and rejected: extending the hotfix to write user-added connections to disk before Pass 4.5 ships, then having Pass 4.5's seeder pick them up. Rejected because (a) it doubles the hotfix scope; (b) it requires shipping a separate disk-write release; (c) the user base is small and the loss is one-time.

### Q8 — Firestore rules

Three new owner-scoped, shape-validated `match` blocks:

- `match /users/{uid}/connections/{contactId}`
- `match /users/{uid}/interactions/{interactionId}`
- `match /users/{uid}/events/{eventId}`

The 64KB cap doesn't apply (these documents are small); rules enforce the field set, optional-field handling, enum-string-set values, and bondScore range.

**Optional-field handling.** Pass 4.2's `hasOnly([...]) && hasAll([...])` does NOT work for genuinely optional Firestore fields. Pass 4.5 rules use a closed-shape `hasOnly` plus per-field `data.x is type || !('x' in data)` guards for nullable fields. Specifically:

- Connection: `bondScore is int && bondScore >= 0 && bondScore <= 100`. `notes`, `email` validated as strings (allowed empty). `isSample is bool` if present, optional.
- CrmInteraction: `type in ['interaction', 'personalDetail', 'goal', 'task', 'aiSuggested', 'archived']` (the actual Dart enum values from `lib/src/models/social_models.dart` — verify exact strings during implementation). `source in [...]` similarly.
- PlannerEvent: `contactId is string || !('contactId' in data)`, same pattern for `startTimeMinutes`, `endTimeMinutes`, `recurrencePattern`. `eventType` is NOT validated server-side because the eventTypes list is per-user data; bad client data is recoverable client-side.

**Sentinel rules.** The existing `match /users/{uid}` block (from #059, allowing `migratedFromDiskAt`) gains the new optional timestamp fields: `connectionsSeededAt`, `interactionsSeededAt`, `eventsSeededAt`, `categoriesSeededAt`, `eventTypesSeededAt` (the last two for Q12). All optional, all timestamps, owner-only writes.

### Q9 — Orphan memory reconciliation

Memory documents at `users/{uid}/memories/{contactId}` whose `contactId` no longer exists in `users/{uid}/connections` are orphans.

**Decided: deferred to Pass 4.6.**

During grilling, two specific risks surfaced for in-Pass-4.5 reconciliation:

1. Race condition with the snapshot listener: on sign-in, the connections snapshot loads asynchronously. Reconciliation that reads `users/{uid}/connections` before the cache populates would see every memory as orphaned.
2. Aggressive deletion (option A) is irreversible; options B and C are harmless or generative.

For Pass 4.5, orphan memories are left in place. They occupy Firestore document slots but don't surface in the UI. A future Pass 4.6 (or sooner if users complain) ships option C — a "restore this contact?" prompt that reads memories without a connection and offers to recreate the connection card.

**One reconciliation step Pass 4.5 DOES ship:** when the user explicitly deletes a connection via `deleteConnection`, the memory document at the same `contactId` is also deleted as part of the multi-store atomic batch (see Q4). This already happens today for `MemoryStore.delete`; Pass 4.5 keeps that contract.

### Q10 — Test substrate

Same as Pass 4.2:

- Headless tests under `test/state/` for the in-memory adapter and the auth-aware provider.
- Emulator-backed tests under `integration_test/state/` for the Firestore adapter, seeder, and rules-deny cases.
- JS rules tests in `firestore/rules.test.js` extend to cover the new collections.

The CI rules-deploy workflow from #055 picks up the rules update automatically; no workflow changes needed.

**Test count estimate (revised after grilling).** Pass 4.2 added ~80+ tests for ONE document family. Pass 4.5 ships THREE families plus a new snapshot listener pattern. Realistic estimate: **+120-180 tests** across:

- Three in-memory adapter test suites (~30 tests).
- Three emulator-backed adapter test suites (~45 tests).
- Three auth-aware provider test suites (~15 tests).
- Snapshot-listener-specific tests (lifetime, teardown, error handling) (~10 tests).
- Multi-store atomic write tests for `deleteConnection` and `applyAiUpdateResult` (~10 tests).
- Seeder tests (~15 tests).
- Rules tests (allow / deny / shape per collection) (~25 tests in JS).
- AppController rewrite contract tests (~15 tests).
- Onboarding prompt tests (~5 tests).

The headless test substrate gains three new fakes (`_RecordingConnectionStore`, etc.) plus a fake snapshot stream pattern. Non-trivial code addition.

### Q11 — bondScore stays a stored field

During grilling: an earlier draft framed bondScore as "computed from interactions on every load." That doesn't match the code. `Connection.bondScore` (`lib/src/models/social_models.dart:162`) is a stored `int`. `applyAiUpdateResult` (`lib/src/state/app_state.dart:560-573`) mutates it additively (`+3, clamp 0..100`), not derives it. The seeded values (95, 85, 73, 68, 92) have no derivation rule. A computed-bondScore design would be a behavior change, not a perf optimization, and is out of scope.

**Decided: keep bondScore as a stored field on the Connection document.**

Consequences:

- Rules validate `bondScore is int && bondScore >= 0 && bondScore <= 100` (Q8).
- `applyAiUpdateResult` writes both `interactions/{newId}` (create) and `connections/{contactId}` (update bondScore) in a Firestore batched write — the multi-store atomic contract from Q4.
- A Pass 4.4 Cloud Function trigger COULD denormalize bondScore server-side later (e.g. recompute from interactions on every interaction write), but Pass 4.5 keeps the client-side mutation contract that already works.

### Q12 — categories and eventTypes are user data, not app preferences

During grilling: an earlier draft treated `categories` and `eventTypes` as app preferences that live outside the auth session. That's wrong. Both are user-mutated lists (`addCategory` at `app_state.dart:508`, `addEventType` at :515, `renameEventType` at :521, `deleteEventType` at :539). A user adding "Mentor" as a category on device 1 should see it on device 2; the existing pre-Pass-4.5 behavior of resetting them to seeded constants every fresh sign-in is silently wrong.

**Decided: categories and eventTypes are part of Pass 4.5 scope.**

New Firestore documents:

- `users/{uid}.categories` — list of strings on the user document. (Tiny list, fits inline; doesn't need its own subcollection.)
- `users/{uid}.eventTypes` — list of strings on the user document.

Seeder writes the existing defaults from `AppState.seeded()` regardless of the Q5 sample-vs-fresh choice (categories like Family/Friends/Work; eventTypes like Coffee/Meeting/Birthday/Reminder are useful even for users who start fresh). Sentinels: `categoriesSeededAt`, `eventTypesSeededAt`.

This adds two more methods to AppController's rewrite scope: `addCategory`, `addEventType`, `renameEventType`, `deleteEventType` all become async writes to the user document.

### Q13 — AppUser cleanup deferred

Grilling flagged that with Firebase Auth shipped, `AppUser` (in `lib/src/models/social_models.dart:35`) duplicates auth state. `currentUserProvider.displayName` and `.email` could replace it. Three callers read `state.user`: `edit_user_profile_modal.dart:28-36`, `profile_screen.dart:18`, `shell_screen.dart:32`.

**Decided: AppUser cleanup is OUT OF SCOPE for Pass 4.5.**

Reasoning: the hotfix's known caveat ("Account A's `state.user.name` lingers into account B's session until B's first state mutation") goes away naturally when Pass 4.5's auth-aware rebuild rebuilds AppController state per-UID. The deeper cleanup (deleting the AppUser model and threading `currentUserProvider` through three callers) is pre-existing tech debt unrelated to connection persistence. File as a follow-up issue and ship Pass 4.5 without it.

### Q14 — Idiomatic Riverpod vs. AppController-as-ViewModel

Grilling raised the question: a more idiomatic Riverpod approach would use `StreamProvider<List<Connection>>` directly off Firestore snapshots, with no AppController layer. Why keep AppController?

**Decided: keep AppController as the write coordinator.**

Reasoning:

- `deleteConnection` and `applyAiUpdateResult` mutate multiple stores atomically. A pure StreamProvider shape gives no place for the multi-store batched-write contract to live.
- `removeSampleConnections` cascades across three stores.
- Recommendation cache identity-pinning (#062) lives in providers that depend on AppController's connection list, not raw Firestore streams.
- The AI Update flow and unified `AiUpdate.commit` contract from Pass 3 already depends on AppController being the write target.

AppController stays. The read paths can still be backed by snapshot listeners inside the stores; AppController's `state.connections` becomes a thin denormalization of the store's mirror map. The layer earns its keep on the write side.

### Module sketch

- **`ConnectionStore`, `InteractionStore`, `EventStore`** — interfaces matching `MemoryStore`'s shape (async load / save / delete / listAll, plus a snapshot stream for Q6).
- **`InMemoryConnectionStore` / etc.** — test-only adapters.
- **`FirebaseConnectionStore` / etc.** — production adapters bound to one UID at construction, opening a `snapshots()` subscription on init.
- **`SeedToFirestoreMigration`** — one-shot migration that copies the seeded sample list into Firestore for opted-in users.
- **`OrphanMemoryReconciler`** — Pass 4.6 deferred (per Q9).
- **Auth-aware providers** — `connectionStoreProvider`, `interactionStoreProvider`, `eventStoreProvider`, mirroring `memoryStoreProvider`.
- **`AppController` rewrite** — methods become async, write-then-state contract.
- **Firestore rules** — three new `match` blocks, owner-scoped + shape-validated.
- **Rules CI** — workflow already handles new rules; tests added to `rules.test.js`.

### Proposed issue sequence (post-grilling, ~10 issues)

1. **Pass 4.5 PRD pre-flight.** Confirm hotfix is on main, Pass 4.2 code-track complete, no in-flight branches block the seam. No code; one-time setup confirmation.
2. **`ConnectionStore` interface + `InMemoryConnectionStore` + auth-aware `connectionStoreProvider` + signed-out sentinel.** Mirrors `MemoryStore` shape. Adds the `snapshot()` method and `Stream<Map<String, Connection>>` shape to the interface. Headless tests only; no Firestore yet.
3. **`FirebaseConnectionStore` adapter behind seam, with snapshot listener.** Emulator-backed tests cover round-trip, snapshot-events, listener teardown, listener-error handling, listener-restart on auth swap, oversized rejection. Production wiring NOT yet flipped.
4. **Firestore rules + JS rules tests for connections.** `firestore/firestore.rules` gains the `connections` match block with optional-field guards and bondScore range; `firestore/rules.test.js` gains the allow/deny cases (~10 tests). Auto-deploy via #055 workflow.
5. **Same shape for interactions.** Store interface + InMemory + Firebase + provider + rules + tests. (One issue end-to-end because the pattern is now established.)
6. **Same shape for events.**
7. **`ConnectionSeeder` + onboarding "Start with samples / Start fresh" prompt + empty-state UX.** Q5 + Q7. Sentinels at `users/{uid}.connectionsSeededAt` etc. One-time "persistence upgraded" notice for hotfix-era accounts.
8. **`AppController` rewrite to write-through-store with multi-store atomic batches.** All 13 mutating methods become async. `deleteConnection` and `applyAiUpdateResult` use Firestore batched writes. AppController gains the four category/eventType methods on the user document (Q12).
9. **Production cutover + offline two-device smoke.** Mirrors Pass 4.2 #060. Net-new code already on main from issue #2 above (offline persistence); this issue is verification + smoke evidence on real devices. Likely device-blocked.
10. **Pass 4.5 closeout.** Revert the sign-out hotfix (the 5 hotfix tests at `test/state/app_state_test.dart:224-365` get rewritten to assert the new "Firestore is the source of truth" behavior). Update `progress.md`. File `AppUser` cleanup as a follow-up issue (Q13).

Issues #2-#6 can run in parallel after #1 (each store is independent). #7 depends on #2-#6. #8 depends on all three stores existing. #9 + #10 close out.

## Testing Decisions (tentative)

Same shape as Pass 4.2:

- Adapter contract tests against the InMemory adapter.
- Emulator round-trip tests against Firestore.
- Auth-aware provider tests against `MockFirebaseAuth`.
- Migration idempotency tests.
- Rules allow / deny cases in JS.
- Two-device smoke verification on real devices.
- AppController-level tests that assert write-then-state contracts and rollback on store failures.

Test count growth estimate: ~50-70 new tests across the three stores, the migration, the rules, and the AppController rewrite.

## Out of Scope

- Pass 4.3 (`LlmAiUpdate`).
- Pass 4.4 (Cloud Functions + FCM push).
- Multi-device conflict resolution beyond Firestore's last-write-wins for single documents (tracked under Pass 4.4).
- Bond score recomputation as a Cloud Function trigger (Pass 4.4).
- Web platform setup beyond the existing Pass 4.1 / 4.2 wiring.
- A custom offline sync engine, write-through cache, or two-store reconciliation layer (the Firestore SDK's local cache + pending writes is the offline story).
- A connection import flow (CSV, contacts API, etc.) — out of scope, possibly Pass 4.7.
- Connection sharing between users (out of scope, possibly Pass 5).
- The orphan memory `restore this contact?` prompt (Q9 option C, deferred to Pass 4.6).

## Further Notes

The biggest architectural fact about this pass is that Pass 4.2 already paid every infrastructural cost. The auth-aware provider pattern, the signed-out sentinel, the rules + emulator + JS rules + CI auto-deploy, the disk-to-Firestore migration, the `AiUpdate.commit` write-then-state contract — all in place. Pass 4.5 walks that same path for connections / interactions / events. The dominant work is the `AppController` rewrite, not new infrastructure.

The grilling questions are largely about UX and product semantics (Q5, Q9), not architecture (Q1-Q4, Q6-Q11). Architecture is a known pattern; the open questions are what the user sees and feels.

Pass 4.5 should ship before Pass 4.3 (`LlmAiUpdate`) and Pass 4.4 (Cloud Functions + FCM). Both of those build on durable user data; neither helps a user whose contacts vanish on sign-out. The hotfix that just shipped on `fix/signout-preserves-user-data` is the bridge until Pass 4.5 lands.

The hotfix carries two known caveats that Pass 4.5 must close:

1. Edited sample connections still get dropped on sign-out (`isSample` stays true after a user edit).
2. Account A → Account B on the same device leaves A's preserved connections visible to B until B's first state mutation.

Both go away when the durable record moves to Firestore.
