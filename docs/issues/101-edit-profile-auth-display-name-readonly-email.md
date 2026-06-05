# 101 — Edit Profile saves Auth display name with read-only email

## Parent

Auth-backed User Profile PRD: `docs/prd/2026-06-05-auth-backed-user-profile-prd.md`

## What to build

Change Edit Profile so it edits Firebase Auth display name, shows email read-only, and no longer writes legacy `AppController.updateUser`.

## Acceptance criteria

- [ ] Edit Profile initializes from `AccountProfile`, not `AppController.state.user`.
- [ ] Email is visible but read-only/non-editable.
- [ ] Display name trims whitespace before save.
- [ ] Empty display name blocks save with inline `Enter your name` copy.
- [ ] Save calls `UserProfileService.updateDisplayName`.
- [ ] Save has loading state and prevents double-submit.
- [ ] Success pops the route and/or shows `Profile updated` without lying on failure.
- [ ] Failure keeps the user on Edit Profile and shows `Couldn’t update profile. Try again.`
- [ ] Existing Profile/EditProfile widget tests are updated without reviving `AppUser` as source of truth.

## Blocked by

#100 — Auth-backed User Profile read + signup name.
