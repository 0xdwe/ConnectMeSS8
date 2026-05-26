# #075 Sign-out test gap: exercise the auth-aware rebuild path

Labels: issue, needs-triage, follow-up

## Parent

docs/prd/2026-05-26-connection-persistence-pass-4-5-prd.md
docs/issues/070-app-controller-write-through-store.md (review S4)

## What to build

Add at least one test that exercises the production sign-out flow: `firebaseAuthProvider.signOut()` triggers the auth-aware rebuild cascade that tears down the four snapshot listener subscriptions, then verifies a subsequent sign-in (as the same or different user) replays state from Firestore via the new listeners.

## Background

The 5 rewritten hotfix tests at `test/state/app_state_test.dart:357-480` (Pass 4.5 #070) verify what `AppController.signOut()` does synchronously: flips `isAuthed`, resets tab, clears in-memory mirrors. They do NOT exercise the production sign-out flow:

```dart
// settings_tab.dart:108-119
await ref.read(firebaseAuthProvider).signOut();      // 1. fires auth swap
ref.read(appControllerProvider.notifier).signOut();  // 2. local clear
```

Step 1 is what tears down the four snapshot listeners (via `currentUserProvider` rebuild → store providers rebuild → AppController rebuild → previous build's `onDispose` cancels subs). The current tests use a `MockFirebaseAuth` locked at `signedIn: true`, so the auth-swap path is not exercised. Step 2 is all that's tested.

Practical consequence: a test gap, not a runtime defect. The listener-teardown contract is implicitly relied on for the next sign-in to start clean. If a future change breaks the rebuild path (e.g. someone replaces `ref.watch(currentUserProvider)` with `ref.read` somewhere), these tests would still pass.

## Acceptance criteria

- [ ] At least one new test in `test/state/app_state_test.dart` (or a new test file under `test/state/`) calls `mockFirebaseAuth.signOut()` and asserts:
  - The four store providers (connection / interaction / event / userDoc) rebuild to their signed-out sentinels.
  - The previous AppController's snapshot subscriptions are cancelled (verify via a recording fake or by asserting no further state mutations).
  - On subsequent `signIn`, AppController rebuilds and its new listeners pick up the seeded data from the (in-memory) store.
- [ ] The test uses `MockFirebaseAuth` with toggleable signed-in state (the library supports `signOut()` and `signInWithEmailAndPassword`).
- [ ] No regression in the 20 existing AppController tests.
- [ ] `flutter analyze` clean.

## Blocked by

None. Pass 4.5 is shipped; this is post-#070 polish.
