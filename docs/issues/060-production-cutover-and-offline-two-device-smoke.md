# #060 Production cutover + offline two-device smoke

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-24-firebase-memory-store-pass-4-2-prd.md

## What to build

Cut production memory persistence over to UID-scoped Firestore, enable Firestore offline persistence, preserve existing AI Update confirmation/rollback behavior, then verify the cross-device claim with a live two-device smoke test.

## Acceptance criteria

- [ ] Production cutover verified end-to-end on at least one of {macOS, iOS Simulator, Android Emulator, physical device}. Chrome web does not count for cutover verification.
- [ ] Firestore offline persistence explicitly enabled in app startup (e.g. `FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true)` before any read/write). macOS desktop in particular needs this set explicitly.
- [ ] `AiUpdate.commit` keeps memory-write-then-app-state-mutation contract and rollback/error behavior.
- [ ] Existing widget tests remain fast via `InMemoryMemoryStore` where Firestore irrelevant.
- [ ] Same-account two-device/simulator smoke documented in `progress.md`. Pick at least two of {macOS, iOS Simulator, Android Emulator, physical device}, name them, and capture the trace: sign in as the same test account on both, write on device A while online, observe on device B within 10s. iOS coverage is required either here or via #053's real-device gate, since the iOS-only `currentUserProvider` loop fixed in `fix/current-user-provider-invalidation-loop` makes iOS the platform most likely to surprise.
- [ ] Offline write step captured in the same trace: take device B offline, write on device B, reconnect, and observe the write replicates within 10s.
- [ ] Smoke validates live rules against `connect-me-e20b1`.
- [ ] Rules-denial evidence captured: a second signed-in test user cannot read user A's memories collection (Firebase console rules-playground screenshot or an explicit emulator-style denial test against the live project is sufficient). Aligns with PRD user story #7.

## Blocked by

- #055
- #058
- #059

## Notes

- The "production path uses `FirebaseMemoryStore` for signed-in users" line that originally lived in this AC is already satisfied by #058 (`lib/src/state/memory/memory_providers.dart` returns `FirebaseMemoryStore(firestore: ..., uid: user.uid)` for signed-in users). #060's net-new code is offline persistence config; the rest is real-device verification.
