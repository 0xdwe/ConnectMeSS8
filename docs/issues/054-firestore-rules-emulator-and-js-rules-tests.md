# #054 Firestore rules + emulator + JS rules tests

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-24-firebase-memory-store-pass-4-2-prd.md

## What to build

Add Firestore rules, emulator config, and JS rules tests for owner-scoped memory docs at `users/{uid}/memories/{contactId}`. Rules enforce auth ownership and document shape before any production memory writes land.

## Acceptance criteria

- [ ] `firebase.json` configures Firestore/Auth emulators and points to Firestore rules.
- [ ] Rules allow only signed-in owners to read/list/create/update/delete their own memories.
- [ ] Rules deny anonymous and other-user access.
- [ ] Rules require only `markdown`, `updatedAt`, `schemaVersion` for memory docs.
- [ ] Rules enforce `markdown` string <= 64KB, `updatedAt` timestamp, `schemaVersion` int.
- [ ] JS rules tests cover allow/deny cases and run locally via emulator.
- [ ] Firestore test setup documented for teammates.

## Blocked by

- #053
