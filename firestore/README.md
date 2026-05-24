# Firestore rules tests

This folder owns the Connect Me Firestore security rules and the local
test suite that exercises them. It lives outside the Flutter test tree
because it has its own JavaScript toolchain and runs against the
Firebase emulator instead of `flutter test`.

## What's here

- `firestore.rules` — owner-scoped, shape-validating rules for
  per-contact memory documents at `users/{uid}/memories/{contactId}`.
- `firestore.indexes.json` — composite index config (empty for now).
- `package.json` — pinned `@firebase/rules-unit-testing`, `firebase-admin`,
  and `jest` for the rules tests. Versions are exact, no `^` or `~`.
- `package-lock.json` — tracked so installs reproduce across the team.
- `rules.test.js` — Jest suite covering the allow/deny matrix.

## Prerequisites

The Firebase emulator needs JDK 21 or newer. On macOS the easy path is
`brew install openjdk@21` and follow Homebrew's `PATH` hint. If you see
a JVM error when booting the emulator, this is almost always why.

## Running the tests locally

The tests need the Firestore emulator running. The simplest way to do
that is to let `firebase-tools` boot the emulator, run jest inside the
emulator's lifecycle, and tear it down on exit.

From the repo root:

```bash
cd firestore && npm install && cd ..
npx -y firebase-tools@latest emulators:exec \
  --only firestore \
  --project connect-me-rules-test \
  "cd firestore && npm test"
```

`npm install` is one-time per checkout. After that, just re-run the
`emulators:exec` line.

The `--project connect-me-rules-test` ID is intentionally not the live
project (`connect-me-e20b1`). The rules tests boot the emulator under a
throwaway project ID so a misconfigured local environment can never
accidentally hit the live backend. The Jest suite hardcodes the same
ID when it initializes its test environment.

If you already have the emulator running in another terminal
(`firebase emulators:start --only firestore`), you can run jest
directly:

```bash
cd firestore && npm test
```

## A note on scope

This is the **rules-test suite only**. It does not exercise any Dart
code. Pass 4.2's Dart adapter, migration, and provider tests live
under `integration_test/` (issues #056 + #057) because `flutter test`
is a headless Dart VM that cannot load Firebase plugin channels. They
run against the same emulator via:

```bash
firebase emulators:exec --only firestore,auth \
  --project connect-me-rules-test \
  "flutter test integration_test -d macos"
```
