import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/connections/connection_providers.dart';
import 'package:connect_me/src/state/connections/connection_store.dart';
import 'package:connect_me/src/state/connections/in_memory_connection_store.dart';
import 'package:connect_me/src/state/firebase_providers.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the auth-aware `connectionStoreProvider` (Pass 4.5 #064).
///
/// Mirrors `test/state/memory/memory_store_provider_test.dart` shape.
/// Pure Dart provider-level tests; the Firestore SDK is not touched
/// here. The signed-in path is exercised via direct overrides
/// because constructing a `FirebaseConnectionStore` (#065) needs a
/// real `FirebaseFirestore`, which is unavailable under headless
/// `flutter test`.
void main() {
  Connection makeConnection(String id) {
    return Connection(
      id: id,
      name: id,
      email: '$id@example.com',
      category: 'Friends',
      avatar: id,
      bondScore: 50,
      nextStep: '',
      lastContact: DateTime.utc(2026, 5, 26),
      notes: '',
      knownSince: DateTime.utc(2024, 1, 1),
      preferredChannels: const ['email'],
    );
  }

  group('connectionStoreProvider — signed out', () {
    test('returns a sentinel whose async surface throws StateError',
        () async {
      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
      ]);
      addTearDown(container.dispose);

      final store = container.read(connectionStoreProvider);

      await expectLater(
        store.load('sarah'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        store.save(makeConnection('sarah')),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        store.delete('sarah'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        store.listAll(),
        throwsA(isA<StateError>()),
      );
    });

    test('snapshot stream emits an empty map and completes — does not throw',
        () async {
      // Widgets that watch the snapshot stream must not crash on
      // sign-out. Mirrors the _SignedOutMemoryStore shape called out
      // in #064 AC4.
      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
      ]);
      addTearDown(container.dispose);

      final store = container.read(connectionStoreProvider);

      final events = await store.snapshot().toList();
      expect(events, hasLength(1));
      expect(events.single, isEmpty);
    });

    test('snapshotSync returns an empty map (not null) when signed out',
        () async {
      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
      ]);
      addTearDown(container.dispose);

      final store = container.read(connectionStoreProvider);
      // Empty rather than null so a UI that reads the synchronous
      // mirror on a signed-out frame renders an empty state instead
      // of a loading skeleton forever.
      expect(store.snapshotSync(), isEmpty);
    });
  });

  group('connectionStoreProvider — signed in (default path)', () {
    test('signed-in default path returns an InMemoryConnectionStore (pre-#065)',
        () async {
      // Regression guard for #064 AC bullet 7 "signed-in returns the
      // in-memory store" via the auth-aware default branch (not via
      // an override). #065 will swap the default branch to
      // FirebaseConnectionStore, at which point this test updates to
      // assert the new type.
      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(
          MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'user-a', isAnonymous: false),
          ),
        ),
      ]);
      addTearDown(container.dispose);

      final store = container.read(connectionStoreProvider);
      expect(store, isA<InMemoryConnectionStore>());
    });

    test('a connectionStoreProvider override wins over the auth-aware default',
        () async {
      final injected = InMemoryConnectionStore();
      final container = ProviderContainer(overrides: [
        connectionStoreProvider.overrideWithValue(injected),
      ]);
      addTearDown(container.dispose);

      final store = container.read(connectionStoreProvider);
      expect(store, same(injected));
    });
  });

  group('connectionStoreProvider — auth swap rebuilds store identity', () {
    test(
        'swap from signed-in user A to signed-in user B rebuilds via the '
        'auth-aware default path', () async {
      // The signed-in default branch constructs `InMemoryConnectionStore()`
      // with no Firestore touch (#064), so we can exercise the actual
      // rebuild edge here without overriding `connectionStoreProvider`.
      // After #065 swaps the default to `FirebaseConnectionStore`, this
      // test will need a Firestore-backed equivalent or will move to
      // `integration_test/`.
      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(
          MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'user-a', isAnonymous: false),
          ),
        ),
      ]);
      addTearDown(container.dispose);

      final storeA = container.read(connectionStoreProvider);
      expect(storeA, isA<InMemoryConnectionStore>());

      container.updateOverrides([
        firebaseAuthProvider.overrideWithValue(
          MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'user-b', isAnonymous: false),
          ),
        ),
      ]);
      final storeB = container.read(connectionStoreProvider);
      expect(storeB, isA<InMemoryConnectionStore>());
      expect(
        identical(storeA, storeB),
        isFalse,
        reason: 'auth swap must construct a new ConnectionStore identity '
            'via connectionStoreProvider.onDispose + rebuild.',
      );
    });

    test(
        'override-driven swap re-resolves the override after auth changes',
        () async {
      // Belt-and-braces complement to the default-path test above:
      // confirms that override-driven test setups also see the new
      // store after an auth swap. Mirrors the shape widget tests use.
      final storeA = InMemoryConnectionStore();
      await storeA.save(makeConnection('sarah'));
      final storeB = InMemoryConnectionStore();
      await storeB.save(makeConnection('mike'));

      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(
          MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'user-a', isAnonymous: false),
          ),
        ),
        connectionStoreProvider.overrideWithValue(storeA),
      ]);
      addTearDown(container.dispose);

      expect(container.read(connectionStoreProvider), same(storeA));
      expect(
        await container.read(connectionStoreProvider).listAll(),
        contains('sarah'),
      );

      container.updateOverrides([
        firebaseAuthProvider.overrideWithValue(
          MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'user-b', isAnonymous: false),
          ),
        ),
        connectionStoreProvider.overrideWithValue(storeB),
      ]);
      expect(container.read(connectionStoreProvider), same(storeB));
      expect(
        await container.read(connectionStoreProvider).listAll(),
        contains('mike'),
      );
    });

    test(
        'sign-out replaces a signed-in InMemoryConnectionStore with the '
        'signed-out sentinel', () async {
      // Reads while signed in (asserts non-sentinel + correct type),
      // then swaps auth to signed-out and asserts the sentinel is in
      // place AND the async surface throws. This is the actual
      // transition #064 AC names (signed-out throws / signed-in
      // returns the in-memory store / auth swap rebuilds).
      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(
          MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'user-a', isAnonymous: false),
          ),
        ),
      ]);
      addTearDown(container.dispose);

      final signedInStore = container.read(connectionStoreProvider);
      expect(signedInStore, isA<InMemoryConnectionStore>());
      // Sanity: signed-in store does not throw on the async surface.
      await expectLater(signedInStore.listAll(), completes);

      container.updateOverrides([
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
      ]);
      final signedOutStore = container.read(connectionStoreProvider);
      expect(
        signedOutStore,
        isNot(isA<InMemoryConnectionStore>()),
        reason: 'sign-out must swap to the signed-out sentinel, not '
            'leave the prior InMemoryConnectionStore in place.',
      );
      await expectLater(
        signedOutStore.load('sarah'),
        throwsA(isA<StateError>()),
        reason: 'sign-out must replace the per-UID store with the '
            'signed-out sentinel.',
      );
    });
  });

  group('ConnectionStore — interface contract through provider', () {
    test('connectionStoreProvider returns a ConnectionStore', () {
      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
      ]);
      addTearDown(container.dispose);

      final store = container.read(connectionStoreProvider);
      expect(store, isA<ConnectionStore>());
    });
  });
}
