# #068 EventStore + FirebaseEventStore + rules + tests

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-26-connection-persistence-pass-4-5-prd.md

## What to build

Same shape as #067, but for `PlannerEvent`. Lives at `users/{uid}/events/{eventId}`. The model has more optional fields than `CrmInteraction` (`contactId`, `startTimeMinutes`, `endTimeMinutes`, `recurrencePattern` are all nullable), so the rule guards are slightly more involved. PRD Q8 explicitly chose NOT to validate `eventType` server-side because the eventTypes list is per-user data; bad client data is recoverable client-side.

## Acceptance criteria

- [ ] `EventStore` interface mirrors `ConnectionStore` and `InteractionStore`.
- [ ] `InMemoryEventStore` implements every method.
- [ ] `eventStoreProvider` is auth-aware with signed-out sentinel.
- [ ] `FirebaseEventStore` is UID-bound, opens snapshot listener, mirrors into `Map<String, PlannerEvent>`.
- [ ] `firestore/firestore.rules` gains `match /users/{uid}/events/{eventId}` with closed shape: required `id`, `title`, `category`, `date is timestamp`, `note`, `eventType`, `isAllDay is bool`, `isRecurring is bool`, `schemaVersion is int`, `updatedAt is timestamp`.
- [ ] Optional-field guards for `contactId is string || !('contactId' in data.keys())`, same for `startTimeMinutes`, `endTimeMinutes`, `recurrencePattern`.
- [ ] `eventType` is NOT validated server-side per PRD Q8.
- [ ] `firestore/rules.test.js` adds at least 12 cases mirroring the connection / interaction rule tests, plus specific cases for the optional-field permutations (event with no contactId, all-day event with no time minutes, recurring event with no pattern, etc.).
- [ ] Headless tests in `test/state/connections/event_store_test.dart` and `test/state/connections/event_provider_test.dart`.
- [ ] Emulator tests in `integration_test/state/connections/firebase_event_store_test.dart`.
- [ ] Production wiring NOT yet flipped.
- [ ] `flutter analyze` clean. Default `flutter test` sweep stays at or above baseline.

## Blocked by

- #065
- #066
