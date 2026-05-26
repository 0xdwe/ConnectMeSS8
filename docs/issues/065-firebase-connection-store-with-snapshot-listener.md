# #065 FirebaseConnectionStore adapter with snapshot listener

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-26-connection-persistence-pass-4-5-prd.md

## What to build

Implement `FirebaseConnectionStore` as the production adapter for `ConnectionStore`. Bound to one UID at construction. Stores Connection documents at `users/{uid}/connections/{contactId}`. Maintains a snapshot listener subscription opened at construction, mirroring incoming events into a local `Map<String, Connection>` that `snapshotSync()` returns.

This is where Pass 4.5 introduces the new pattern Pass 4.2 did not pay for. Subscription lifetime, listener-error handling, and teardown on auth swap all live here. Production wiring is NOT flipped in this issue — `AppController` still consumes `InMemoryConnectionStore` overrides; #069 cuts production over.

## Acceptance criteria

- [ ] `FirebaseConnectionStore` in `lib/src/state/connections/firebase_connection_store.dart` implements `ConnectionStore`.
- [ ] UID bound at construction; never reads global auth state per operation.
- [ ] Save writes a Connection document with all 12 fields (id, name, email, category, avatar, bondScore, nextStep, lastContact, notes, knownSince, preferredChannels, isSample) plus `schemaVersion: 1` and `updatedAt: serverTimestamp`.
- [ ] Delete removes the document.
- [ ] Load reads a single document by contactId.
- [ ] `listAll` reads the collection once and returns a `Map<String, Connection>`.
- [ ] `snapshot()` returns the broadcast stream backed by the Firestore `snapshots()` subscription.
- [ ] `snapshotSync()` returns the current mirror map (null until first snapshot resolves).
- [ ] Subscription opens at construction, tears down via `dispose()` (called by the auth-aware provider's `onDispose`).
- [ ] Listener errors (network, permission-during-signout) are caught and surfaced via the stream's error channel; the mirror is not corrupted.
- [ ] Adapter doc comment names: the offline acceptance contract (writes accepted into local cache and queued for replication), the listener teardown contract, and the load-before-mirror-populated null guarantee on `snapshotSync()`.
- [ ] Emulator tests in `integration_test/state/connections/firebase_connection_store_test.dart` cover: round-trip, missing, delete, listAll, snapshot emits on cross-instance writes (two stores against same UID), listener teardown on dispose, listener-error handling, auth-swap restart (new UID gets a new store with its own subscription), oversized rejection (via rules — see #066).
- [ ] Headless tests for `connectionStoreProvider` extend to verify: signed-in path returns `FirebaseConnectionStore` (verified via type guard, not by constructing one without Firebase init).
- [ ] `flutter analyze` clean. `flutter test test/state/` stays above the current baseline; integration tests run separately via the Pass 4.2 emulator command.

## Blocked by

- #064
