Labels: docs

# Firebase AI Logic + App Check setup

## Why this exists

Pass 4.3 introduces `LlmAiUpdate`, the production adapter for the AI Update flow that calls Gemini through Firebase AI Logic on the user's behalf (PRD `2026-05-27-llm-ai-update-pass-4-3-prd.md`). The first time this code runs against the live `connect-me-e20b1` project, two things must already be configured: AI Logic must be enabled in the Firebase console, and App Check debug tokens must be registered for the device(s) running the app. This doc covers the one-time setup so the SDK call site lights up cleanly.

App Check matters here because Firebase AI Logic charges Gemini inference to the project's billing account. Without App Check, anyone with a leaked `firebase_options.dart` (which ships in every release binary) can hammer Gemini on the project's credit. The 9,400 NTD prototype credit is not safe to leave unprotected.

## One-time console setup (HITL)

1. **Open the Firebase console** for `connect-me-e20b1`.
2. **Enable AI Logic.** Sidebar → Build → AI Logic → enable, pick **Gemini Developer API** (not Vertex AI). Vertex's regional/IAM/audit features are unnecessary for the prototype and the Developer API has a generous free tier. The console auto-provisions the API on the linked GCP project.
3. **Confirm model availability.** The current default in this codebase is `gemini-3.1-flash-lite`. If the console suggests a newer Flash-Lite generation at the time of `LlmAiUpdate` work, update the constructor default in #080 to match.
4. **Set a Google Cloud budget alert.** Open https://console.cloud.google.com/billing for the project's billing account → Budgets & alerts → Create budget. Threshold around 1,000 NTD is plenty of headroom for prototype dogfooding while still catching runaway loops within minutes. Budgets are alert-only — they do not cap spend — so the threshold value is the email trigger, not a hard cap.
5. **Confirm App Check is reachable for the platform you'll exercise first.** Sidebar → Build → App Check → Apps. Each registered Flutter app (Android / iOS / web) should be visible. Status will read "Unregistered" until the next setup step runs.

## Per-device App Check debug token (HITL)

The first launch of the app on a development device prints a debug token to the Flutter console. Register it once per device per platform.

1. Run the app in debug mode (`flutter run`) on the target device.
2. In the Flutter console, look for a log line near startup similar to:
   - Android: `FirebaseAppCheck: Enter this debug secret into the allow list in the Firebase Console: <UUID>`
   - iOS: `[Firebase/AppCheck][I-FAA001001] Firebase App Check debug token: '<UUID>'`
3. Copy the UUID.
4. In Firebase Console → App Check → Apps → click the menu next to the platform → **Manage debug tokens** → **Add debug token**. Paste the UUID, name it (e.g. `james-iphone`, `ci-runner`), save.
5. The next call to a Firebase AI Logic / Firestore / any App-Check-protected API on that device succeeds. Until the token is registered, calls return `PERMISSION_DENIED`.

The debug token survives across runs on the same install. Reinstalling the app generates a fresh token; register the new one when that happens.

## Release-mode providers

Pass 4.3 release builds use the platform-native attestation providers automatically on launch targets, and fall back to the debug provider on everything else:

- **Android release** — Play Integrity. Configured automatically by `firebase_app_check` once the app is signed and uploaded through Google Play.
- **iOS release** — DeviceCheck. Configured automatically once the app has a real bundle id signed with the project's Apple developer account.
- **App Attest** is intentionally deferred (PRD §Q3). Adds enrollment complexity that does not earn its keep until App Store distribution.
- **Other release targets (web, macOS, Linux)** fall back to the debug provider with a console warning logged via `debugPrint`. None of these are launch targets per ADR-0003. Reaching the debug fallback in production means the credit-protection guard is the debug stub, not real attestation — promote the platform here AND in the Firebase console before treating it as a launch target.

## What runs when

`lib/main.dart` calls `activateAppCheck()` between `Firebase.initializeApp` and `enableFirestoreOfflinePersistence`. The function lives in `lib/src/state/firebase_providers.dart`:

- Debug builds (`kDebugMode`) → debug provider on every platform.
- Release Android → Play Integrity.
- Release iOS → DeviceCheck.
- Other release targets (web, macOS, Linux) → debug provider with a `debugPrint` warning. The non-launch fallback collapses into the same branch as `kDebugMode` so a release build on a non-mobile platform does not crash on missing attestation infrastructure.

`firebaseAiProvider` returns `FirebaseAI.googleAI()` — the Gemini Developer API backend. The SDK consumes Firebase Auth and App Check via `FirebaseApp.getService` internally, so the provider is one line and the call site does not have to thread either explicitly.

## Failure modes

- **Calls to Gemini return `PERMISSION_DENIED` in dev** — the device's debug token is not registered. Run the app, copy the printed debug token, register in the Firebase Console.
- **Calls to Gemini return `RESOURCE_EXHAUSTED`** — the project's daily Gemini quota or budget hit. Check Google Cloud → Quotas, or raise the budget alert.
- **App Check activation throws on app launch** — usually means a release build is running on a device that does not satisfy Play Integrity / DeviceCheck (e.g. unsigned APK, jailbroken device). For development, the debug provider applies in `kDebugMode`; for release smoke tests, ensure the app is signed and uploaded through the proper distribution channel.
- **`flutter pub get` complains about Firebase plugin platform mismatches** — usually the `firebase_core`, `firebase_ai`, and `firebase_app_check` versions need to align. Always pin the versions in `pubspec.yaml` and update them together when bumping.

## Rollback

The AI Logic enable is reversible from the same console screen. App Check enforcement on a per-API basis can be toggled in Console → App Check → APIs without removing the debug tokens. Reverting `lib/main.dart`'s `activateAppCheck()` call disables the client-side enforcement for the next release; this should only be a panic-button option since it removes the credit-protection guard.
