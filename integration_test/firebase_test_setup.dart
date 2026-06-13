/// Firebase emulator test scaffold (Pass 4.2, #056 + #057).
///
/// Shared helpers that initialize Firebase against the local Firestore
/// and Auth emulators so adapter, migration, and provider tests can
/// exercise the real Firebase SDK without talking to the production
/// `connect-me-e20b1` project.
///
/// **Why this lives under `integration_test/` and not `test/`.**
/// `flutter test` runs in a headless Dart VM that cannot load
/// `firebase_core`'s native plugin channels — `Firebase.initializeApp`
/// throws `channel-error` immediately. The `integration_test` package
/// boots a real Flutter engine on a device target, which is what the
/// Firebase SDK needs. Default `flutter test` therefore does not run
/// any of these tests; physical location under `integration_test/`
/// gates them, no `--tags` workaround needed.
///
/// Canonical invocation (from repo root):
///
///     firebase emulators:exec --only firestore,auth \
///       --project connect-me-rules-test \
///       "flutter test integration_test -d macos"
///
/// macOS desktop is the cheapest engine to boot. iOS simulator,
/// Android emulator, and Chrome are alternatives — pick what
/// `flutter devices` reports.
///
/// Non-goals:
///
///   * Widget tests should keep overriding `memoryStoreProvider` with
///     `InMemoryMemoryStore`. Booting Firebase per widget test would
///     make the suite slow and flaky for no benefit — the contract
///     they exercise is the `MemoryStore` interface, not Firestore.
///   * This scaffold does NOT replace `firebase_auth_mocks`. Tests
///     that only need a fake authed user should keep using
///     `MockFirebaseAuth` via `firebaseAuthProvider`.
///
/// Project ID convention: `connect-me-rules-test`. The same id is used
/// by the JS rules tests in `firestore/rules.test.js` so all emulator
/// usage in this repo points at one isolated namespace, separate from
/// the production project.
library;

import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Project ID used by every emulator-backed Dart test in this repo.
/// Matches the JS rules-test project so a single emulator instance
/// can host both suites.
const String emulatorProjectId = 'connect-me-rules-test';

/// Firestore emulator host/port. Matches `firebase.json`.
const String _firestoreHost = 'localhost';
const int _firestorePort = 8080;

/// Auth emulator host/port. Matches `firebase.json`.
const String _authHost = 'localhost';
const int _authPort = 9099;

bool _initialized = false;

/// Initialize Firebase against the local emulators.
///
/// Idempotent — safe to call from many `setUp`s in a single process.
/// First call boots the SDK and routes Firestore + Auth at the
/// emulator. Later calls short-circuit.
///
/// Tests that call this helper live under `integration_test/` so the
/// default `flutter test` sweep skips them.
Future<void> setUpEmulators() async {
  if (_initialized) return;

  // Minimal stand-in `FirebaseOptions` tied to the test project ID.
  // Real API keys/app IDs are not required because every request is
  // routed at `localhost`; the SDK only needs `projectId` to form
  // emulator URLs correctly.
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'fake-api-key-for-emulator',
        appId: '1:0000000000:web:0000000000000000',
        messagingSenderId: '0000000000',
        projectId: emulatorProjectId,
      ),
    );
  } on FirebaseException catch (e) {
    // `[core/duplicate-app]` — already initialized in this process.
    // Tolerated so test files that boot Firebase themselves still
    // work alongside this helper.
    if (e.code != 'duplicate-app') rethrow;
  }

  FirebaseFirestore.instance.useFirestoreEmulator(
    _firestoreHost,
    _firestorePort,
  );
  await FirebaseAuth.instance.useAuthEmulator(_authHost, _authPort);

  _initialized = true;
}

/// Wipe all Firestore data in the emulator's `(default)` database.
///
/// Useful between tests so order doesn't matter. Uses the emulator's
/// REST endpoint so the wipe is server-side and synchronous.
///
/// Uses `dart:io` `HttpClient` instead of pulling `package:http` into
/// `dev_dependencies` — the request is a single unauthenticated
/// DELETE, so the standard library is enough.
Future<void> clearFirestoreEmulator() async {
  final uri = Uri.parse(
    'http://$_firestoreHost:$_firestorePort'
    '/emulator/v1/projects/$emulatorProjectId'
    '/databases/(default)/documents',
  );
  final client = HttpClient();
  try {
    final req = await client.deleteUrl(uri);
    final res = await req.close();
    // Drain so the connection releases. We only care about success
    // shape; the emulator returns 200 with an empty body.
    await res.drain<void>();
    if (res.statusCode != HttpStatus.ok) {
      throw StateError(
        'Firestore emulator wipe failed: HTTP ${res.statusCode}',
      );
    }
  } finally {
    client.close(force: true);
  }
}

/// Wipe all Auth users in the emulator.
///
/// Companion to [clearFirestoreEmulator] for tests that exercise the
/// auth-aware provider rebuild in #058.
Future<void> clearAuthEmulator() async {
  final uri = Uri.parse(
    'http://$_authHost:$_authPort'
    '/emulator/v1/projects/$emulatorProjectId/accounts',
  );
  final client = HttpClient();
  try {
    final req = await client.deleteUrl(uri);
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer owner');
    final res = await req.close();
    await res.drain<void>();
    if (res.statusCode != HttpStatus.ok) {
      throw StateError('Auth emulator wipe failed: HTTP ${res.statusCode}');
    }
  } finally {
    client.close(force: true);
  }
}

/// Convenience: clear both emulators and the SDK's local state.
/// Call from `tearDown` (or `setUp`) in tests that mutate emulator
/// state so each test starts from a known-empty world.
///
/// Why three steps:
///   1. **Sign out.** `signInAnonymously` returns the *existing*
///      in-memory session if one is set, even after the auth
///      emulator wipe deleted the server-side user. Without an
///      explicit sign-out, the next test would reuse the previous
///      test's UID and hit the same Firestore path.
///   2. **Terminate + clearPersistence.** The Firestore SDK keeps a
///      local cache. The emulator REST wipe only deletes server-side
///      data; without clearing persistence, the SDK happily serves
///      stale cached docs to subsequent reads.
///   3. **Server-side wipe.** REST DELETE on both emulators.
///
/// After termination, `FirebaseFirestore.instance` is auto-recreated
/// the next time it's accessed. The emulator route established in
/// `setUpEmulators` does *not* survive the recreation, so we re-route
/// at the end.
Future<void> tearDownEmulators() async {
  try {
    await FirebaseAuth.instance.signOut();
  } catch (_) {
    // No-op: not signed in is fine.
  }
  try {
    await FirebaseFirestore.instance.terminate();
    await FirebaseFirestore.instance.clearPersistence();
  } on FirebaseException {
    // First-call / not-initialized edge cases are harmless.
  }
  await clearFirestoreEmulator();
  await clearAuthEmulator();
  FirebaseFirestore.instance.useFirestoreEmulator(
    _firestoreHost,
    _firestorePort,
  );
}
