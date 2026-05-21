import 'package:firebase_auth/firebase_auth.dart';
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
