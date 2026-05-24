# #055 Rules CI + rules-only auto-deploy

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-24-firebase-memory-store-pass-4-2-prd.md

## What to build

Add GitHub Actions discipline for Firestore rules: PRs touching `firestore/` run JS rules tests; merges to `main` with rules changes deploy only Firestore rules to `connect-me-e20b1` after tests pass.

## Acceptance criteria

- [ ] PR workflow runs JS rules tests against emulator for `firestore/` changes.
- [ ] Main-branch workflow deploys Firestore rules after tests pass.
- [ ] Deploy command is rules-only; no functions/indexes/other Firebase resources deployed.
- [ ] Workflow uses `FIREBASE_SERVICE_ACCOUNT` secret.
- [ ] Required service-account role is documented as Firebase Rules Admin.

## Blocked by

- #054
