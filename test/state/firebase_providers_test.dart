import 'dart:async';

import 'package:connect_me/src/state/firebase_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for `currentUserProvider`'s subscription discipline.
///
/// `firebase_auth_mocks` does not replay the current state on
/// `authStateChanges()` subscribe. Real `FirebaseAuth.instance` does.
/// That difference is the entire reason the white-screen bug only
/// surfaced on the iPhone simulator and not in the headless test
/// sweep. These tests use a custom fake that DOES replay on
/// subscribe so we exercise the production stream contract from a
/// pure-Dart test.
void main() {
  group('currentUserProvider — production stream contract', () {
    test(
        'does not rebuild infinitely when authStateChanges replays '
        'current user on subscribe', () async {
      // Real FirebaseAuth emits the current user immediately to every
      // new authStateChanges subscriber. Riverpod will recreate the
      // provider on every invalidateSelf, which recreates the
      // subscription, which replays the user, which fires the
      // invalidate listener again — a tight microtask-driven loop
      // that never settles. memorySeedingProvider watches
      // currentUserProvider, so this loop holds the seeding splash
      // forever (the white screen).
      //
      // Riverpod dedupes Provider<T> output by equality, so a
      // listener wouldn't see repeated rebuilds when User? stays
      // null. The faithful symptom is the side-effect counter:
      // each rebuild creates a fresh authStateChanges() subscription.
      // That's what the loop actually does, and that's what we
      // measure here.
      final auth = _ReplayingFakeAuth(currentUser: null);
      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(auth),
      ]);
      addTearDown(container.dispose);

      // Keep the provider alive so it actually rebuilds on invalidate.
      container.listen(currentUserProvider, (_, __) {});

      // Let the microtask queue drain. A loop will rack up
      // hundreds of subscribe calls in this window.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        auth.subscribeCount,
        lessThan(5),
        reason:
            'currentUserProvider must not loop on stream subscribe replay. '
            'Saw ${auth.subscribeCount} authStateChanges() subscriptions in '
            '100ms — production Firebase replays the current user on every '
            'subscribe, so any nontrivial count here means each replay is '
            'invalidating the provider, which resubscribes, which replays, '
            '...',
      );
    });

    test(
        'still picks up genuine auth state transitions after subscribe',
        () async {
      // The fix must not regress the real reason the listen exists:
      // when the user signs in or out, currentUserProvider has to
      // rebuild so memoryStoreProvider swaps to the right store.
      final controller = StreamController<User?>.broadcast();
      final auth = _StreamBackedFakeAuth(
        currentUser: null,
        stream: controller.stream,
      );
      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(auth),
      ]);
      addTearDown(() {
        controller.close();
        container.dispose();
      });

      // Initial read — no user.
      expect(container.read(currentUserProvider), isNull);

      // Simulate sign-in: update what currentUser returns AND emit on
      // the stream. Real FirebaseAuth flips both atomically.
      final signedIn = MockUser(uid: 'user-a', isAnonymous: false);
      auth.currentUserOverride = signedIn;
      controller.add(signedIn);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        container.read(currentUserProvider)?.uid,
        'user-a',
        reason:
            'A real auth state change must still rebuild '
            'currentUserProvider. The fix must preserve this behavior.',
      );
    });
  });

  group('activateAppCheck — prototype no-op gate', () {
    test(
        'is a no-op when kAppCheckEnforcementEnabled is false so a '
        'headless test environment does not need Firebase.initializeApp',
        () async {
      // PRD §Q3 / Path B (2026-05-30): for prototype scope we leave
      // App Check enforcement OFF and short-circuit activateAppCheck
      // before it touches the SDK. Without the gate, calling
      // activateAppCheck in a headless test would throw because
      // FirebaseAppCheck.instance reaches for FirebaseApp.instance,
      // which has no [DEFAULT] app initialized.
      //
      // Asserting the constant is false pins the prototype-scope
      // default; flipping it to true at launch is a one-line edit.
      // The function-completes-without-throw assertion proves the
      // short-circuit actually fires.
      expect(
        kAppCheckEnforcementEnabled,
        isFalse,
        reason:
            'Prototype scope keeps App Check enforcement OFF per '
            'PRD §Q3 / Path B. Flip to true at launch when registering '
            'a real attestation provider in the Firebase console.',
      );
      await activateAppCheck();
    });
  });
}

/// Test double for `FirebaseAuth` that replays `currentUser` on
/// every `authStateChanges` subscribe — matching real Firebase.
class _ReplayingFakeAuth extends MockFirebaseAuth {
  _ReplayingFakeAuth({User? currentUser})
      : _currentUser = currentUser,
        super(
          signedIn: currentUser != null,
          mockUser: currentUser is MockUser ? currentUser : null,
        );

  final User? _currentUser;
  int subscribeCount = 0;

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> authStateChanges() {
    final c = StreamController<User?>();
    c.onListen = () {
      subscribeCount++;
      // Replay current state on subscribe — this is the production
      // Firebase contract that firebase_auth_mocks does not replicate.
      c.add(_currentUser);
    };
    return c.stream;
  }
}

/// Test double driven by an external stream so the test can fire
/// genuine auth transitions on demand.
class _StreamBackedFakeAuth extends MockFirebaseAuth {
  _StreamBackedFakeAuth({User? currentUser, required Stream<User?> stream})
      : currentUserOverride = currentUser,
        _stream = stream,
        super(signedIn: false);

  User? currentUserOverride;
  final Stream<User?> _stream;

  @override
  User? get currentUser => currentUserOverride;

  @override
  Stream<User?> authStateChanges() {
    final c = StreamController<User?>();
    StreamSubscription<User?>? sub;
    c.onListen = () {
      // Replay-on-subscribe like the real SDK.
      c.add(currentUserOverride);
      sub = _stream.listen(c.add);
    };
    c.onCancel = () => sub?.cancel();
    return c.stream;
  }
}
