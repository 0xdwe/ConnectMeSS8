# #124 — `MemoryRebuilder` Seam and Full Memory Rebuild on Delete

**Parent:** #121  
**Branch:** `feat/124-memory-rebuilder-seam`  
**Triage:** `ready-for-agent`

---

## Parent

#121 — Delete Activity Log Entry + Rebuild Memory

## What to build

Introduce a new `MemoryRebuilder` seam and wire it into the delete flow so that deleting an interaction regenerates the contact's `MemoryDocument` from the remaining history.

End-to-end behavior:
- New `MemoryRebuilder` interface accepts current `Connection`, current `MemoryDocument`, remaining `CrmInteraction`s, and the deleted `CrmInteraction`.
- `LlmMemoryRebuilder` uses a dedicated prompt to remove references to the deleted interaction and regenerate summary, history, preferences, topics, upcoming, and topic-scoped suggestions.
- `FakeMemoryRebuilder` supports deterministic tests.
- After `AppController.deleteInteraction` removes the interaction and updates the connection, it calls `MemoryRebuilder.rebuild`, saves the rebuilt `MemoryDocument` through `MemoryStore`, updates `Connection.nextStep` from the result, bumps `memoryEpochProvider`, clears `recommendationsCacheProvider`, and sets `lastAiUpdatedContactId`.

## Acceptance criteria

- [ ] `MemoryRebuilder` interface and `MemoryRebuildResult` type are defined.
- [ ] `LlmMemoryRebuilder` adapter implements the interface with a dedicated prompt.
- [ ] `FakeMemoryRebuilder` adapter exists for tests.
- [ ] `AppController.deleteInteraction` invokes the rebuild after interaction/connection updates.
- [ ] Rebuilt memory is saved; `nextStep` is updated from the result.
- [ ] `memoryEpochProvider` is bumped and recommendation cache is cleared after save.
- [ ] Stale topics and summary from the deleted interaction no longer appear after rebuild.
- [ ] Unit tests verify rebuild integration using the fake adapter.

## Blocked by

- #123 — Delete Activity Log Row with Confirmation, Undo, and Connection Recalculation
