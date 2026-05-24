import 'package:cloud_firestore/cloud_firestore.dart';
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

/// Currently signed-in [User], or null when signed out
/// (Pass 4.2, #058).
///
/// Synchronous read of `firebaseAuthProvider.currentUser`. Subscribes
/// to `authStateChanges` once and invalidates itself on every event,
/// which causes `memoryStoreProvider` and any other watcher to
/// rebuild against the new user. Returning `User?` synchronously
/// keeps consumers free of `AsyncValue` plumbing — a UID is either
/// available right now or it isn't.
///
/// Swapping `firebaseAuthProvider`'s override (e.g. in tests with
/// `container.updateOverrides`) also rebuilds this provider, since
/// `firebaseAuthProvider` is a watched dep.
final currentUserProvider = Provider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final sub = auth.authStateChanges().listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return auth.currentUser;
});

