import 'package:connect_me/src/state/firebase_providers.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_overrides.dart';

/// Tests for the auth-aware `memoryStoreProvider` (Pass 4.2 #058).
///
/// These are pure Dart provider-shape tests. They do NOT exercise
/// the Firestore SDK — that lives behind the integration-test
/// substrate in `integration_test/`. A `FirebaseFirestore` is never
/// constructed here; tests assert behavior at the provider boundary
/// only. Constructing a `FirebaseMemoryStore` instance also requires
/// a `FirebaseFirestore`, which is why the signed-in cases override
/// `memoryStoreProvider` directly with a fake store and assert on
/// the surrounding rebuild behavior rather than the runtime type.
void main() {
  group('memoryStoreProvider — signed out', () {
    test(
        'returns a sentinel when firebaseAuthProvider has no signed-in user',
        () async {
      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
      ]);
      addTearDown(container.dispose);

      final store = container.read(memoryStoreProvider);

      // The sentinel is private; assert behaviour rather than type.
      await expectLater(
        store.load('sarah'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        store.save(MemoryDocument(
          contactId: 'sarah',
          displayName: 'Sarah',
          lastUpdated: DateTime.utc(2026, 5, 24),
        )),
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
  });

  group('memoryStoreProvider — signed in', () {
    test('currentUserProvider reflects the signed-in MockFirebaseAuth user',
        () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-a', isAnonymous: false),
      );
      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(auth),
      ]);
      addTearDown(container.dispose);

      final user = container.read(currentUserProvider);
      expect(user, isNotNull,
          reason: 'currentUserProvider must surface the signed-in user.');
      expect(user!.uid, 'user-a');

      // memoryStoreProvider intentionally is NOT exercised here:
      // building the FirebaseMemoryStore would read firestoreProvider,
      // which calls FirebaseFirestore.instance, which requires
      // Firebase.initializeApp — unavailable under headless
      // flutter test. The integration test covers that path. The
      // headless-testable invariant is that the provider DEPS
      // (currentUserProvider) reflect the auth state.
    });

    test('currentUserProvider rebuilds when the user changes', () async {
      final authA = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-a', isAnonymous: false),
      );
      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(authA),
      ]);
      addTearDown(container.dispose);

      final userA = container.read(currentUserProvider);
      expect(userA?.uid, 'user-a');

      final authB = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-b', isAnonymous: false),
      );
      container.updateOverrides([
        firebaseAuthProvider.overrideWithValue(authB),
      ]);
      final userB = container.read(currentUserProvider);
      expect(userB?.uid, 'user-b',
          reason: 'currentUserProvider must rebuild when '
              'firebaseAuthProvider rebuilds.');
    });

    test('currentUserProvider goes null on auth swap to a signed-out mock',
        () async {
      final authA = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-a', isAnonymous: false),
      );
      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(authA),
      ]);
      addTearDown(container.dispose);

      expect(container.read(currentUserProvider)?.uid, 'user-a');

      container.updateOverrides([
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
      ]);
      expect(container.read(currentUserProvider), isNull,
          reason: 'sign-out must take currentUserProvider back to null '
              'so memoryStoreProvider falls back to the sentinel.');

      // Signed-out memoryStoreProvider does NOT read firestoreProvider
      // — the sentinel branch returns before that watch — so we can
      // verify the sentinel here without overriding firestoreProvider.
      final store = container.read(memoryStoreProvider);
      await expectLater(
        store.load('sarah'),
        throwsA(isA<StateError>()),
        reason: 'sign-out must replace the per-UID store with the '
            'signed-out sentinel.',
      );
    });
  });

  group('memoryStoreProvider — direct override (existing test pattern)', () {
    test(
        'a memoryStoreProvider override wins over the auth-aware default',
        () async {
      // Explicit override path — this is what every widget test in
      // the repo already does. Establishes that the new auth-aware
      // logic does not break tests that don't care about Firebase.
      final injected = InMemoryMemoryStore();
      final container = ProviderContainer(overrides: [
        memoryStoreProvider.overrideWithValue(injected),
      ]);
      addTearDown(container.dispose);

      final store = container.read(memoryStoreProvider);
      expect(store, same(injected));
    });
  });

  group('memoryProvider invalidation on auth change', () {
    test(
        'memoryProvider rebuilds when memoryStoreProvider rebuilds via auth',
        () async {
      // Two distinct stores keyed for two users; assert
      // memoryProvider's resolved doc swaps when the auth user
      // (and therefore the active store) changes. We override
      // memoryStoreProvider directly per-user — the auth-aware
      // default needs Firestore, which the headless test can't
      // load — but the rebuild edge that matters is
      // memoryStoreProvider's identity changing, not specifically
      // its Firestore-vs-InMemory shape.
      final storeA = InMemoryMemoryStore();
      await storeA.save(MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah from A',
        lastUpdated: DateTime.utc(2026, 5, 24),
        summary: 'Account A note',
      ));
      final storeB = InMemoryMemoryStore();
      await storeB.save(MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah from B',
        lastUpdated: DateTime.utc(2026, 5, 24),
        summary: 'Account B note',
      ));

      final container = ProviderContainer(overrides: [
        ...signedInDemoOverrides(),
        memoryStoreProvider.overrideWithValue(storeA),
      ]);
      addTearDown(container.dispose);

      final docA = await container.read(memoryProvider('sarah').future);
      expect(docA.summary, 'Account A note');

      container.updateOverrides([
        ...signedInDemoOverrides(),
        memoryStoreProvider.overrideWithValue(storeB),
      ]);
      // memoryProvider is auto-disposed and rebuilds on next read.
      final docB = await container.read(memoryProvider('sarah').future);
      expect(docB.summary, 'Account B note',
          reason: 'memoryProvider must read through the new store '
              'after a memoryStoreProvider rebuild.');
    });
  });
}
