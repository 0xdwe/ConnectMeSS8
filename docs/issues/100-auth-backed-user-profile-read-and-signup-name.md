# 100 — Auth-backed User Profile read + signup name

## Parent

Auth-backed User Profile PRD: `docs/prd/2026-06-05-auth-backed-user-profile-prd.md`

## What to build

Move the Profile screen off placeholder `AppUser` state and make signup collect/persist display name through Firebase Auth.

## Acceptance criteria

- [ ] Add an `AccountProfile` value and `UserProfileService` seam for reading Firebase Auth account identity.
- [ ] Add provider wiring so Profile can read current signed-in account profile without `AppController.state.user`.
- [ ] Profile screen shows Firebase Auth email.
- [ ] Profile screen shows Firebase Auth `displayName`; legacy null displayName falls back to email prefix, then `Your profile`.
- [ ] Profile screen uses Firebase Auth `photoURL` when present.
- [ ] Signup form requires a non-empty trimmed name.
- [ ] Successful signup calls Firebase Auth `updateDisplayName` after account creation.
- [ ] Signup failure still surfaces existing Firebase Auth errors.
- [ ] Headless/widget tests cover Profile rendering from account profile and signup displayName persistence.

## Blocked by

None.
