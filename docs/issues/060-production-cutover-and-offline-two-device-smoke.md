# #060 Production cutover + offline two-device smoke

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-24-firebase-memory-store-pass-4-2-prd.md

## What to build

Cut production memory persistence over to UID-scoped Firestore, enable Firestore offline persistence, preserve existing AI Update confirmation/rollback behavior, then verify the cross-device claim with a live two-device smoke test.

## Acceptance criteria

- [ ] Production path uses `FirebaseMemoryStore` for signed-in users.
- [ ] Firestore offline persistence explicitly enabled.
- [ ] `AiUpdate.commit` keeps memory-write-then-app-state-mutation contract and rollback/error behavior.
- [ ] Existing widget tests remain fast via `InMemoryMemoryStore` where Firestore irrelevant.
- [ ] Same-account two-device/simulator smoke shows memory created/updated on one appears on the other.
- [ ] Offline write is accepted locally and syncs later automatically.
- [ ] Smoke validates live rules against `connect-me-e20b1`.

## Blocked by

- #055
- #058
- #059
