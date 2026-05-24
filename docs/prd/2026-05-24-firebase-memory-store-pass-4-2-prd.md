# Pass 4.2 — FirebaseMemoryStore Adapter (post-grilling)

Labels: prd, needs-triage

> Builds on: Pass 3 `MemoryStore` / `AiUpdate` seam and Pass 4.1 Firebase Auth (`#052`, commit `ac9e705`).
> Grilling outcomes: Q1–Q11 from the Pass 4.2 design conversation.
> Scope: Pass 4.2 only. Pass 4.3 (`LlmAiUpdate`) and Pass 4.4 (Cloud Functions + FCM) are deliberately out of scope.

## Problem Statement

ConnectMe now has real Firebase Auth, but the relationship memory that makes the app valuable is still stored on one device. Pass 3 introduced per-contact memory documents and the `MemoryStore` seam so the app could remember context about Sarah, Mike, or a family member across AI Update sessions. That memory is durable only on the local filesystem today. If a user signs in on a second device, their account exists, but their relationship memory does not follow them.

That breaks the product promise. ConnectMe is a memory aid for people whose working memory is already overloaded; the app cannot ask them to remember which phone has the latest context. If user A signs in on device 1 and device 2, both devices should read the same per-contact memory collection because both devices are authenticated as the same Firebase UID.

The current live Firebase project also still carries the Pass 4.1 Firestore test-mode posture. Before any real memory documents land in Firestore, the rules must move from permissive prototype rules to owner-scoped, shape-validating rules. The migration needs to preserve existing developer/demo data from the Pass 3 local markdown store without inventing a full offline-first sync system.

## Solution

Pass 4.2 adds `FirebaseMemoryStore`, the third implementation of the existing async `MemoryStore` interface. Production memory persistence moves from local markdown files to Firestore documents scoped by Firebase Auth UID:

`users/{uid}/memories/{contactId}`

Each contact memory is stored as one Firestore document with three fields: `markdown`, `updatedAt`, and `schemaVersion`. The markdown string remains the canonical artifact. Firestore is a persistence adapter, not a new memory schema.

The production provider becomes auth-aware: when a user is signed in, `memoryStoreProvider` returns a `FirebaseMemoryStore` bound to that user's UID; when signed out, memory access throws loudly. When the auth user changes, Riverpod rebuilds the store and invalidates downstream memory consumers.

Firestore offline persistence is explicitly enabled. `FirebaseMemoryStore.save()` returns when the SDK accepts the write into the local cache and queues it for replication. The Pass 3 `AiUpdate.commit` all-or-nothing contract remains unchanged: memory write, then app-state mutation, with the existing rollback path on failure.

Existing on-device files migrate once, after authenticated launch, only if the user's Firestore memory collection is empty. The migration copies local markdown documents into Firestore, sets `migratedFromDiskAt` on the user document, and leaves the local files in place as a backup.

Pass 4.2 also establishes the Firebase test and deploy discipline the project needs before a five-person team starts modifying rules: Firestore emulator-backed tests, JS rules tests with `@firebase/rules-unit-testing`, and GitHub Actions that run rules tests on PR and auto-deploy rules-only changes on merge to `main`.

## User Stories

1. As a ConnectMe user, I want my relationship memory to follow my login, so that signing in on a second device shows the same remembered context.
2. As a busy professional, I want updates I make on my phone to be available later on my laptop, so that I do not have to remember which device has the latest relationship state.
3. As a user with ADHD, I want the app's memory to be tied to my account instead of one install, so that reinstalling or switching devices does not feel like starting over.
4. As any user, I want Sarah's memory to stay associated with Sarah's stable contact id, so that display-name changes do not split or lose her history.
5. As any user, I want the app to keep working when my network is unreliable, so that I can still capture a relationship update on a bus or subway.
6. As any user, I want an update saved offline to sync later automatically, so that I do not need to manage a manual sync button.
7. As any user, I want the app to prevent other signed-in users from reading my memories, so that private relationship context stays private.
8. As any user, I want the app to reject malformed or oversized memory writes at the backend, so that bad clients cannot poison my account's memory collection.
9. As any user, I want old local memories to be carried into my account on first upgrade, so that demo data and existing relationship context are not silently abandoned.
10. As any user, I want migration to leave local files in place, so that there is a backup if the prototype migration ever needs inspection.
11. As any user, I want signing out and signing in as another person to swap memory stores completely, so that one person's memories cannot leak into another person's session.
12. As any user, I want an AI Update to keep the same confirmation and rollback behavior after the Firebase swap, so that the app remains predictable.
13. As any user, I want no new shamey or alarming copy during the migration, so that the backend change stays invisible and calm.
14. As a developer, I want Firestore to store the existing `MemoryDocument.render()` output, so that Pass 4.2 is one adapter swap rather than a second memory-model migration.
15. As a developer, I want a third `MemoryStore` adapter, so that the Pass 3 seam proves its value without reshaping UI consumers.
16. As a developer, I want `FirebaseMemoryStore` bound to a UID at construction time, so that auth changes cannot accidentally route reads to the wrong account.
17. As a developer, I want provider invalidation to follow auth changes, so that `memoryProvider`, `memoryTopicsProvider`, and `recommendationsProvider` naturally rebuild for the current user.
18. As a developer, I want server-side rules to enforce ownership and document shape, so that security is not only a client convention.
19. As a developer, I want Firestore rules tested in CI, so that a rules regression is caught before merge.
20. As a developer on a five-person team, I want rules to deploy automatically after merge, so that nobody has to remember a manual deploy step.
21. As a developer, I want the deploy workflow scoped to rules only, so that CI cannot accidentally deploy functions, indexes, or unrelated Firebase resources.
22. As a developer, I want adapter and migration tests to run against the Firestore emulator, so that the tests exercise the real Firestore SDK behavior rather than a Dart fake.
23. As a developer, I want existing widget tests to keep using `InMemoryMemoryStore` when Firestore behavior is irrelevant, so that the UI test suite stays focused and fast.
24. As a developer, I want a documented emulator test setup, so that every teammate can reproduce the same test environment locally.
25. As a developer, I want the Pass 4.1 real-device auth gate completed before Firestore work begins, so that Firestore bugs are not confused with Firebase config or bundle-id problems.
26. As a developer, I want the production cutover to include a real two-device smoke test, so that the PRD's cross-device claim is verified against the live project.
27. As a developer, I want `FileMemoryStore` to remain tested but leave the production path, so that local persistence stays available as a debug/reference adapter without creating a two-writer sync problem.
28. As a future Pass 4.3 implementer, I want the memory store swap completed independently of LLM work, so that the `LlmAiUpdate` adapter can focus on prompt, key, retry, timeout, and cancellation decisions.

## Implementation Decisions

### Q1 — Scope: Pass 4.2 only

This PRD covers only the Firebase-backed memory store. It does not design or implement the real LLM adapter, API key UX, Cloud Functions, FCM, or server-side notification triggers. Pass 4.2 is the persistence adapter swap that Pass 3 prepared for.

### Q2 — Pass 4.1 verification gate

The first Pass 4.2 issue is a no-code gate: verify the shipped Firebase Auth work against the live `connect-me-e20b1` project. The smoke test covers sign-up, sign-out, sign-in, and wrong-password inline error handling on at least one supported platform. Evidence is captured in the Firebase console and `progress.md` is updated before Firestore implementation begins.

### Q3 — Firestore data model

Each contact memory is one document at `users/{uid}/memories/{contactId}`. The document stores:

- `markdown` — the canonical rendered memory document string.
- `updatedAt` — Firestore timestamp for debugging, sorting, and future metadata.
- `schemaVersion` — integer, initially `1`.

The markdown document remains the source of truth. The adapter does not split summary, history, topics, preferences, and upcoming events into separate Firestore fields. If future passes need queryable metadata, they can add narrow top-level fields without replacing the markdown artifact.

### Q4 — Offline behavior and `FileMemoryStore`

Firestore offline persistence is explicitly enabled. Production reads and writes go through `FirebaseMemoryStore`; `FileMemoryStore` remains in the codebase as a tested adapter, debug/reference implementation, and migration source, but it is no longer the production binding.

The project intentionally avoids a write-through cache or manual sync layer. Firestore's local cache and queued writes are the offline story for Pass 4.2. This avoids a two-writer coherence problem that would overlap with Pass 4.4's future conflict-resolution work.

### Q5 — Security rules

Rules enforce both ownership and shape. Users can read/list/write only under their own UID. Writes must contain only `markdown`, `updatedAt`, and `schemaVersion`; `markdown` must be a string at or under 64KB; `updatedAt` must be a timestamp; `schemaVersion` must be an integer.

The 64KB per-contact cap from Pass 3 is now server-enforced. The previous 16MB global soft cap is not carried into Firestore rules because per-user aggregate storage is awkward to enforce safely in rules and unnecessary for the prototype. Firestore's per-document and project-level limits become the practical ceiling.

### Q6 — One-shot disk-to-Firestore migration

On first authenticated launch under Pass 4.2, migration checks whether the user's Firestore memory collection is empty. If it is empty and local markdown memory files exist, the migration copies each local file through `FirebaseMemoryStore.save()` and writes `migratedFromDiskAt` on the user document. Source files remain untouched.

The empty-collection check is the real guard. The sentinel avoids repeated scans on later launches. Migration is account-scoped, not device-scoped, and only runs while signed in. Different Firebase accounts receive different memory collections.

### Q7 — Auth-aware provider construction

`memoryStoreProvider` watches auth state. Signed-in users get a `FirebaseMemoryStore` constructed with the Firestore instance and the current UID. Signed-out reads throw because memory consumers should not be active outside the authenticated app shell.

When the user signs out or signs in as a different account, the provider rebuilds and downstream providers invalidate. `FirebaseMemoryStore` never reads global auth state per operation; it is bound to exactly one UID.

### Q8 — Atomic writes and `AiUpdate.commit`

A single Firestore `set()` is atomic for one memory document. `FirebaseMemoryStore.save()` completes when the SDK accepts the write locally and queues it for sync. Waiting for server acknowledgement would break the desired offline behavior, so Pass 4.2 treats SDK acceptance as success.

`AiUpdate.commit` keeps its Pass 3 contract. If a store write throws, the existing retryable error path runs. If the app is uninstalled before an offline queued write reaches the server, that last write can be lost; this is an accepted prototype failure mode and should be documented in the adapter.

### Q9 — Test substrate: Firestore emulator

Adapter, migration, and rules tests use the Firebase emulator. The project does not adopt `fake_cloud_firestore`. Dart tests that need Firestore point the SDK at `localhost:8080` and Auth at `localhost:9099`. Rules tests use Firebase's JS rules testing library.

Existing widget tests remain free to override `memoryStoreProvider` with `InMemoryMemoryStore` unless they are specifically verifying Firebase behavior.

### Q10 — Repository layout

Firebase artifacts live in a top-level `firestore/` directory containing rules, indexes, JS test package files, rules tests, and a README. Root `firebase.json` points to the rules file and configures emulators. Dart test helper code lives under the normal Flutter `test/` tree.

### Q11 — Rules deploy workflow

A five-person team makes manual rules deployment too easy to forget. Pass 4.2 adds GitHub Actions for rules discipline:

- PRs touching `firestore/` run the JS rules-test suite against the emulator.
- Pushes to `main` with rules changes deploy only Firestore rules to `connect-me-e20b1`.
- The deploy job depends on passing tests.
- The service account has the Firebase Rules Admin role and is stored as `FIREBASE_SERVICE_ACCOUNT`.
- The workflow is rules-only; indexes, functions, and other Firebase resources are not deployed by this job.

### Module sketch

- **`FirebaseMemoryStore`** — third adapter for the existing `MemoryStore` interface. Owns Firestore paths, schemaVersion `1`, markdown serialization boundary, and CRUD/list operations.
- **`DiskToFirestoreMigration`** — idempotent migration collaborator that copies from local file store to Firebase store after authenticated launch when the remote collection is empty.
- **Auth-aware provider binding** — Riverpod construction logic that ties `MemoryStore` identity to Firebase UID and invalidates memory consumers on auth changes.
- **Firestore rules module** — owner-scoped, shape-validating rules and the JS allow/deny test suite.
- **Emulator test setup** — shared Dart test helper for Firebase initialization and emulator routing.
- **Rules CI workflows** — PR test and main-branch deploy pipelines scoped to Firestore rules.

### Proposed issue sequence

1. `#053` — Pass 4.1 real-device verification gate.
2. `#054` — Firestore rules, emulator config, and JS rules-test scaffolding.
3. `#055` — GitHub Actions rules tests on PR and rules auto-deploy on `main`.
4. `#056` — Dart-side Firestore emulator test scaffolding.
5. `#057` — `FirebaseMemoryStore` adapter, emulator-tested, not wired into production.
6. `#058` — Auth-aware `memoryStoreProvider` rebuild and signed-out access behavior.
7. `#059` — One-shot disk-to-Firestore migration.
8. `#060` — Production cutover to `FirebaseMemoryStore` and offline persistence.
9. `#061` — Pass 4.2 closeout and `progress.md` update.

`#053` blocks all work. After that, rules scaffolding and Dart emulator setup can proceed in parallel once the shared Firebase emulator config exists. The production cutover waits until rules, adapter, provider, and migration all land.

## Testing Decisions

Good tests in this pass verify externally visible contracts: a saved document can be loaded; a user can only access their own memory path; migration is idempotent; auth changes rebuild the store; and production cutover preserves the existing AI Update behavior. Tests should not assert private helper structure or Firestore SDK internals.

**FirebaseMemoryStore adapter tests.** Run against the Firestore emulator. Cover save/load round-trip, delete, load-missing returns null, listAll returns all saved documents keyed by contact id, schemaVersion is written, malformed documents surface as parse errors rather than crashing UI consumers where the existing `MemoryDocument` contract allows that behavior, and oversized writes are rejected through rules.

**Migration tests.** Seed local file memory, run the migration, assert Firestore documents exist with the expected markdown and schema fields, assert `migratedFromDiskAt` is written, run migration again and assert it is a no-op, assert non-empty Firestore collection skips migration even if local files exist, and assert source files remain on disk.

**Provider tests.** Flip auth state and assert `memoryStoreProvider` rebuilds for the new UID. Assert signed-out access throws. Assert downstream memory providers invalidate when the store identity changes. Follow the `ProviderContainer` style used by existing state/provider tests.

**Rules tests.** JS/Jest tests using `@firebase/rules-unit-testing` cover authenticated owner reads, lists, creates, updates, and deletes; other-user denial; anonymous denial; missing keys; extra keys; wrong types; oversized markdown; and valid payload acceptance.

**Widget tests.** Existing UI tests keep using `InMemoryMemoryStore` unless they specifically exercise Firebase behavior. Pass 4.2 should not make every widget test require an emulator just because production storage changed.

**CI tests.** The canonical command becomes emulator-backed for Firebase tests: `firebase emulators:exec --only firestore,auth "flutter test"`. The JS rules suite runs in its own workflow and gates rules deployment.

**Real-device smoke tests.** `#053` verifies Pass 4.1 Auth before Firestore work. `#060` verifies the actual Pass 4.2 claim: sign in as the same account on two devices or simulators, create/update memory on one, and observe the memory on the other.

**Prior art.** Pass 3's `MemoryStore` and `AiUpdate` tests establish the adapter-contract style. Existing provider tests establish Riverpod container patterns. Pass 4.1's Firebase Auth test overrides establish the Firebase-authenticated testing idiom.

## Out of Scope

- `LlmAiUpdate`, real LLM calls, prompt design, API key UX, secure key storage, retry, timeout, and cancellation. These are Pass 4.3.
- Cloud Functions, FCM, push notifications, server-side recommendation scheduling, and background notification triggers. These are Pass 4.4.
- Multi-device conflict resolution beyond Firestore's last-write-wins behavior for single documents.
- `#051` recommendation-provider `listAll()` wiring. It remains independent and most naturally lights up alongside Pass 4.3 when `Upcoming` is populated by a real LLM.
- Web platform setup. Pass 4.2 targets the already-configured Firebase platforms from Pass 4.1.
- A custom offline sync engine, manual sync button, write-through disk cache, or two-store reconciliation layer.
- Server-side per-user aggregate storage caps.
- Memory editor UI, export/import UI, structured topic taxonomy, or per-revision memory history.
- `fake_cloud_firestore`.

## Further Notes

The most important architectural fact is that Pass 3 already paid the seam cost. The UI, recommendation engine, conversation topics, and AI Update flow all depend on `MemoryStore`, not on local files. Pass 4.2 proves that seam by adding a third adapter and swapping production to it.

Cross-device sync is automatic once memory lives under `users/{uid}/memories/...`: device 1 and device 2 sign in as the same user, read the same collection, and let the Firestore SDK handle cache and replication. Pass 4.2 does not need a separate "sync service" to deliver that core behavior.

The one-shot migration is intentionally conservative. It claims local prototype data for the first authenticated account only when the remote collection is empty, and it never deletes source files. This is enough for the developer/demo install base without creating a permanent custom sync system.

The Firestore rules workflow is shaped for the team's next phase. A solo developer can remember a deploy command; five developers need automation. Auto-deploying rules after tests pass makes the repo the source of truth and avoids stale test-mode rules lingering in the live project.

### Pass 4.3 / 4.4 readiness considerations

Pass 4.2 should make later work easier without absorbing it. `LlmAiUpdate` can assume the memory store is already remote and UID-scoped. Cloud Functions and FCM can assume memory documents have a stable path and a simple top-level metadata envelope. If future passes need queryable fields, they should add narrow metadata beside `markdown`, not replace the markdown artifact.

The remaining big Firebase questions — notification cadence, server-triggered recommendation logic, real conflict resolution, and LLM-generated upcoming events — belong to their own grilling sessions. Pass 4.2's job is to make relationship memory account-scoped, secure, tested, migrated, and production-bound.
