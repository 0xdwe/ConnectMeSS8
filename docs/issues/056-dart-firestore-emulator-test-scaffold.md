# #056 Dart Firestore emulator test scaffold

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-24-firebase-memory-store-pass-4-2-prd.md

## What to build

Add Dart/Flutter test helpers that initialize Firebase and route Firestore/Auth SDKs to local emulators for adapter, migration, and provider tests while preserving fast `InMemoryMemoryStore` widget-test overrides.

## Acceptance criteria

- [ ] Shared Dart test helper initializes Firebase for emulator-backed tests.
- [ ] Firestore points at `localhost:8080`; Auth points at `localhost:9099`.
- [ ] Canonical emulator-backed test command documented.
- [ ] Existing widget tests can keep overriding `memoryStoreProvider` with `InMemoryMemoryStore`.
- [ ] Scaffold supports future adapter/migration tests without `fake_cloud_firestore`.

## Blocked by

- #053
- #054
