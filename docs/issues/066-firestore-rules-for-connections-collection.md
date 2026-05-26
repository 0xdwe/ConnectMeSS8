# #066 Firestore rules + JS rules tests for connections collection

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-26-connection-persistence-pass-4-5-prd.md

## What to build

Extend `firestore/firestore.rules` and `firestore/rules.test.js` to cover the new `connections` collection. Owner-scoped, shape-validated, with closed-shape `hasOnly` plus per-field guards for optional fields (PRD Q8). The CI auto-deploy from #055 picks up the new rules without workflow changes.

## Acceptance criteria

- [ ] `firestore/firestore.rules` gains `match /users/{uid}/connections/{contactId}`.
- [ ] Rules allow only the owner (`request.auth.uid == uid`) to read / list / create / update / delete.
- [ ] Shape validation closes the field set: required `id is string`, `name is string`, `category is string`, `avatar is string`, `bondScore is int && bondScore >= 0 && bondScore <= 100`, `nextStep is string`, `lastContact is timestamp`, `knownSince is timestamp`, `preferredChannels is list`, `schemaVersion is int`, `updatedAt is timestamp`.
- [ ] Optional fields handled with `data.x is type || !('x' in data.keys())` guards: `email`, `notes`, `isSample`.
- [ ] `hasOnly` closes the shape so unknown fields are rejected.
- [ ] `firestore/rules.test.js` adds at least 12 cases for the connections collection: owner read, owner list, owner create, owner update, owner delete, anonymous denied (read + write), cross-user denied (read + write), oversized markdown N/A here but bondScore out-of-range rejected, missing required field rejected, unknown extra field rejected, wrong type rejected.
- [ ] Existing tests stay green; total `npm test` count is at least the prior 38 plus the new connection cases.
- [ ] Rules CI workflow at `.github/workflows/rules-tests.yml` picks up the new tests on PR.
- [ ] Rules deploy workflow at `.github/workflows/rules-deploy.yml` deploys the updated rules on merge to main.

## Blocked by

- #064
