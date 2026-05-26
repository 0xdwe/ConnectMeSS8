import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/connections/in_memory_interaction_store.dart';
import 'package:connect_me/src/state/connections/interaction_providers.dart';
import 'package:connect_me/src/state/connections/interaction_store.dart';
import 'package:connect_me/src/state/firebase_providers.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the auth-aware [interactionStoreProvider] (Pass 4.5
/// #067). Mirrors `connection_provider_test.dart` shape from
/// #064 / #065.
///
/// Pure Dart provider-level tests; the Firestore SDK is not touched
/// here. The signed-in path's full type-guard
/// ([FirebaseInteractionStore]) is exercised under the emulator
/// (deferred to #073). The headless-testable invariant is that the
/// provider DEPS (currentUserProvider) reflect the auth state and
/// that overrides resolve correctly.
void main() {
  CrmInteraction makeInteraction(String id) {
    return CrmInteraction(
      id: id,
      contactId: 'sarah',
      type: InteractionType.interaction,
      title: id,
      note: '',
      date: DateTime.utc(2026, 5, 26),
    );
  }

  group('interactionStoreProvider — signed out', () {
    test('returns a sentinel whose async surface throws StateError',
        () async {
      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
      ]);
      addTearDown(container.dispose);

      final store = container.read(interactionStoreProvider);

      await expectLater(
        store.load('i1'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        store.save(makeInteraction('i1')),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        store.delete('i1'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        store.listAll(),
        throwsA(isA<StateError>()),
      );
    });

    test('snapshot stream emits an empty map and completes — does not throw',
        () async {
      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
      ]);
      addTearDown(container.dispose);

      final store = container.read(interactionStoreProvider);

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

      final store = container.read(interactionStoreProvider);
      expect(store.snapshotSync(), isEmpty);
    });
  });

  group('interactionStoreProvider — signed in', () {
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

      expect(container.read(currentUserProvider)?.uid, 'user-a');

      final authB = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-b', isAnonymous: false),
      );
      container.updateOverrides([
        firebaseAuthProvider.overrideWithValue(authB),
      ]);
      expect(container.read(currentUserProvider)?.uid, 'user-b',
          reason: 'currentUserProvider must rebuild when '
              'firebaseAuthProvider rebuilds.');
    });

    test(
        'currentUserProvider goes null on auth swap to a signed-out '
        'mock; interactionStoreProvider falls back to the sentinel',
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
              'so interactionStoreProvider falls back to the sentinel.');

      final store = container.read(interactionStoreProvider);
      await expectLater(
        store.load('i1'),
        throwsA(isA<StateError>()),
        reason: 'sign-out must replace the per-UID store with the '
            'signed-out sentinel.',
      );
    });
  });

  group('interactionStoreProvider — direct override (existing test pattern)',
      () {
    test(
        'an interactionStoreProvider override wins over the auth-aware default',
        () async {
      final injected = InMemoryInteractionStore();
      final container = ProviderContainer(overrides: [
        interactionStoreProvider.overrideWithValue(injected),
      ]);
      addTearDown(container.dispose);

      final store = container.read(interactionStoreProvider);
      expect(store, same(injected));
    });

    test(
        'override-driven swap re-resolves the override after auth changes',
        () async {
      final storeA = InMemoryInteractionStore();
      await storeA.save(makeInteraction('a-int'));
      final storeB = InMemoryInteractionStore();
      await storeB.save(makeInteraction('b-int'));

      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(
          MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'user-a', isAnonymous: false),
          ),
        ),
        interactionStoreProvider.overrideWithValue(storeA),
      ]);
      addTearDown(container.dispose);

      expect(container.read(interactionStoreProvider), same(storeA));
      expect(
        await container.read(interactionStoreProvider).listAll(),
        contains('a-int'),
      );

      container.updateOverrides([
        firebaseAuthProvider.overrideWithValue(
          MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'user-b', isAnonymous: false),
          ),
        ),
        interactionStoreProvider.overrideWithValue(storeB),
      ]);
      expect(container.read(interactionStoreProvider), same(storeB));
      expect(
        await container.read(interactionStoreProvider).listAll(),
        contains('b-int'),
      );
    });
  });

  group('InteractionStore — interface contract through provider', () {
    test('interactionStoreProvider returns an InteractionStore', () {
      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
      ]);
      addTearDown(container.dispose);

      final store = container.read(interactionStoreProvider);
      expect(store, isA<InteractionStore>());
    });
  });
}
