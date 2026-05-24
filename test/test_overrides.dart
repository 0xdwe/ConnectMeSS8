import 'package:connect_me/src/state/firebase_providers.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Standard signed-in [firebaseAuthProvider] override for headless
/// `flutter test` (Pass 4.2 #058).
///
/// Pass 4.2 made `memoryStoreProvider`, `memorySeedingProvider`, and
/// any provider that reaches through them auth-aware. Tests that
/// don't care about authentication still need a signed-in identity
/// available, otherwise they hit `FirebaseAuth.instance` (no
/// `Firebase.initializeApp` in headless tests). This helper returns
/// the conventional override for "anything signed in is fine."
///
/// Usage:
/// ```
/// ProviderContainer(overrides: [
///   ...signedInDemoOverrides(),
///   memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
/// ]);
/// ```
///
/// The return type is `dynamic`-cast inferred via `<Object>[...]`
/// because Riverpod 3's `Override` type is not part of the
/// `flutter_riverpod` public surface; spreading the list into
/// `ProviderContainer(overrides: [...])` works either way and
/// avoids an extra import path.
List<dynamic> signedInDemoOverrides({String uid = 'demo-uid'}) {
  return <dynamic>[
    firebaseAuthProvider.overrideWithValue(
      MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(
          uid: uid,
          isAnonymous: false,
          email: 'demo@example.com',
          displayName: 'Demo',
        ),
      ),
    ),
  ];
}
