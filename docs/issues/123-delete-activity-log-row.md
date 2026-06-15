# #123 — Delete Activity Log Row with Confirmation, Undo, and Connection Recalculation

**Parent:** #121  
**Branch:** `feat/123-delete-activity-log-row`  
**Triage:** `ready-for-agent`

---

## Parent

#121 — Delete Activity Log Entry + Rebuild Memory

## What to build

Add the delete action to each Activity Log row on the contact profile. After a short undo window, delete the interaction and immediately recalculate the dependent connection fields.

End-to-end behavior:
- Each `CrmInteraction` row shows a delete action.
- Tapping it opens a confirmation dialog explaining that AI Insights, connection score, and last contact will be reprocessed.
- On confirm, a 4-second SnackBar offers Undo.
- If not undone, the UI calls `AppController.deleteInteraction`.
- The method deletes the interaction through `InteractionStore`, then recalculates `Connection.lastContact` from the remaining interactions and subtracts the deleted interaction's `bondScoreDelta` from `Connection.bondScore` (clamped to `[0, 100]`).
- The Activity Log row is disabled while deletion is in progress.

## Acceptance criteria

- [ ] Each Activity Log row shows a delete action.
- [ ] Tapping delete shows the confirmation dialog with agreed copy.
- [ ] Confirming delete shows a 4-second undo SnackBar.
- [ ] Undo restores the interaction and cancels any downstream rebuild.
- [ ] After the undo window expires, the interaction is removed from the Activity Log.
- [ ] `Connection.lastContact` is recalculated from remaining interactions.
- [ ] `Connection.bondScore` is reduced by the deleted interaction's `bondScoreDelta` when present.
- [ ] The deleted row is disabled during processing.
- [ ] Widget tests cover confirmation, undo, and row removal.
- [ ] Unit tests cover `AppController.deleteInteraction` orchestration through the interaction and connection stores.

## Blocked by

- #122 — Add `bondScoreDelta` to `CrmInteraction` and Populate on AI Update
