/// Smoke test for the #056 Firebase emulator scaffold.
///
/// Tagged `emulator` so the default `flutter test` sweep skips it.
/// Run via:
///
///     firebase emulators:exec --only firestore,auth \
///       --project connect-me-rules-test \
///       "flutter test --tags emulator"
///
/// This test exists only to prove the scaffold boots Firebase against
/// the emulator and round-trips a request. Real adapter coverage
/// lands in #057.
@Tags(['emulator'])
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'firebase_test_setup.dart';

void main() {
  setUpAll(setUpEmulators);
  // Per-test wipe so order doesn't matter. Pattern future #057/#058/#059
  // tests should follow.
  tearDown(tearDownEmulators);

  test('anonymous sign-in against the auth emulator succeeds', () async {
    final cred = await FirebaseAuth.instance.signInAnonymously();
    expect(cred.user, isNotNull);
    expect(FirebaseAuth.instance.currentUser, isNotNull);
  });
}
