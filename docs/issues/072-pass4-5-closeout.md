# #072 Pass 4.5 closeout + revert sign-out hotfix + progress update

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-26-connection-persistence-pass-4-5-prd.md

## What to build

Close Pass 4.5 after production cutover (#071) lands. Revert the sign-out hotfix on `lib/src/state/app_state.dart` and rewrite the 5 hotfix tests at `test/state/app_state_test.dart:224-365` to assert the new "Firestore is the source of truth" behavior. Document the completed scope in `progress.md`. File `AppUser` cleanup as a follow-up issue (PRD Q13).

## Acceptance criteria

- [ ] `AppController.signOut()` reverts from the hotfix's "preserve user data + cascade samples" shape to the trivial post-Pass-4.5 shape. Snapshot listeners tear down via the auth-aware provider rebuild from #058 + #064–#068; in-memory state clears naturally on the next sign-in's snapshot replay from Firestore.
- [ ] The 5 hotfix tests at `test/state/app_state_test.dart` (the "signOut preserves user data (hotfix)" group) are rewritten to assert the new behavior: signOut tears down listeners; subsequent signIn rebuilds connections / interactions / events from Firestore.
- [ ] `progress.md` updated:
  - Pass 4.5 status moves from "in progress" to "shipped".
  - The 10 Pass 4.5 issues are listed under Pass 4.5 done with merge commits.
  - The two-device smoke evidence from #071 is referenced.
  - The hotfix entry under Pass 4 done is marked as superseded.
  - Test baseline progression gains rows for each Pass 4.5 issue.
- [ ] `AppUser` cleanup follow-up issue filed (mirroring `currentUserProvider` for `displayName` and `email`; deletes the legacy `AppUser` model from `lib/src/models/social_models.dart`). PRD Q13 reasoning carried over.
- [ ] Pass 4.5 closeout commit message names the deferred items: orphan memory reconciliation (Pass 4.6, PRD Q9), AppUser cleanup (follow-up issue), Pass 4.4 Cloud Functions / FCM push.
- [ ] `flutter analyze` clean. `flutter test test/state/` stays above baseline (count includes all Pass 4.5 deltas plus the rewritten hotfix tests).

## Blocked by

- #071
