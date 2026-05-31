import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
/// Active [FirebaseAuth] instance (Pass 4.1, #052).
///
/// Production resolves to `FirebaseAuth.instance`. Tests override
/// with a `MockFirebaseAuth` from `firebase_auth_mocks` so the
/// `AuthScreen`-driven flows can exercise sign-in / sign-up without
/// touching a real Firebase project. All consumers should read this
/// provider rather than `FirebaseAuth.instance` directly.
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

/// Active [FirebaseFirestore] instance (Pass 4.2, #058).
///
/// Production resolves to `FirebaseFirestore.instance`. Tests should
/// either override with an emulator-routed instance (in
/// `integration_test/`) or skip overriding entirely if they are also
/// overriding `memoryStoreProvider` directly. Isolating the SDK
/// reach behind this provider keeps future tests and migrations from
/// having to reach for `FirebaseFirestore.instance` directly.
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

/// Enables Firestore's local-disk persistent cache so writes issued
/// while offline are accepted into the cache and replicated to the
/// server once connectivity returns (Pass 4.2, #060 / PRD Q4).
///
/// Mobile platforms (iOS, Android) default to persistence enabled,
/// but macOS and other desktop targets do not. This call makes the
/// behavior explicit and uniform across every supported target so
/// the offline two-device smoke evidence holds on macOS as well as
/// on the simulators.
///
/// Must be called before any read or write on [firestore]; the
/// underlying SDK throws if `settings` is assigned after the first
/// use. Production calls this from `main()` immediately after
/// `Firebase.initializeApp` and before any provider can resolve
/// [firestoreProvider]. Extracted as a top-level function (rather
/// than inlined in `main.dart`) so the intent has a name and the
/// startup wiring stays one line.
void enableFirestoreOfflinePersistence(FirebaseFirestore firestore) {
  firestore.settings = const Settings(persistenceEnabled: true);
}

/// Master switch for App Check enforcement (Pass 4.3 / Path B,
/// 2026-05-30).
///
/// Prototype scope per ADR-0003 keeps this `false` so [activateAppCheck]
/// short-circuits before touching the SDK. With enforcement off,
/// AI Logic accepts requests without an attestation token and the
/// `firebase_app_check` plugin never tries to mint one — which
/// avoids the iOS-debug-token 403 ("App attestation failed")
/// observed against an unregistered iOS app.
///
/// Flip this to `true` at launch when:
///   1. Each launch-target app has been registered with a real
///      attestation provider in the Firebase console (App Attest /
///      DeviceCheck for iOS, Play Integrity for Android).
///   2. AI Logic enforcement has been turned ON in the Firebase
///      console for project `connect-me-e20b1`.
///
/// PRD §Q3 explicitly allows enforcement off for prototype scope:
/// "App Check is the right way to protect AI Logic. Defer
/// registration to launch; for prototype scope, AI Logic
/// enforcement stays OFF."
const bool kAppCheckEnforcementEnabled = false;

/// Activates Firebase App Check before any AI Logic call ships
/// (Pass 4.3, #077 / PRD Q3).
///
/// App Check protects Firebase AI Logic (and any future Cloud
/// Functions or Firestore reads scoped behind it) from being abused
/// by anyone with a leaked `firebase_options.dart`. Without it, the
/// 9,400 NTD prototype credit is not safe.
///
/// Provider matrix per PRD §Q3:
/// - debug builds (`kDebugMode`) — debug provider on every platform.
///   The first launch logs a debug token to the Flutter console; the
///   developer pastes it into Firebase Console → App Check → Manage
///   debug tokens. Tests do not call this function.
/// - release Android — Play Integrity.
/// - release iOS — DeviceCheck. App Attest is deferred (PRD §Q3).
/// - other release targets (web, macOS, Linux) — debug provider
///   with a console warning. None of those are launch targets per
///   ADR-0003 single-device prototype scope. Promoting any of them
///   requires registering a real attestation provider here AND in
///   the Firebase console.
///
/// Throws synchronously on activation failure — `main.dart`'s
/// `await` lets the failure surface at launch rather than letting
/// AI Logic ship without protection. Do not swallow the throw at
/// the call site; doing so silently disables the credit-protection
/// guard.
///
/// Must be called between `Firebase.initializeApp` and the first
/// `FirebaseAI` call. Mirrors [enableFirestoreOfflinePersistence]'s
/// boundary-function shape so `main.dart` stays one line per
/// concern.
Future<void> activateAppCheck() async {
  if (!kAppCheckEnforcementEnabled) {
    // Prototype-scope short-circuit (Path B, 2026-05-30). Skipping
    // FirebaseAppCheck.instance.activate() means the SDK never
    // attempts the debug-token exchange that 403s when the iOS
    // app is not registered in the Firebase console. AI Logic
    // calls go out without an attestation token; the project's
    // AI Logic enforcement is also OFF, so requests are accepted.
    // Flip [kAppCheckEnforcementEnabled] to true at launch.
    debugPrint(
      'App Check: prototype-scope no-op (kAppCheckEnforcementEnabled '
      'is false). Flip to true at launch.',
    );
    return;
  }

  // Treat "production attestation" as the launch matrix from ADR-0003:
  // signed Android + signed iOS only. Everything else (web, macOS,
  // Linux, debug) routes through the debug provider so a release
  // build on a non-launch target does not crash on missing
  // attestation infrastructure.
  final isMobileLaunchTarget = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  if (kDebugMode || !isMobileLaunchTarget) {
    if (!kDebugMode) {
      debugPrint(
        'App Check: non-mobile release target detected; using debug '
        'provider. Promote to a real attestation provider before '
        'shipping web/macOS/Linux as a launch target. See PRD §Q3.',
      );
    }
    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidDebugProvider(),
      providerApple: const AppleDebugProvider(),
      // 'debug' is not a valid reCAPTCHA v3 site key; reaching this
      // line on a real release web build will fail at runtime, which
      // is the intended outcome until web becomes a launch target
      // and a real key is registered.
      providerWeb: ReCaptchaV3Provider('debug'),
    );
    return;
  }
  await FirebaseAppCheck.instance.activate(
    providerAndroid: const AndroidPlayIntegrityProvider(),
    providerApple: const AppleDeviceCheckProvider(),
    providerWeb: ReCaptchaV3Provider('debug'),
  );
}

/// Active [FirebaseAI] handle (Pass 4.3, #077).
///
/// Production resolves to `FirebaseAI.googleAI()` — the Gemini
/// Developer API backend on Firebase AI Logic per PRD §Q1 §Q2.
/// Production callers should treat the value as non-null; the
/// nullable shape exists so headless tests (notably
/// `test/state/memory/ai_update_provider_test.dart`) can override
/// with `null` to construct an [LlmAiUpdate] without booting
/// Firebase. The adapter carries `firebaseAi` as nullable already,
/// and the failure-path tests in #080 already exercise the null
/// branch.
///
/// `googleAI()` consumes Firebase Auth and App Check via
/// `FirebaseApp.getService` internally, so the call site does not
/// have to thread either explicitly. The instance is cached per
/// app identity by the SDK, so re-reading this provider after an
/// auth swap is cheap.
final firebaseAiProvider = Provider<FirebaseAI?>(
  (ref) => FirebaseAI.googleAI(),
);

/// Currently signed-in [User], or null when signed out
/// (Pass 4.2, #058).
///
/// Synchronous read of `firebaseAuthProvider.currentUser`. Subscribes
/// to `authStateChanges` and invalidates itself when the UID actually
/// changes, which causes `memoryStoreProvider` and any other watcher
/// to rebuild against the new user. Returning `User?` synchronously
/// keeps consumers free of `AsyncValue` plumbing — a UID is either
/// available right now or it isn't.
///
/// Real `FirebaseAuth.instance.authStateChanges()` replays the
/// current user immediately on every new subscriber. Without the UID
/// guard below, a naive `listen((_) => ref.invalidateSelf())` would
/// loop: the provider rebuilds, subscribes, the stream replays the
/// current user, the listener invalidates the provider, the provider
/// rebuilds, etc. The seeding splash watches this provider, so that
/// loop holds the splash open forever (white screen at launch). The
/// guard skips the replay-on-subscribe and any redundant emission
/// where the UID is unchanged from the value the synchronous build
/// already returned.
///
/// Swapping `firebaseAuthProvider`'s override (e.g. in tests with
/// `container.updateOverrides`) also rebuilds this provider, since
/// `firebaseAuthProvider` is a watched dep.
final currentUserProvider = Provider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final initialUid = auth.currentUser?.uid;
  final sub = auth.authStateChanges().listen((user) {
    if (user?.uid != initialUid) ref.invalidateSelf();
  });
  ref.onDispose(sub.cancel);
  return auth.currentUser;
});

