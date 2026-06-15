# #121 — Delete Activity Log Entry + Rebuild Memory

**Parent PRD:** N/A (standalone feature)  
**Branch:** `feat/121-delete-activity-log-and-rebuild-memory`  
**Triage:** `ready-for-agent`

---

## Problem Statement

Users currently see every `CrmInteraction` in a Connection's Activity Log on the contact profile, but they cannot remove an entry. When an interaction is logged by mistake, duplicated, or simply becomes irrelevant, it continues to influence the contact's `MemoryDocument`, `Bond Score`, `lastContact`, and AI-driven recommendations. There is no way to correct the relationship graph after the fact.

## Solution

Add a delete action to each Activity Log row. Tapping it shows a confirmation explaining that AI Insights, connection score, and last contact will be reprocessed. On confirm, the app deletes the `CrmInteraction`, recalculates the dependent Connection fields, runs a full memory rebuild from the remaining interactions, and refreshes the AI Insights card with the same spinner used for manual refresh.

## User Stories

1. As a user, I want to delete an activity log entry, so that I can correct mistakes in a contact's history.
2. As a user, I want a confirmation before deleting, so that I don't accidentally lose history that affects AI Insights.
3. As a user, I want the confirmation to explain that AI Insights will be reprocessed, so that I understand why the action matters.
4. As a user, I want a brief undo window after deleting, so that I can recover the entry if I changed my mind.
5. As a user, I want the AI Insights card to show a refresh spinner while the memory rebuild happens, so that I know the system is working.
6. As a user, I want the connection score to drop if I delete an interaction that previously increased it, so that the score stays factually correct.
7. As a user, I want `lastContact` to update to the next most recent interaction after deletion, so that maintenance urgency is accurate.
8. As a user, I want topic suggestions that came only from a deleted interaction to disappear, so that AI Insights don't reference stale context.
9. As a user, I want the Person Summary to be rewritten without the deleted interaction, so that the memory narrative stays consistent.
10. As a user, I want the next step suggestion to update after deletion, so that it doesn't reference an activity that no longer exists.
11. As a user, I want manual "Refresh AI Insights" to remain fast, so that routine refreshes don't always trigger an expensive full rebuild.
12. As a user, I want deletion to work even when offline, so that I'm not blocked by connectivity; the rebuild can retry or warn when back online.
13. As a user, I want to see a clear error if the memory rebuild fails after deletion, so that I know the memory may be stale and can refresh manually later.
14. As a user, I want both manually logged and AI-suggested activity rows to be deletable, so that I have full control over the history.
15. As a user, I want the delete action to be clearly visible on each row, so that I don't have to discover hidden gestures.
16. As a user, I want deleted interactions to be removed from the Activity Log immediately after the undo window expires, so that the UI reflects the action I took.
17. As a user, I want the Activity Log row to be disabled while deletion and rebuild are in progress, so that I can't trigger a second delete accidentally.

## Implementation Decisions

- **New `AppController.deleteInteraction(String interactionId)` orchestration method.** It mirrors the shape of `deleteConnection` and `deleteEvent`: read from in-memory state, call the store, then coordinate downstream side effects.
- **Use the existing `InteractionStore` seam for the delete.** The operation is a single-store delete; no Firestore batch is needed because the memory rebuild is asynchronous and cannot participate in a transaction.
- **Recalculate `Connection.lastContact` from the remaining `CrmInteraction`s for the same contact.** Fall back to the connection's original seeded `lastContact` if no interactions remain.
- **Subtract `bondScoreDelta` from `Connection.bondScore` when the deleted interaction carries a delta.** Deltas are clamped to `[0, 100]`. Existing interactions that lack the new field keep `bondScore` unchanged on delete.
- **Add `bondScoreDelta` field to `CrmInteraction`.** Default is `0`. AI Update commits populate it with the computed delta. `logInteraction` sets it to `0`. Store encoders/decoders must round-trip it.
- **Update `Connection.nextStep` from the memory rebuild result.** The rebuild has full context and can produce a corrected one-line next step. If the result omits a next step, clear it to empty.
- **Introduce a new `MemoryRebuilder` seam.** It is separate from `AiUpdate` (which is user-input/preview driven) and from `MemoryTopicEnricher` (which only enriches topics/suggestions). Shape:
  ```dart
  abstract interface class MemoryRebuilder {
    Future<MemoryRebuildResult> rebuild({
      required Connection contact,
      required MemoryDocument currentMemory,
      required List<CrmInteraction> remainingInteractions,
      required CrmInteraction deletedInteraction,
    });
  }

  class MemoryRebuildResult {
    final MemoryDocument memoryDocument;
    final String nextStep;
  }
  ```
- **Implement `LlmMemoryRebuilder` with a dedicated prompt.** The prompt instructs the model to remove references to the deleted interaction and regenerate `Summary`, `History`, `Preferences`, `Topics`, `Upcoming`, and topic-scoped suggestions from the remaining interactions and current memory context.
- **Save the rebuilt `MemoryDocument` through `MemoryStore`.** After a successful save, bump `memoryEpochProvider`, clear `recommendationsCacheProvider`, and set `lastAiUpdatedContactId` so the recommendation banner refreshes with the completion signal.
- **Introduce `pendingMemoryRebuildProvider` (String? contactId).** `AiInsightsCard` watches this provider. When it matches the card's contact, it shows the header refresh spinner and runs the full rebuild flow. This is separate from `pendingAiInsightsRefreshProvider`, which continues to trigger the lighter topic-enrichment refresh.
- **Undo is UI-owned.** `ContactProfileScreen` shows a 4-second SnackBar. If the user taps Undo, the interaction is restored via `InteractionStore.save` and no rebuild is triggered. If not undone, the UI calls `AppController.deleteInteraction`.
- **Confirmation dialog copy:** "Delete this activity? This activity is part of {name}'s history. Deleting it will reprocess AI Insights, connection score, and last contact from the remaining activity log."
- **Offline behavior:** Allow the store delete to proceed. If the LLM rebuild fails (network unreachable), show an error SnackBar and leave memory stale; the user can manually refresh AI Insights later.
- **Attachments are left as storage orphans.** Interaction deletion does not cascade to Firebase Storage objects.

## Acceptance Criteria

- [ ] Each Activity Log row shows a delete action.
- [ ] Tapping delete shows the confirmation dialog with the agreed copy.
- [ ] Confirming delete shows a 4-second undo SnackBar.
- [ ] Undo restores the interaction and cancels rebuild.
- [ ] After the undo window expires, the interaction is removed from the Activity Log.
- [ ] `Connection.lastContact` is recalculated from remaining interactions.
- [ ] `Connection.bondScore` is reduced by the deleted interaction's `bondScoreDelta` when the field is present.
- [ ] `Connection.nextStep` is updated from the memory rebuild result.
- [ ] `MemoryDocument` is rebuilt via `MemoryRebuilder` and saved.
- [ ] AI Insights card shows the refresh spinner during rebuild.
- [ ] After rebuild, stale topics/summary from the deleted interaction no longer appear.
- [ ] Manual "Refresh AI Insights" still performs topic-only enrichment.
- [ ] Deleting an interaction while offline succeeds; rebuild failure surfaces a SnackBar error.
- [ ] Unit tests cover `AppController.deleteInteraction` orchestration.
- [ ] Widget tests cover confirmation, undo, spinner, and row removal.

## Testing Decisions

- **Test external behavior, not implementation details.** Assert on provider state, widget finders, and store contents; avoid asserting on private helper internals.
- **`AppController.deleteInteraction` unit tests** using `InMemoryInteractionStore`, `InMemoryConnectionStore`, `InMemoryMemoryStore`, and a `FakeMemoryRebuilder`. Prior art: `test/state/app_state_test.dart` patterns for `deleteConnection` and `applyAiUpdateResult`.
- **Fake `MemoryRebuilder` adapter** that returns deterministic topics/summary/next-step so tests can assert memory changes without network.
- **Widget tests in `test/widgets/contact_profile_test.dart` or similar** that pump `ContactProfileScreen` with scoped overrides, tap delete, assert confirmation dialog, assert undo behavior, and assert AI Insights spinner via the existing refresh button key.
- **Schema round-trip tests** for `FirebaseInteractionStore.encode/decode` and `InMemoryInteractionStore` to ensure `bondScoreDelta` survives persistence.
- **No integration tests against the real Firebase emulator** for this feature per ADR-0003; headless tests use InMemory adapters.

## Out of Scope

- Bulk delete of multiple activity log entries.
- Deleting attachment files from Firebase Storage.
- Backfilling `bondScoreDelta` for existing interactions; only new interactions carry the field.
- Reverting `bondScore` for deleted interactions that lack `bondScoreDelta`.
- Cross-device evidence chain for the delete operation (ADR-0003 deferred).
- Editing an existing activity log entry.

## Further Notes

- This feature reinforces the source-of-truth contract: `InteractionStore` owns interactions, `ConnectionStore` owns connection metadata, `MemoryStore` owns memory, and `AppController` coordinates the cross-store side effects.
- The new `MemoryRebuilder` seam may be reused later for "rebuild memory from scratch" or "merge duplicate contacts" flows.
- The anti-shame guardrail applies to confirmation and error copy: no numeric day counts or guilt phrasing.
- Label: `ready-for-agent`
