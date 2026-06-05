# 103 — Profile avatar Firebase Storage rules

## Parent

Auth-backed User Profile PRD: `docs/prd/2026-06-05-auth-backed-user-profile-prd.md`

## What to build

Add Firebase Storage rules and test coverage for the profile-avatar object namespace.

## Acceptance criteria

- [ ] `firebase.json` declares Storage rules and Storage emulator config if missing.
- [ ] Storage rules allow only signed-in owner access at `users/{uid}/profile/avatar.jpg`.
- [ ] Anonymous access is denied.
- [ ] Cross-user read/write/delete is denied.
- [ ] Writes require image content type.
- [ ] Writes require size <= 2MB.
- [ ] Listing/broad folder access is not allowed.
- [ ] Rules tests cover owner allow, anonymous deny, cross-user deny, bad content type, oversized write, delete, and disallowed sibling paths.
- [ ] Docs note that Firebase Auth `photoURL` stores a tokenized HTTPS download URL; token behavior is accepted for prototype scope.

## Blocked by

#102 — Firebase Storage profile avatar upload/remove.
