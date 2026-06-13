import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/connections/connection_providers.dart';
import 'package:connect_me/src/state/connections/connection_store.dart';
import 'package:connect_me/src/state/connections/in_memory_connection_store.dart';
import 'package:connect_me/src/state/firebase_providers.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the auth-aware `connectionStoreProvider` (Pass 4.5
/// #064 + #065).
///
/// Mirrors `test/state/memory/memory_store_provider_test.dart`
/// shape. Pure Dart provider-level tests; the Firestore SDK is not
/// touched here. The signed-in path's full type-guard
/// (`FirebaseConnectionStore`) is exercised by the integration test
/// at `integration_test/state/connections/firebase_connection_store_test.dart`,
/// because constructing a [FirebaseConnectionStore] reads
/// [firestoreProvider], which calls `FirebaseFirestore.instance`,
/// which requires `Firebase.initializeApp` \u2014 unavailable under
/// headless `flutter test`. The headless-testable invariant is that
/// the provider DEPS (currentUserProvider) reflect the auth state
/// and that overrides resolve correctly.
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
    test('returns a sentinel whose async surface throws StateError', () async {
      final container = ProviderContainer(
        overrides: [firebaseAuthProvider.overrideWithValue(MockFirebaseAuth())],
      );
      addTearDown(container.dispose);

      final store = container.read(connectionStoreProvider);

      await expectLater(store.load('sarah'), throwsA(isA<StateError>()));
      await expectLater(
        store.save(makeConnection('sarah')),
        throwsA(isA<StateError>()),
      );
      await expectLater(store.delete('sarah'), throwsA(isA<StateError>()));
      await expectLater(store.listAll(), throwsA(isA<StateError>()));
    });

    test(
      'snapshot stream emits an empty map and completes — does not throw',
      () async {
        // Widgets that watch the snapshot stream must not crash on
        // sign-out. Mirrors the _SignedOutMemoryStore shape called out
        // in #064 AC4.
        final container = ProviderContainer(
          overrides: [
            firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
          ],
        );
        addTearDown(container.dispose);

        final store = container.read(connectionStoreProvider);

        final events = await store.snapshot().toList();
        expect(events, hasLength(1));
        expect(events.single, isEmpty);
      },
    );

    test(
      'snapshotSync returns an empty map (not null) when signed out',
      () async {
        final container = ProviderContainer(
          overrides: [
            firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
          ],
        );
        addTearDown(container.dispose);

        final store = container.read(connectionStoreProvider);
        // Empty rather than null so a UI that reads the synchronous
        // mirror on a signed-out frame renders an empty state instead
        // of a loading skeleton forever.
        expect(store.snapshotSync(), isEmpty);
      },
    );
  });

  group('connectionStoreProvider — signed in', () {
    test(
      'currentUserProvider reflects the signed-in MockFirebaseAuth user',
      () async {
        final auth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'user-a', isAnonymous: false),
        );
        final container = ProviderContainer(
          overrides: [firebaseAuthProvider.overrideWithValue(auth)],
        );
        addTearDown(container.dispose);

        final user = container.read(currentUserProvider);
        expect(
          user,
          isNotNull,
          reason: 'currentUserProvider must surface the signed-in user.',
        );
        expect(user!.uid, 'user-a');

        // connectionStoreProvider intentionally is NOT exercised here:
        // building the FirebaseConnectionStore would read
        // firestoreProvider, which calls FirebaseFirestore.instance,
        // which requires Firebase.initializeApp \u2014 unavailable under
        // headless flutter test. The integration test covers the
        // type-guard ("signed-in returns FirebaseConnectionStore"). The
        // headless-testable invariant is that the provider DEPS
        // (currentUserProvider) reflect the auth state.
      },
    );

    test('currentUserProvider rebuilds when the user changes', () async {
      final authA = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-a', isAnonymous: false),
      );
      final container = ProviderContainer(
        overrides: [firebaseAuthProvider.overrideWithValue(authA)],
      );
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
      expect(
        userB?.uid,
        'user-b',
        reason:
            'currentUserProvider must rebuild when '
            'firebaseAuthProvider rebuilds.',
      );
    });

    test('currentUserProvider goes null on auth swap to a signed-out '
        'mock; connectionStoreProvider falls back to the sentinel', () async {
      final authA = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-a', isAnonymous: false),
      );
      final container = ProviderContainer(
        overrides: [firebaseAuthProvider.overrideWithValue(authA)],
      );
      addTearDown(container.dispose);

      expect(container.read(currentUserProvider)?.uid, 'user-a');

      container.updateOverrides([
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
      ]);
      expect(
        container.read(currentUserProvider),
        isNull,
        reason:
            'sign-out must take currentUserProvider back to null '
            'so connectionStoreProvider falls back to the sentinel.',
      );

      // Signed-out connectionStoreProvider does NOT read
      // firestoreProvider \u2014 the sentinel branch returns before that
      // watch \u2014 so we can verify the sentinel here without
      // overriding firestoreProvider.
      final store = container.read(connectionStoreProvider);
      await expectLater(
        store.load('sarah'),
        throwsA(isA<StateError>()),
        reason:
            'sign-out must replace the per-UID store with the '
            'signed-out sentinel.',
      );
    });
  });

  group(
    'connectionStoreProvider — direct override (existing test pattern)',
    () {
      test(
        'a connectionStoreProvider override wins over the auth-aware default',
        () async {
          // Explicit override path \u2014 this is what every widget test in
          // the repo already does for memoryStoreProvider. Establishes
          // that the new auth-aware logic does not break tests that
          // don't care about Firebase.
          final injected = InMemoryConnectionStore();
          final container = ProviderContainer(
            overrides: [connectionStoreProvider.overrideWithValue(injected)],
          );
          addTearDown(container.dispose);

          final store = container.read(connectionStoreProvider);
          expect(store, same(injected));
        },
      );

      test(
        'override-driven swap re-resolves the override after auth changes',
        () async {
          // Belt-and-braces complement: confirms that override-driven
          // test setups also see the new store after an auth swap. This
          // is the shape widget tests will use.
          final storeA = InMemoryConnectionStore();
          await storeA.save(makeConnection('sarah'));
          final storeB = InMemoryConnectionStore();
          await storeB.save(makeConnection('mike'));

          final container = ProviderContainer(
            overrides: [
              firebaseAuthProvider.overrideWithValue(
                MockFirebaseAuth(
                  signedIn: true,
                  mockUser: MockUser(uid: 'user-a', isAnonymous: false),
                ),
              ),
              connectionStoreProvider.overrideWithValue(storeA),
            ],
          );
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
        },
      );
    },
  );

  group('ConnectionStore — interface contract through provider', () {
    test('connectionStoreProvider returns a ConnectionStore', () {
      final container = ProviderContainer(
        overrides: [firebaseAuthProvider.overrideWithValue(MockFirebaseAuth())],
      );
      addTearDown(container.dispose);

      final store = container.read(connectionStoreProvider);
      expect(store, isA<ConnectionStore>());
    });
  });
}
