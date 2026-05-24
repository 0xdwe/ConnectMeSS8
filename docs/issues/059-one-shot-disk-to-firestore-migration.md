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
- [ ] **Rules update + rules tests:** `firestore/firestore.rules` gains an owner-only `match /users/{uid}` block that allows write of a single `migratedFromDiskAt` (timestamp) field on the user document, with `firestore/rules.test.js` covering allow/deny (owner allow, non-owner deny, anonymous deny, extra/wrong-typed fields rejected). Today the rules file only matches `users/{uid}/memories/{contactId}`, so the sentinel write is currently default-denied.
- [ ] **Ordering with `memorySeedingProvider`:** migration runs before (or atomically with) the Pass 3 seeding bootstrap for the active user, and seeding skips when `migratedFromDiskAt` is set on the user document. Today seeding (in `lib/src/state/memory/memory_providers.dart`) populates an empty store from connections; without ordering protection it can fire first, fill Firestore, and starve the migration's empty-collection guard, silently abandoning local disk content.
- [ ] Non-empty remote collection skips migration even if local files exist.
- [ ] Re-running migration is a no-op after first successful migration.
- [ ] Source local files remain on disk.
- [ ] Migration is account-scoped, not device-scoped.
- [ ] Tests cover copy, sentinel, idempotency, non-empty skip, source preservation, and the seeding-ordering interaction.

## Blocked by

- #057
- #058
