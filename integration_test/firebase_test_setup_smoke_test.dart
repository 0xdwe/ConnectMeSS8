/// Smoke test for the Firebase emulator scaffold (Pass 4.2, #056 + #057).
///
/// Lives under `integration_test/` because `flutter test` runs in a
/// headless Dart VM that cannot load `firebase_core` plugin channels.
/// Run via:
///
///     firebase emulators:exec --only firestore,auth \
///       --project connect-me-rules-test \
///       "flutter test integration_test -d macos"
///
/// This test exists only to prove the scaffold boots Firebase against
/// the emulator and round-trips an auth request. Real adapter
/// coverage lives alongside in `state/memory/firebase_memory_store_test.dart`.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'firebase_test_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(setUpEmulators);
  // Per-test wipe so order doesn't matter. Pattern future #058/#059
  // tests should follow.
  tearDown(tearDownEmulators);

  testWidgets('anonymous sign-in against the auth emulator succeeds',
      (tester) async {
    final cred = await FirebaseAuth.instance.signInAnonymously();
    expect(cred.user, isNotNull);
    expect(FirebaseAuth.instance.currentUser, isNotNull);
  });
}
