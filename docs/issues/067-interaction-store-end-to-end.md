# #067 InteractionStore + FirebaseInteractionStore + rules + tests

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-26-connection-persistence-pass-4-5-prd.md

## What to build

Same shape as #064 + #065 + #066, but for `CrmInteraction`. The pattern is established by the connection store work; this issue ships the full interaction stack end-to-end (interface, in-memory, provider, Firebase adapter, rules, tests) in one commit because the cost is repetition not invention.

`CrmInteraction` lives at `users/{uid}/interactions/{interactionId}` with these fields: id, contactId, type (enum), title, note, date, attachments (list, optional), source (enum, optional). PRD Q8 lists the enum string sets to validate.

## Acceptance criteria

- [ ] `InteractionStore` interface mirrors `ConnectionStore`'s shape: async load / save / delete / listAll, plus `snapshot()` and `snapshotSync()`.
- [ ] `InMemoryInteractionStore` implements every method, broadcasts on snapshot stream.
- [ ] `interactionStoreProvider` is auth-aware, returns a signed-out sentinel under signed-out auth, returns `FirebaseInteractionStore` under signed-in auth.
- [ ] `FirebaseInteractionStore` is UID-bound at construction, opens a snapshot listener at `users/{uid}/interactions`, mirrors into `Map<String, CrmInteraction>`.
- [ ] `firestore/firestore.rules` gains `match /users/{uid}/interactions/{interactionId}` with closed shape, enum validation for `type` (against actual `InteractionType` enum string values from `lib/src/models/social_models.dart`), enum validation for `source`, optional-field guards for `attachments`, `source`, `note`, `title`.
- [ ] `firestore/rules.test.js` adds at least 12 cases mirroring the connection rule tests.
- [ ] Headless tests in `test/state/connections/interaction_store_test.dart` and `test/state/connections/interaction_provider_test.dart`.
- [ ] Emulator tests in `integration_test/state/connections/firebase_interaction_store_test.dart` mirror the connection adapter's test surface.
- [ ] Production wiring NOT yet flipped — `AppController` still mutates in-memory `interactions` list. #070 cuts production over.
- [ ] `flutter analyze` clean. Default `flutter test` sweep stays at or above baseline.

## Blocked by

- #065 (the snapshot-listener pattern is established here)
- #066 (the rules pattern is established here)
