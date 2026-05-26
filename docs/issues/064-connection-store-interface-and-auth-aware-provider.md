# #064 ConnectionStore interface + InMemoryConnectionStore + auth-aware connectionStoreProvider

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-26-connection-persistence-pass-4-5-prd.md

## What to build

Introduce `ConnectionStore` as the pure-Dart seam for connection persistence, mirroring `MemoryStore` from Pass 3 / Pass 4.2. Ship the in-memory test adapter, the auth-aware Riverpod provider, and the signed-out sentinel. No Firestore yet.

The interface adds a `Stream<Map<String, Connection>> snapshot()` shape on top of the async load / save / delete / listAll surface, so Q6's snapshot listener pattern (introduced in #065) has a clean contract from day one.

## Acceptance criteria

- [ ] `ConnectionStore` interface in `lib/src/state/connections/connection_store.dart` with async `load`, `save`, `delete`, `listAll`, plus `Stream<Map<String, Connection>> snapshot()` and a synchronous `Map<String, Connection>? snapshotSync()` mirror getter.
- [ ] `InMemoryConnectionStore` in the same package implements every method, broadcasts on its own snapshot stream when save / delete fire.
- [ ] `connectionStoreProvider` in `lib/src/state/connections/connection_providers.dart` watches `currentUserProvider`; signed-out access returns a `_SignedOutConnectionStore` sentinel whose async methods throw `StateError`.
- [ ] Sentinel matches `_SignedOutMemoryStore` shape — including pulling `snapshot()` to an immediately-completing empty stream rather than throwing on stream subscribe (so widgets that watch the stream don't crash on sign-out).
- [ ] `connectionStoreProvider` rebuilds when the auth UID changes (verified via headless test using `MockFirebaseAuth`).
- [ ] Headless tests in `test/state/connections/connection_store_test.dart` cover: round-trip, missing, delete-missing-noop, listAll empty / non-empty, snapshot stream emits on save / delete / clear.
- [ ] Headless tests in `test/state/connections/connection_provider_test.dart` cover: signed-out sentinel throws on async, signed-in returns the in-memory store, auth swap rebuilds the store identity.
- [ ] No production code path reads the new provider yet — `AppController` is unchanged.
- [ ] `flutter analyze` clean on touched files. `flutter test test/state/` stays at or above the current baseline.

## Blocked by

- #063
