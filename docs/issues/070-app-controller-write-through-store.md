# #070 AppController rewrite: write-through-store with multi-store atomic batches

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-26-connection-persistence-pass-4-5-prd.md

## What to build

Rewrite the 13 mutating methods on `AppController` to write through the new stores instead of mutating in-memory `state.copyWith` directly. The two costly methods (`deleteConnection`, `applyAiUpdateResult`) use Firestore batched writes for multi-store atomicity, extending the Pass 3 / Pass 4.2 `AiUpdate.commit` write-then-state contract.

This is the largest single piece of work in Pass 4.5. It cuts production over to the new stores. After this issue, `AppController.state.connections / interactions / events` is a thin denormalization of the stores' mirror maps, kept in sync via the snapshot listeners.

## Acceptance criteria

- [ ] All 13 mutating methods become async and write through the appropriate store(s) before mutating `AppController.state`:
  1. `addConnection` → `connectionStore.save`
  2. `updateConnection` → `connectionStore.save`
  3. `deleteConnection` → batched: `connectionStore.delete` + filtered `interactionStore.delete` for each related interaction + filtered `eventStore.delete` for each related event + `memoryStore.delete`
  4. `removeSampleConnections` → batched: same shape as `deleteConnection` but iterating sample IDs
  5. `logInteraction` → `interactionStore.save`
  6. `addEvent` → delegates to `saveEvent`
  7. `saveEvent` → `eventStore.save`
  8. `deleteEvent` → `eventStore.delete`
  9. `restoreEvent` → `eventStore.save`
  10. `applyAiUpdateResult` → batched: `interactionStore.save(newInteraction)` + `connectionStore.save(connection.copyWith(bondScore: ..., lastContact: ...))`
  11. `renameEventType` → `userDocStore.update({ eventTypes: [...] })` + filtered `eventStore.save` for each affected event
  12. `deleteEventType` → `userDocStore.update({ eventTypes: [...] })` + filtered `eventStore.save` for each affected event
  13. `signOut` → trivial: rely on auth-aware provider rebuild + listener teardown to clear in-memory state. The hotfix's `isSample`-cascade preservation logic is removed.
- [ ] `addCategory`, `addEventType`, `renameEventType`, `deleteEventType` write to a `users/{uid}` user document (PRD Q12). Rules already validate the new fields per #069.
- [ ] Multi-store atomic batches use `WriteBatch` (Firestore atomic across documents in same project). On batch failure, the existing `AiUpdate.commit` retryable error path runs; in-memory state is not advanced.
- [ ] `AppController.state.connections / interactions / events` reads through `store.snapshotSync()` mirror maps. The mirror maps are populated by the snapshot listeners; first load may show empty until snapshot fires (existing Pass 4.5 splash from `_MemorySeedingSplash` extends to wait on the first snapshot).
- [ ] Existing widget tests that override `memoryStoreProvider` keep passing — the new pattern adds `connectionStoreProvider`, `interactionStoreProvider`, `eventStoreProvider` overrides for tests that exercise mutations.
- [ ] AppController contract tests cover: write-then-state ordering, multi-store batch atomicity, rollback on partial failure, snapshot-listener-driven state updates after a remote write from another instance.
- [ ] The 5 sign-out hotfix tests at `test/state/app_state_test.dart:224-365` get rewritten to assert the new "Firestore is source of truth" behavior: signOut tears down listeners and clears in-memory state; subsequent signIn rebuilds from Firestore.
- [ ] `flutter analyze` clean. `flutter test test/state/` stays above baseline (count grows substantially).

## Blocked by

- #064 through #069 (every store must exist before the controller can write through them)
