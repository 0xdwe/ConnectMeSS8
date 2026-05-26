# #069 ConnectionSeeder service + sentinel rules + headless tests

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-26-connection-persistence-pass-4-5-prd.md

## What to build

One-shot seeder service that initializes the user's `connections`, `interactions`, `events` collections and `categories` / `eventTypes` fields on first authenticated launch. The word "seeder" is intentional — Pass 4.2's migration was a real disk → cloud copy, while Pass 4.5's data was never on disk (PRD Q7).

**Scope: infrastructure only.** This issue ships the seeder as a parameterized API (`ConnectionSeeder.run(choice: SeederChoice.samples | .fresh)`), the five sentinel-field additions to Firestore rules, the JS rules tests, and the headless tests. The UI that drives the seeder choice (onboarding modal, empty-state UX, persistence-upgraded notice) is filed separately as #074 — those decisions involve product copy and UX placement that benefit from explicit review.

## Acceptance criteria

- [ ] `SeederChoice` enum in `lib/src/state/connections/connection_seeder.dart` with values `samples` and `fresh`.
- [ ] `ConnectionSeeder` class with `Future<SeederResult> run({required SeederChoice choice})`. Result carries `didSeed` (true if any documents were written), `didNoOp` (true if all sentinels already set), and the per-collection counts.
- [ ] Seeder runs only when signed in AND the user's `users/{uid}/connections` collection is empty AND `connectionsSeededAt` is unset.
- [ ] When `choice == SeederChoice.samples`: writes the seeded sample list (David / Emily / Jessica / Mike / Sarah from `AppState.seeded()`) to `users/{uid}/connections`, the seeded interactions to `users/{uid}/interactions`, and the seeded events to `users/{uid}/events`.
- [ ] When `choice == SeederChoice.fresh`: connections / interactions / events collections stay empty (sentinel-only).
- [ ] `categories` and `eventTypes` lists on `users/{uid}` get the seeded defaults regardless of `choice` (PRD Q12 — useful for fresh-start users too).
- [ ] Sentinels written on `users/{uid}` (timestamps): `connectionsSeededAt`, `interactionsSeededAt`, `eventsSeededAt`, `categoriesSeededAt`, `eventTypesSeededAt`.
- [ ] Seeder is idempotent: re-running with the same UID is a no-op (`didNoOp == true`).
- [ ] Seeder uses Firestore `WriteBatch` for atomic writes within each collection so a partial network failure cannot leave a half-seeded state with the sentinel set.
- [ ] `firestore/firestore.rules` `match /users/{uid}` block extends `isWellFormedUserDoc(data)` to allow the five new optional timestamp fields alongside the existing `migratedFromDiskAt`.
- [ ] `firestore/rules.test.js` adds at least 8 cases for the new sentinel fields (positive write of each + cross-user denial of each + wrong-type rejection).
- [ ] Headless tests in `test/state/connections/connection_seeder_test.dart` cover: samples branch writes the expected counts, fresh branch is sentinel-only, idempotent re-run is a no-op, partial-state recovery (one sentinel set, others not) does not double-seed.
- [ ] Emulator-backed test in `integration_test/state/connections/connection_seeder_test.dart` writes both branches against the real Firestore emulator and verifies the documents land at the expected paths. (Run deferred to #073.)
- [ ] Production wiring (auto-trigger off auth + choice) does NOT land here. AppController and the auth screen are unchanged. The seeder is callable but no production path calls it yet — #074 wires the trigger.
- [ ] `flutter analyze` clean. `flutter test test/state/` stays at or above baseline.

## Why narrowed from the original scope

The original #069 bundled three concerns: backend seeder, signup-time onboarding modal, empty-state UI + persistence-upgraded notice. Three different review surfaces (data, UX, copy) made one merge too thick. Splitting keeps each issue focused and reviewable. The UI half is filed as #074.

## Blocked by

- #064
- #065
- #066
- #067
- #068
