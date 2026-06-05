# 104 — Auth-backed User Profile closeout

## Parent

Auth-backed User Profile PRD: `docs/prd/2026-06-05-auth-backed-user-profile-prd.md`

## What to build

Close the pass by updating docs/progress and recording validation evidence.

## Acceptance criteria

- [ ] `CONTEXT.md` includes the `User Profile` term and source-of-truth contract.
- [ ] `progress.md` records what shipped, test commands, and known deferred work.
- [ ] Any legacy `AppUser` / `AppController.updateUser` leftovers are explicitly listed as deferred cleanup or removed if naturally dead.
- [ ] Targeted Flutter tests for the touched profile/auth state pass.
- [ ] Storage rules tests pass.
- [ ] No full `flutter test` sweep is run without explicit user permission.

## Blocked by

#100 — Auth-backed User Profile read + signup name.
#101 — Edit Profile saves Auth display name with read-only email.
#102 — Firebase Storage profile avatar upload/remove.
#103 — Profile avatar Firebase Storage rules.
