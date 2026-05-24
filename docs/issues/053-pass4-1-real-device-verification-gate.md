# #053 Pass 4.1 real-device verification gate

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-24-firebase-memory-store-pass-4-2-prd.md

## What to build

No-code verification gate for shipped Pass 4.1 Firebase Auth against live `connect-me-e20b1` before Firestore work begins. Verify sign-up, sign-out, sign-in, wrong-password inline error handling on at least one supported real device/simulator; capture evidence.

## Acceptance criteria

- [ ] Live-project auth smoke covers sign-up, sign-out, sign-in.
- [ ] Wrong-password inline error handling verified.
- [ ] Evidence captured from device/simulator + Firebase console.
- [ ] Firestore work remains blocked until gate passes.

## Blocked by

None - can start immediately
