# #069 ConnectionSeeder + onboarding "Start with samples / Start fresh" + empty-state UX

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-26-connection-persistence-pass-4-5-prd.md

## What to build

One-shot seeder that initializes the user's `connections`, `interactions`, `events`, `categories`, and `eventTypes` collections / fields on first authenticated launch. The word "seeder" is intentional — Pass 4.2's migration was a real disk → cloud copy, while Pass 4.5's data was never on disk (PRD Q7).

Onboarding asks the user once at sign-up: "Start with sample contacts" (Mike, Sarah, Emily, David + their interactions and events) or "Start fresh" (empty connection/interaction/event collections, but the seeded `categories` and `eventTypes` are still written because they're useful even for fresh-start users — PRD Q12).

Empty-state UX on the People tab and Home recommendations list lands here so a "Start fresh" user doesn't see a confusing blank screen.

A one-time "data persistence has been upgraded" notice fires on the first Pass 4.5 launch for accounts that pre-existed the Pass 4.5 build, hinting that any hotfix-era user-added contacts are not in the cloud (PRD Q7's accepted data-loss decision).

## Acceptance criteria

- [ ] `ConnectionSeeder` in `lib/src/state/connections/connection_seeder.dart` runs only when signed in AND the user's `users/{uid}/connections` collection is empty AND `connectionsSeededAt` is unset.
- [ ] Seeder writes the seeded sample list (Mike / Sarah / Emily / David from `AppState.seeded()`) when the user picked "Start with samples"; sentinel-only no-op when picked "Start fresh".
- [ ] Same shape for `interactions` (sample-only) and `events` (sample-only).
- [ ] `categories` and `eventTypes` lists on `users/{uid}` get the seeded defaults regardless of sample-vs-fresh choice.
- [ ] Sentinels written on `users/{uid}`: `connectionsSeededAt`, `interactionsSeededAt`, `eventsSeededAt`, `categoriesSeededAt`, `eventTypesSeededAt` (all timestamps).
- [ ] `firestore/firestore.rules` `match /users/{uid}` block gains the five new optional timestamp fields (alongside the existing `migratedFromDiskAt`). `firestore/rules.test.js` covers them.
- [ ] Onboarding prompt: a modal or full-screen step on the auth screen's `_AuthMode.signup` flow, AFTER `signUp()` succeeds and BEFORE the first navigation to the shell. Two-button choice; user's choice persisted to a Riverpod state and consumed by the seeder.
- [ ] Onboarding prompt does NOT fire on `_AuthMode.login`.
- [ ] Empty-state UI on the People tab when `connections` is empty AND seeder has completed: short copy + "Add your first contact" CTA.
- [ ] Empty-state UI on Home recommendations when no recommendations: calmer placeholder copy.
- [ ] One-time "persistence upgraded" notice fires when both: (a) `connectionsSeededAt` was just written this session, AND (b) the auth account already existed before this build (heuristic: Firebase Auth `creationTime` is older than this build's release date, OR a fallback flag like `data/persistence_v45_seen` to ensure the notice fires at most once per device per account).
- [ ] Headless tests cover seeder branching (samples vs fresh), idempotency (re-running is a no-op), sentinel-only behavior on fresh, and ordering (seeder runs before any AppController-driven mutation that would race it).
- [ ] Emulator-backed tests verify the actual Firestore writes for both samples and fresh paths.
- [ ] Onboarding prompt and empty-state widgets have widget tests.
- [ ] `flutter analyze` clean. `flutter test test/state/` stays above baseline.

## Blocked by

- #064
- #065
- #066
- #067
- #068
