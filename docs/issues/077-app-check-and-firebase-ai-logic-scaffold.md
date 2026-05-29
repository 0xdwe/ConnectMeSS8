# #077 App Check + Firebase AI Logic SDK scaffold

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-27-llm-ai-update-pass-4-3-prd.md

## What to build

Add the Firebase AI Logic and App Check SDK dependencies to the Flutter app, initialize App Check before any AI Logic call, and expose the Firebase AI handle through a Riverpod provider. No production AI Update behavior changes yet — `aiUpdateProvider` still binds `MockAiUpdate`. This is the scaffolding that lets Pass 4.3 issues #078–#081 light up.

App Check uses the debug provider in `kDebugMode`, Play Integrity on Android release, and DeviceCheck on iOS release. App Attest is deferred per PRD §Q3. The boundary function for App Check init mirrors the existing `enableFirestoreOfflinePersistence` pattern from Pass 4.2 #060.

## Acceptance criteria

- [ ] `firebase_ai` (or current `firebase_vertexai` / Firebase AI Logic Dart package) and `firebase_app_check` added to `pubspec.yaml` with pinned versions.
- [ ] App Check boundary function lives in `lib/src/state/firebase_providers.dart`, alongside `enableFirestoreOfflinePersistence`.
- [ ] `main.dart` calls App Check activation between `Firebase.initializeApp` and `enableFirestoreOfflinePersistence`.
- [ ] Debug builds (`kDebugMode`) use the debug provider; the debug token is logged to console once on first run for the user to register in the Firebase console.
- [ ] Release Android uses Play Integrity; release iOS uses DeviceCheck. Other release targets (macOS, Linux, web) fall back to debug provider with a console warning.
- [ ] `firebaseAiProvider` Riverpod provider returns the Firebase AI Logic SDK handle, mirroring the shape of `firestoreProvider`.
- [ ] Provider is testable via override (e.g. injecting a stand-in handle) without instantiating real Firebase.
- [ ] App Check init failure is loud — throws or logs prominently — so misconfiguration cannot ship silently.
- [ ] `aiUpdateProvider` still binds `MockAiUpdate` for now. No user-visible behavior change.
- [ ] Documentation snippet added under `docs/operations/` (or appended to existing Firebase ops doc) covering: enabling AI Logic in console, registering the debug App Check token, and confirming Gemini Developer API path is active.
- [ ] `flutter test test/state/` baseline unchanged (232 passed + 2 skipped).
- [ ] `flutter analyze` clean for new files.

## Blocked by

#076
