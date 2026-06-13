# Google Login Integration

Labels: feature, ready-for-agent, pass-4.7

## Parent

- PRD: N/A

## What to build

Integrate Google Sign-In with Firebase Authentication for iOS, macOS, and Android. This requires backend provisioning via `firebase.json`, client ID generation via `flutterfire configure`, custom URL schemes configuration in plist files, adding the `google_sign_in` package, implementing the UI button on `AuthScreen`, and updating the mock environment for widget tests.

## Acceptance criteria

- [ ] Add the `"auth"` configuration block to `firebase.json` containing `"googleSignIn"` with support email `jamesliyanto@gmail.com` and displayName `ConnectMe`.
- [ ] Add `google_sign_in: ^7.2.0` dependency to `pubspec.yaml`.
- [ ] Run `flutterfire configure` to generate updated `firebase_options.dart` containing iOS/macOS Client IDs.
- [ ] Add custom URL scheme (Reversed Client ID) to `ios/Runner/Info.plist` and `macos/Runner/Info.plist`.
- [ ] Add a premium "Continue with Google" button to both `_LoginForm` and `_SignupForm` in `lib/src/features/auth_screen.dart`.
- [ ] Implement the login flow utilizing `google_sign_in` package to fetch credentials, and authenticate with Firebase via `signInWithCredential`.
- [ ] Add mock Google sign-in support in widget tests to ensure the test suite is green and runs cleanly.
- [ ] Validate implementation with targeted tests.

## Blocked by

- None
