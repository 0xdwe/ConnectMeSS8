# #063 Pass 4.5 PRD pre-flight

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-26-connection-persistence-pass-4-5-prd.md

## What to build

No-code pre-flight gate before Pass 4.5 implementation begins. Confirm Pass 4.2 code-track is on `main`, the sign-out hotfix is on `main`, no in-flight branches touch the connection / interaction / event seam, and the user has accepted the PRD's hotfix-era data-loss decision (Q7).

## Acceptance criteria

- [ ] `main` contains all Pass 4.2 merges (#054–#062) plus the iOS hotfix and the sign-out hotfix.
- [ ] `git status` clean on `main`; no in-flight branches modifying `lib/src/state/app_state.dart`'s mutating methods, `lib/src/state/firebase_providers.dart`, or `firestore/firestore.rules`.
- [ ] PRD's "Hotfix-era data loss" decision (Q7) acknowledged: hotfix-era user-added connections in RAM will not be preserved across the Pass 4.5 upgrade. The one-time UX notice for hotfix-era accounts is in scope.
- [ ] Pass 4.2 `flutter test test/state/` baseline confirmed (130+ passed, 0 failed) so Pass 4.5 deltas can be measured.
- [ ] PRD §"Proposed issue sequence" reflects the actual issue numbers used in the tracker (this issue is #063; the rest follow sequentially).

## Blocked by

None — must run first.
