import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/connections/event_providers.dart';
import 'package:connect_me/src/state/connections/event_store.dart';
import 'package:connect_me/src/state/connections/in_memory_event_store.dart';
import 'package:connect_me/src/state/firebase_providers.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the auth-aware [eventStoreProvider] (Pass 4.5 #068).
/// Mirrors `connection_provider_test.dart` and
/// `interaction_provider_test.dart` shape.
void main() {
  PlannerEvent makeEvent(String id) {
    return PlannerEvent(
      id: id,
      title: id,
      category: 'general',
      date: DateTime.utc(2026, 5, 26),
      note: '',
    );
  }

  group('eventStoreProvider — signed out', () {
    test('returns a sentinel whose async surface throws StateError', () async {
      final container = ProviderContainer(
        overrides: [firebaseAuthProvider.overrideWithValue(MockFirebaseAuth())],
      );
      addTearDown(container.dispose);

      final store = container.read(eventStoreProvider);

      await expectLater(store.load('e1'), throwsA(isA<StateError>()));
      await expectLater(
        store.save(makeEvent('e1')),
        throwsA(isA<StateError>()),
      );
      await expectLater(store.delete('e1'), throwsA(isA<StateError>()));
      await expectLater(store.listAll(), throwsA(isA<StateError>()));
    });

    test(
      'snapshot stream emits an empty map and completes — does not throw',
      () async {
        final container = ProviderContainer(
          overrides: [
            firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
          ],
        );
        addTearDown(container.dispose);

        final store = container.read(eventStoreProvider);

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

        final store = container.read(eventStoreProvider);
        expect(store.snapshotSync(), isEmpty);
      },
    );
  });

  group('eventStoreProvider — signed in', () {
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
        expect(user, isNotNull);
        expect(user!.uid, 'user-a');
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

      expect(container.read(currentUserProvider)?.uid, 'user-a');

      final authB = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-b', isAnonymous: false),
      );
      container.updateOverrides([
        firebaseAuthProvider.overrideWithValue(authB),
      ]);
      expect(container.read(currentUserProvider)?.uid, 'user-b');
    });

    test('currentUserProvider goes null on auth swap to a signed-out '
        'mock; eventStoreProvider falls back to the sentinel', () async {
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
      expect(container.read(currentUserProvider), isNull);

      final store = container.read(eventStoreProvider);
      await expectLater(store.load('e1'), throwsA(isA<StateError>()));
    });
  });

  group('eventStoreProvider — direct override (existing test pattern)', () {
    test(
      'an eventStoreProvider override wins over the auth-aware default',
      () async {
        final injected = InMemoryEventStore();
        final container = ProviderContainer(
          overrides: [eventStoreProvider.overrideWithValue(injected)],
        );
        addTearDown(container.dispose);

        final store = container.read(eventStoreProvider);
        expect(store, same(injected));
      },
    );

    test(
      'override-driven swap re-resolves the override after auth changes',
      () async {
        final storeA = InMemoryEventStore();
        await storeA.save(makeEvent('a-evt'));
        final storeB = InMemoryEventStore();
        await storeB.save(makeEvent('b-evt'));

        final container = ProviderContainer(
          overrides: [
            firebaseAuthProvider.overrideWithValue(
              MockFirebaseAuth(
                signedIn: true,
                mockUser: MockUser(uid: 'user-a', isAnonymous: false),
              ),
            ),
            eventStoreProvider.overrideWithValue(storeA),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(eventStoreProvider), same(storeA));
        expect(
          await container.read(eventStoreProvider).listAll(),
          contains('a-evt'),
        );

        container.updateOverrides([
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(
              signedIn: true,
              mockUser: MockUser(uid: 'user-b', isAnonymous: false),
            ),
          ),
          eventStoreProvider.overrideWithValue(storeB),
        ]);
        expect(container.read(eventStoreProvider), same(storeB));
        expect(
          await container.read(eventStoreProvider).listAll(),
          contains('b-evt'),
        );
      },
    );
  });

  group('EventStore — interface contract through provider', () {
    test('eventStoreProvider returns an EventStore', () {
      final container = ProviderContainer(
        overrides: [firebaseAuthProvider.overrideWithValue(MockFirebaseAuth())],
      );
      addTearDown(container.dispose);

      final store = container.read(eventStoreProvider);
      expect(store, isA<EventStore>());
    });
  });
}
