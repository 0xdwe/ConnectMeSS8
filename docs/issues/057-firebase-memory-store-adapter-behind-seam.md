# #057 FirebaseMemoryStore adapter behind seam

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-24-firebase-memory-store-pass-4-2-prd.md

## What to build

Implement `FirebaseMemoryStore` as a third `MemoryStore` adapter, bound to one UID and storing canonical rendered memory markdown at `users/{uid}/memories/{contactId}`. Keep it behind the seam, emulator-tested, not yet production-bound.

## Acceptance criteria

- [ ] Adapter implements existing async `MemoryStore` contract.
- [ ] Save writes `markdown`, `updatedAt`, `schemaVersion: 1`.
- [ ] Load, delete, load-missing, listAll behavior matches adapter contract.
- [ ] Contact id remains the stable Firestore document id.
- [ ] Adapter never reads global auth state per operation; UID supplied at construction.
- [ ] Firestore offline/local-acceptance behavior is documented in adapter comments/tests.
- [ ] Emulator tests cover round-trip, missing, delete, listAll, schemaVersion, malformed/oversized cases.
- [ ] `FileMemoryStore` remains tested but not changed into a write-through cache.

## Blocked by

- #056
