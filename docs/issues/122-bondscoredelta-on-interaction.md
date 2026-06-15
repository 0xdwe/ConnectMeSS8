# #122 — Add `bondScoreDelta` to `CrmInteraction` and Populate on AI Update

**Parent:** #121  
**Branch:** `feat/122-bondscoredelta-on-interaction`  
**Triage:** `ready-for-agent`

---

## Parent

#121 — Delete Activity Log Entry + Rebuild Memory

## What to build

Add a `bondScoreDelta` field to `CrmInteraction` so that each activity log row carries the exact score impact it had on the connection. This is the foundation for reverting the connection score when an interaction is later deleted.

End-to-end behavior:
- `CrmInteraction` gains a `bondScoreDelta` integer, defaulting to `0`.
- `InteractionStore` adapters round-trip the field through persistence.
- AI Update commits populate the generated interaction's `bondScoreDelta` with the delta applied to the connection.
- `logInteraction` sets `bondScoreDelta` to `0` for manually logged rows.

## Acceptance criteria

- [ ] `CrmInteraction` model includes `bondScoreDelta` with default `0` and `copyWith` support.
- [ ] `InMemoryInteractionStore` and `FirebaseInteractionStore` round-trip `bondScoreDelta`.
- [ ] AI Update commit sets `bondScoreDelta` on the persisted interaction equal to the delta applied to `Connection.bondScore`.
- [ ] `AppController.logInteraction` persists `bondScoreDelta = 0`.
- [ ] Unit tests verify schema round-trip and AI Update population.

## Blocked by

None - can start immediately.
