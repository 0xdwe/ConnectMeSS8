# #059 One-shot disk-to-Firestore migration

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-24-firebase-memory-store-pass-4-2-prd.md

## What to build

Add an authenticated one-shot migration that copies existing local markdown memories into Firestore only when the user's remote memory collection is empty. Leave local files untouched as backup and keep migration calm/invisible to users.

## Acceptance criteria

- [ ] Migration runs only while signed in.
- [ ] Empty remote collection + local files → copies each local memory via `FirebaseMemoryStore.save()`.
- [ ] Writes `migratedFromDiskAt` on the user document.
- [ ] Non-empty remote collection skips migration even if local files exist.
- [ ] Re-running migration is a no-op after first successful migration.
- [ ] Source local files remain on disk.
- [ ] Migration is account-scoped, not device-scoped.
- [ ] Tests cover copy, sentinel, idempotency, non-empty skip, source preservation.

## Blocked by

- #057
- #058
