# 102 — Firebase Storage profile avatar upload/remove

## Parent

Auth-backed User Profile PRD: `docs/prd/2026-06-05-auth-backed-user-profile-prd.md`

## What to build

Wire Edit Profile image picking to Firebase Storage and persist the resulting download URL through Firebase Auth `photoURL`.

## Acceptance criteria

- [ ] Add `firebase_storage` dependency and `firebaseStorageProvider`.
- [ ] `UserProfileService` uploads picked image only when Save is tapped.
- [ ] Avatar upload path is exactly `users/{uid}/profile/avatar.jpg`.
- [ ] Upload writes image metadata/content type where available.
- [ ] Upload then calls `getDownloadURL()` and updates Firebase Auth `photoURL`.
- [ ] Picking an image before Save only changes local preview.
- [ ] Remove Photo best-effort deletes the Storage object, then clears Auth `photoURL`.
- [ ] Missing Storage object during remove is ignored.
- [ ] Upload/remove failures keep the user on Edit Profile and show failure feedback.
- [ ] Own User Profile no longer offers emoji avatar as an edit option; emoji remains a Connection-avatar concept.
- [ ] Tests cover upload-on-save, no-upload-on-pick, remove-photo, failure behavior, and Profile photo rendering.

## Blocked by

#101 — Edit Profile saves Auth display name with read-only email.
