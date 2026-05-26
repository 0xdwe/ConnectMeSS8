# #073 Pass 4.5 emulator integration-test verification

Labels: issue, needs-triage, deferred

## Parent

docs/prd/2026-05-26-connection-persistence-pass-4-5-prd.md

## What to build

GREEN-confirm the Pass 4.5 store-layer integration tests against the Firebase emulator on a target where Firebase Auth's keychain works.

Pass 4.5's #065, #067, and #068 each ship integration test files under `integration_test/state/connections/` that:

- Compile cleanly (`flutter analyze` passes).
- Are structurally correct against the AC (verified by reviewer code-read).
- Could not be GREEN-confirmed during the implementation pass because the macOS-desktop run target hits `[firebase_auth/keychain-error]` on `signInAnonymously` — macOS has no keychain-access-groups entitlement equivalent to the iOS one Pass 4.2 #058 added, and adding signing entitlements to the macOS Runner pulls in development certificate complications that affect every macOS build.

This issue picks one of the three options the #065 worker named and runs the three integration suites end-to-end.

## Acceptance criteria

- [ ] Decide on the target. Options:
  - **A.** iOS Simulator. Pass 4.2's iOS entitlements at `ios/Runner/Runner.entitlements` already cover `keychain-access-groups`. Boot a simulator, run `flutter test integration_test/state/connections/ -d <udid>`. Lowest-risk path.
  - **B.** Real macOS desktop signing. Enable development signing in Xcode, set `DEVELOPMENT_TEAM` in `macos/Runner.xcodeproj/project.pbxproj`. Project config change affecting every macOS build.
  - **C.** Android Emulator. Should also work but requires booting a separate emulator.
- [ ] Run `firebase emulators:exec --only firestore "flutter test integration_test/state/connections/ -d <target>"` with all three Pass 4.5 store integration suites.
- [ ] Each suite passes GREEN. Test counts:
  - `firebase_connection_store_test.dart` — 14 tests (13 from #065 worker + 1 SUB-1 fix).
  - `firebase_interaction_store_test.dart` — count from #067.
  - `firebase_event_store_test.dart` — count from #068.
- [ ] Document the chosen target and run command in `progress.md` so future Pass-4.x emulator work has a known-good path.
- [ ] If the SUB-3 flaky-wait pattern (`Future.delayed` in cross-instance snapshot tests) shows up as an actual flake, replace with `expectLater(stream, emitsThrough(...))` or `firstWhere` predicate-based waits. The pattern is documented in `.agent-runs/065-reviewer.md` SUB-3.

## Why deferred

User is on a single-device prototype scope. Pass 4.2's #060 device-half and #053 iOS-real-device-gate were already deferred under the same logic. The headless suite + structural review covers the seam-correctness side; emulator GREEN is evidence the reviewer accepted as a follow-up given the environment block.

## Blocked by

None — can be picked up whenever the user picks a target. Nothing else in Pass 4.5 is gated on this; #069/#070/#071/#072 all proceed without it.
