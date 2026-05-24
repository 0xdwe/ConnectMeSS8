/// Firebase emulator test scaffold (Pass 4.2, #056).
///
/// Shared helpers that initialize Firebase against the local Firestore
/// and Auth emulators so adapter, migration, and provider tests can
/// exercise the real Firebase SDK without talking to the production
/// `connect-me-e20b1` project. Tests that use this helper must be
/// tagged `emulator` (see `dart_test.yaml`) so the default
/// `flutter test` sweep still runs offline and stays the 289-passing
/// baseline established at the end of Pass 3.
///
/// Canonical invocation (from repo root):
///
///     firebase emulators:exec --only firestore,auth \
///       --project connect-me-rules-test \
///       "flutter test --tags emulator"
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
/// Tests that call this helper must be tagged `emulator` so the
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
      throw StateError(
        'Auth emulator wipe failed: HTTP ${res.statusCode}',
      );
    }
  } finally {
    client.close(force: true);
  }
}

/// Convenience: clear both emulators. Call from `tearDown` in tests
/// that mutate emulator state.
Future<void> tearDownEmulators() async {
  await clearFirestoreEmulator();
  await clearAuthEmulator();
}
