# #126 — Offline/Error Handling for Activity Log Deletion

**Parent:** #121  
**Branch:** `feat/126-delete-activity-log-offline-error`  
**Triage:** `ready-for-agent`

---

## Parent

#121 — Delete Activity Log Entry + Rebuild Memory

## What to build

Polish the delete flow so it behaves gracefully when the device is offline or the memory rebuild fails.

End-to-end behavior:
- The interaction delete itself is allowed to proceed while offline; Firestore's local persistence handles queuing.
- If the `MemoryRebuilder` call fails (no network, model error, timeout), show a SnackBar error explaining that AI Insights could not be refreshed.
- The deleted interaction stays deleted; the memory remains in its pre-delete state until the user manually refreshes AI Insights later.
- No spinner gets stuck; the pending-rebuild provider is cleared on failure.

## Acceptance criteria

- [ ] Deleting an interaction while offline succeeds at the store level.
- [ ] Rebuild failure surfaces a clear SnackBar error (no numeric/guilt copy).
- [ ] Pending rebuild provider is cleared on failure so the spinner stops.
- [ ] Memory stays stale after failure; user can manually refresh later.
- [ ] Unit/widget tests cover offline delete and rebuild-failure paths.

## Blocked by

- #124 — `MemoryRebuilder` Seam and Full Memory Rebuild on Delete
- #125 — AI Insights Spinner for Pending Memory Rebuild
