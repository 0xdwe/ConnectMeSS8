# Auth-backed User Profile PRD

Date: 2026-06-05

## Problem

The Profile screen still reads legacy placeholder `AppUser` state, so name, email, and photo do not reflect the signed-in Firebase account. Firebase Storage is now available for user-uploaded profile photos.

## Decisions

### Q1. What owns User Profile data?

Firebase Auth owns the User Profile for this pass.

- Email is read-only from `FirebaseAuth.currentUser.email`.
- Display name is `FirebaseAuth.currentUser.displayName`.
- Profile photo is `FirebaseAuth.currentUser.photoURL`.
- Firebase Storage stores the uploaded avatar object.
- Firestore `users/{uid}` remains for existing user-doc fields and sentinels; do not add profile fields there in this pass.

Rationale: User Profile is account identity, not Relationship Graph data. This avoids reviving legacy `AppUser` as durable state and keeps schema/rules blast radius small.

### Q2. Can users edit email?

No. Email is shown read-only. Changing account email requires reauthentication and verification UX, which is a separate account-security feature.

### Q3. Is name required?

Yes. Display name is required wherever the user can submit profile identity.

- Signup collects name and calls `updateDisplayName` after account creation.
- Edit Profile validates trimmed name and blocks empty saves with inline copy: `Enter your name`.
- Profile display may still fallback for legacy/null accounts: email prefix, then `Your profile`.

### Q4. How does avatar upload work?

Upload only on Save.

- Picking an image updates local preview only.
- Save uploads to Storage path `users/{uid}/profile/avatar.jpg`.
- Save then calls `getDownloadURL()` and updates Auth `photoURL` with the URL.
- Failed upload/save leaves the user on Edit Profile and shows failure feedback.
- Double-save is prevented with a loading state.

### Q5. How does remove-photo work?

Best-effort delete the Storage object, then clear Auth `photoURL`.

- Missing object is ignored.
- Permission/network failures show failure feedback and do not claim success.

### Q6. Should own profile support emoji avatar?

No. Emoji avatars remain for Connections. User Profile supports uploaded image or generated placeholder/initials.

### Q7. What seam should own profile mutations?

Add `UserProfileService`.

Responsibilities:

- derive an `AccountProfile` from current Firebase Auth user;
- update required display name;
- upload avatar + update Auth `photoURL`;
- remove avatar + clear Auth `photoURL`.

UI tests can override the service rather than touching Firebase Storage SDK directly.

### Q8. Storage rules

Add Firebase Storage rules for only the owner’s profile avatar:

- path: `users/{uid}/profile/avatar.jpg`;
- signed-in owner only;
- image content type required on write;
- max size 2MB;
- no cross-user access.

Token download URLs are accepted prototype behavior: the app stores the HTTPS URL in Auth `photoURL`; access via that URL is bearer-token-like.

## Non-goals

- Firestore user-profile document fields.
- Account email change.
- Reauthentication flows.
- Profile photo on signup.
- Broad deletion of legacy `AppUser` / `AppController.updateUser`.
- Cross-device/live-device Storage verification; ADR-0003 still applies.

## Acceptance summary

- Profile screen shows signed-in account email/name/photo, not placeholders.
- Signup requires name and persists it into Firebase Auth displayName.
- Edit Profile saves display name through Firebase Auth; email is read-only.
- Edit Profile uploads/removes avatar through Firebase Storage and persists URL via Auth `photoURL`.
- Storage rules constrain profile-avatar access.
- Legacy `AppUser` no longer drives the Profile screen.
