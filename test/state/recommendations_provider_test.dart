import 'package:connect_me/src/ai/ai_update.dart';
import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/app_state.dart';
import 'package:connect_me/src/state/connections/batched_writes.dart';
import 'package:connect_me/src/state/connections/batched_writes_providers.dart';
import 'package:connect_me/src/state/connections/connection_providers.dart';
import 'package:connect_me/src/state/connections/event_providers.dart';
import 'package:connect_me/src/state/connections/in_memory_connection_store.dart';
import 'package:connect_me/src/state/connections/in_memory_event_store.dart';
import 'package:connect_me/src/state/connections/in_memory_interaction_store.dart';
import 'package:connect_me/src/state/connections/in_memory_user_doc_store.dart';
import 'package:connect_me/src/state/connections/interaction_providers.dart';
import 'package:connect_me/src/state/connections/user_doc_store_providers.dart';
import 'package:connect_me/src/state/firebase_providers.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test-callable wall clock. Implements `call` so the bare instance
/// can be passed where `DateTime Function()` is expected.
class _FakeClock {
  _FakeClock(this.now);
  DateTime now;
  DateTime call() => now;
}

class _CountingMemoryStore extends InMemoryMemoryStore {
  int listAllCalls = 0;

  @override
  Future<Map<String, MemoryDocument>> listAll() async {
    listAllCalls++;
    return super.listAll();
  }
}

class _FailingListAllMemoryStore extends InMemoryMemoryStore {
  @override
  Future<Map<String, MemoryDocument>> listAll() async {
    throw StateError('boom');
  }
}

MockFirebaseAuth _mockSignedInAuth() => MockFirebaseAuth(
  signedIn: true,
  mockUser: MockUser(
    isAnonymous: false,
    uid: 'rec-test-user',
    email: 'rec@example.com',
    displayName: 'Rec Test',
  ),
);

/// Pass 4.5 #070 — AppController now reads connection / interaction
/// / event / user-doc stores. Recommendations tests don't exercise
/// those collections directly, but the AppController's snapshot
/// listeners do, so we have to seed and override them or the
/// signed-in store providers fall back to real Firestore (which
/// fails without `Firebase.initializeApp`).
///
/// Returns the override list AND the InMemory stores pre-seeded
/// with the seeded fixture data, so reads of `state.connections /
/// interactions / events` see the same five seeded contacts the
/// pre-Pass-4.5 tests assumed.
class _SeededOverrides {
  _SeededOverrides({
    required this.overrides,
    required this.connectionStore,
    required this.interactionStore,
    required this.eventStore,
  });
  final List<dynamic> overrides;
  final InMemoryConnectionStore connectionStore;
  final InMemoryInteractionStore interactionStore;
  final InMemoryEventStore eventStore;
}

_SeededOverrides _seededPassFourFiveOverrides() {
  final connections = InMemoryConnectionStore();
  final interactions = InMemoryInteractionStore();
  final events = InMemoryEventStore();
  final userDoc = InMemoryUserDocStore();
  // Pre-seed: the production seeder writes these on first sign-in.
  // Tests that exercise the rec engine's behavior on the seeded
  // fixture need them present, otherwise the snapshot listener
  // replaces `state.connections` with [] on first emission.
  for (final c in AppState.seeded().connections) {
    connections.save(c);
  }
  for (final i in AppState.seeded().interactions) {
    interactions.save(i);
  }
  for (final e in AppState.seeded().events) {
    events.save(e);
  }
  final batched = InMemoryBatchedWrites(
    connectionStore: connections,
    interactionStore: interactions,
    eventStore: events,
  );
  return _SeededOverrides(
    overrides: <dynamic>[
      connectionStoreProvider.overrideWithValue(connections),
      interactionStoreProvider.overrideWithValue(interactions),
      eventStoreProvider.overrideWithValue(events),
      userDocStoreProvider.overrideWithValue(userDoc),
      batchedWritesProvider.overrideWithValue(batched),
    ],
    connectionStore: connections,
    interactionStore: interactions,
    eventStore: events,
  );
}

/// Pump the event loop a few times so the snapshot listeners in
/// AppController.build emit their initial seeded mirrors before the
/// test assertions run. Without this, `state.connections` may still
/// be the [AppState.seeded] initial value rather than the
/// store-driven mirror.
Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProviderContainer _container({_FakeClock? clock, InMemoryMemoryStore? store}) {
  final memoryStore = store ?? InMemoryMemoryStore();
  return ProviderContainer(
    overrides: [
      firebaseAuthProvider.overrideWithValue(_mockSignedInAuth()),
      memoryStoreProvider.overrideWithValue(memoryStore),
      ..._seededPassFourFiveOverrides().overrides,
      if (clock != null) clockProvider.overrideWithValue(clock.call),
      // Pass 4.3 #081: production aiUpdateProvider now constructs
      // LlmAiUpdate which would reach Firebase AI Logic. Pin Mock to
      // preserve the deterministic shape these tests assert on.
      aiUpdateProvider.overrideWith(
        (ref) => MockAiUpdate(
          memoryStore: memoryStore,
          appController: ref.read(appControllerProvider.notifier),
          onMemoryWritten: () {
            final c = ref.read(clockProvider);
            ref.read(memoryEpochProvider.notifier).bump(c());
          },
        ),
      ),
    ],
  );
}

void main() {
  group('recommendationsProvider', () {
    test('emits a list ranked per the engine on initial read', () async {
      final container = _container();
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      final recs = await container.read(recommendationsProvider.future);

      // Seeded AppState has 5 connections with varied recency. Top 3
      // by Q11 score get returned.
      expect(recs, hasLength(lessThanOrEqualTo(3)));
      expect(recs, isNotEmpty);
      // Every emitted contactId must reference a real seeded connection.
      final connectionIds = container
          .read(appControllerProvider)
          .connections
          .map((c) => c.id)
          .toSet();
      for (final rec in recs) {
        expect(connectionIds, contains(rec.contactId));
      }
    });

    test('rebuilds when state.connections changes', () async {
      final container = _container();
      addTearDown(container.dispose);

      // Pump so the seeded-store snapshot lands in state before we
      // capture the baseline rec list.
      container.read(appControllerProvider);
      await _settle();

      final before = await container.read(recommendationsProvider.future);

      await container
          .read(appControllerProvider.notifier)
          .addConnection(
            name: 'Drifting Dana',
            email: 'dana@test.com',
            category: 'Friends',
            notes: 'new contact',
          );
      await _settle();

      // The new contact has lastContact = now, so it's filtered by the
      // 24h cooldown. The provider still recomputes; result identity
      // changes even when content is similar because Provider returns a
      // fresh list per read.
      final after = await container.read(recommendationsProvider.future);
      expect(identical(before, after), isFalse);
    });

    test(
      "deleted contact's recommendation card is no longer present",
      () async {
        final container = _container();
        addTearDown(container.dispose);

        container.read(appControllerProvider);
        await _settle();

        // 'mike' is in the seeded fixture and lands in the top 3 because
        // he's drifting (bond 68 = steady actually) with a 39-day gap.
        // Verify he's present, then verify deletion drops him.
        final before = (await container.read(
          recommendationsProvider.future,
        )).map((r) => r.contactId).toList();
        expect(before, contains('mike'));

        await container
            .read(appControllerProvider.notifier)
            .deleteConnection('mike');
        await _settle();

        final after = (await container.read(
          recommendationsProvider.future,
        )).map((r) => r.contactId).toList();
        expect(after, isNot(contains('mike')));
      },
    );

    test(
      'returned recommendations carry deterministic priority strings',
      () async {
        final container = _container();
        addTearDown(container.dispose);
        container.read(appControllerProvider);
        await _settle();

        final recs = await container.read(recommendationsProvider.future);
        const allowedPriorities = {
          'high priority',
          'medium priority',
          'low priority',
        };
        for (final rec in recs) {
          expect(allowedPriorities, contains(rec.priority));
          expect(rec, isA<Recommendation>());
        }
      },
    );

    test('surfaces an upcoming card loaded from MemoryStore.listAll', () async {
      final store = InMemoryMemoryStore();
      await store.save(
        MemoryDocument.empty(
          contactId: 'mike',
          displayName: 'Mike Chen',
          now: DateTime(2026, 6, 1),
        ).copyWith(
          upcoming: [
            UpcomingEntry(
              startDate: DateTime(2026, 5, 29),
              endDate: DateTime(2026, 6, 1),
              description: 'Paris trip',
            ),
          ],
        ),
      );
      final container = _container(
        clock: _FakeClock(DateTime(2026, 6, 1, 12)),
        store: store,
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      final recs = await container.read(recommendationsProvider.future);

      expect(recs.first.contactId, 'mike');
      expect(recs.first.reason, "Wondering how Mike Chen's Paris trip went?");
    });

    test(
      'memory load failure falls back to recency-only recommendations',
      () async {
        final clock = _FakeClock(DateTime(2026, 6, 1, 12));
        final container = ProviderContainer(
          overrides: [
            firebaseAuthProvider.overrideWithValue(_mockSignedInAuth()),
            memoryStoreProvider.overrideWithValue(_FailingListAllMemoryStore()),
            ..._seededPassFourFiveOverrides().overrides,
            clockProvider.overrideWithValue(clock.call),
          ],
        );
        addTearDown(container.dispose);
        container.read(appControllerProvider);
        await _settle();

        final recs = await container.read(recommendationsProvider.future);

        expect(recs, isNotEmpty);
        expect(
          recs.map((r) => r.reason),
          isNot(contains("Wondering how Mike Chen's Paris trip went?")),
        );
      },
    );
  });

  // -------------------------------------------------------------------
  // PRD Q2 / #048 — dual invalidation cache.
  //
  // Cache is served when neither the memory-change signal nor the 6h
  // freshness window has fired. The freshness check runs on each
  // read — there is no background scheduler (PRD Q2). Tests use a
  // fake clock to drive the 6h boundary deterministically; see
  // `_FakeClock` above.
  // -------------------------------------------------------------------
  group('recommendationsProvider dual invalidation (PRD Q2)', () {
    test(
      'cache is served on a second read when no invalidation fires',
      () async {
        // Fake clock pinned at a time well after the seeded `lastContact`
        // values so the engine produces a non-empty list.
        final clock = _FakeClock(DateTime(2026, 6, 1, 12));
        final store = _CountingMemoryStore();
        final container = _container(clock: clock, store: store);
        addTearDown(container.dispose);
        container.read(appControllerProvider);
        await _settle();

        final first = await container.read(recommendationsProvider.future);
        final second = await container.read(recommendationsProvider.future);

        // Same list reference — the notifier returned the cached value
        // verbatim rather than recomputing.
        expect(identical(first, second), isTrue);
        expect(store.listAllCalls, 1);
      },
    );

    test('memory-change signal invalidates the cache on next read', () async {
      final clock = _FakeClock(DateTime(2026, 6, 1, 12));
      final store = _CountingMemoryStore();
      final container = _container(clock: clock, store: store);
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      final before = await container.read(recommendationsProvider.future);
      expect(store.listAllCalls, 1);

      // Bump the memory epoch to a moment after computedAt. This is
      // what `MockAiUpdate.commit` does after a successful save.
      container
          .read(memoryEpochProvider.notifier)
          .bump(clock.now.add(const Duration(seconds: 1)));

      final after = await container.read(recommendationsProvider.future);

      // Recompute happened — a fresh list reference comes back.
      expect(identical(before, after), isFalse);
      expect(store.listAllCalls, 2);
      // Content matches because the engine input did not change.
      expect(
        after.map((r) => r.contactId).toList(),
        before.map((r) => r.contactId).toList(),
      );
    });

    test('elapsed time > 6h invalidates the cache on next read', () async {
      final clock = _FakeClock(DateTime(2026, 6, 1, 12));
      final container = _container(clock: clock);
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      final before = await container.read(recommendationsProvider.future);

      // Advance the wall clock past the 6h freshness window, then
      // invalidate the FutureProvider to model the next provider
      // evaluation. That next evaluation should observe the stale
      // timestamp, bypass the cache, and recompute recommendations.
      clock.now = clock.now.add(
        recommendationsFreshness + const Duration(milliseconds: 1),
      );
      container.invalidate(recommendationsProvider);

      final after = await container.read(recommendationsProvider.future);
      expect(identical(before, after), isFalse);
    });

    test(
      'cache survives reads at exactly the 6h boundary minus one tick',
      () async {
        final clock = _FakeClock(DateTime(2026, 6, 1, 12));
        final container = _container(clock: clock);
        addTearDown(container.dispose);
        container.read(appControllerProvider);
        await _settle();

        final before = await container.read(recommendationsProvider.future);

        // Just inside the freshness window. Re-reading should not
        // recompute even after an explicit invalidate — build runs but
        // the cache check returns the prior list.
        clock.now = clock.now.add(
          recommendationsFreshness - const Duration(seconds: 1),
        );
        container.invalidate(recommendationsProvider);
        final after = await container.read(recommendationsProvider.future);

        expect(identical(before, after), isTrue);
      },
    );

    test('AI update commit bumps memoryEpoch which invalidates '
        'recommendations cache', () async {
      final store = InMemoryMemoryStore();
      final clock = _FakeClock(DateTime(2026, 6, 1, 12));
      final container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_mockSignedInAuth()),
          memoryStoreProvider.overrideWithValue(store),
          ..._seededPassFourFiveOverrides().overrides,
          clockProvider.overrideWithValue(clock.call),
          // Pass 4.3 #081: pin Mock as the active adapter; this test
          // asserts memoryEpoch bump from a successful commit, which
          // requires the onMemoryWritten hook to land.
          aiUpdateProvider.overrideWith(
            (ref) => MockAiUpdate(
              memoryStore: store,
              appController: ref.read(appControllerProvider.notifier),
              onMemoryWritten: () {
                final c = ref.read(clockProvider);
                ref.read(memoryEpochProvider.notifier).bump(c());
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen<AsyncValue<List<Recommendation>>>(
        recommendationsProvider,
        (_, _) {},
      );

      // Prime the cache.
      final before = await container.read(recommendationsProvider.future);

      // Run + commit a full AI update on a seeded contact.
      final mike = container
          .read(appControllerProvider)
          .connections
          .firstWhere((c) => c.id == 'mike');
      final memory = await container.read(memoryProvider('mike').future);
      final adapter = container.read(aiUpdateProvider);
      final result = await adapter.run(
        contact: mike,
        userInput: 'Caught up over coffee.',
        currentMemory: memory,
        attachments: const [],
      );
      // Advance the clock by one tick so the bumped epoch is strictly
      // after computedAt regardless of the freshness window.
      clock.now = clock.now.add(const Duration(seconds: 1));
      await adapter.commit(result);
      await _settle();

      // Reading the provider again must observe the epoch bump and
      // recompute. The state delta from `commit` also bumps
      // `lastContact`, so the recompute reflects the updated input.
      final after = await container.read(recommendationsProvider.future);
      subscription.close();
      expect(identical(before, after), isFalse);
    });

    test('cache does not survive a memoryStoreProvider swap '
        '(sign-out then sign-in-as-different-user) — #062', () async {
      // Two distinct stores, one per user. We override
      // memoryStoreProvider directly to model the production
      // scenario: an auth swap rebuilds memoryStoreProvider's
      // identity. AppController is intentionally NOT overridden, so
      // connections + interactions stay object-identical across the
      // swap — that's the exact case where the existing identity-
      // based cache check would happily serve user A's list to user B
      // if the provider didn't watch the store. Identity is the right
      // invariant: content may be coincidentally equal because the
      // engine input did not change; we're asserting the notifier
      // recomputed rather than served the cached list.
      final storeA = InMemoryMemoryStore();
      final storeB = InMemoryMemoryStore();
      var activeStore = storeA;
      final container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_mockSignedInAuth()),
          memoryStoreProvider.overrideWith((_) => activeStore),
          ..._seededPassFourFiveOverrides().overrides,
          // Pass 4.3 #081: pin Mock; this test doesn't read the
          // adapter directly but a future provider walk could touch
          // it via aiUpdateProvider construction.
          aiUpdateProvider.overrideWith(
            (ref) => MockAiUpdate(
              memoryStore: ref.watch(memoryStoreProvider),
              appController: ref.read(appControllerProvider.notifier),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(appControllerProvider);
      await _settle();
      final listA = await container.read(recommendationsProvider.future);

      activeStore = storeB;
      container.invalidate(memoryStoreProvider);
      container.invalidate(recommendationsProvider);
      await _settle();
      final listB = await container.read(recommendationsProvider.future);

      expect(
        identical(listA, listB),
        isFalse,
        reason:
            'recommendationsProvider must rebuild when '
            'memoryStoreProvider rebuilds (auth user swap), so the '
            "previous user's cached list is not reused.",
      );
    });

    test('failed commit (failOnApply) still bumps the epoch — a transient '
        'extra recompute is acceptable per the rollback contract', () async {
      final store = InMemoryMemoryStore();
      final clock = _FakeClock(DateTime(2026, 6, 1, 12));
      final container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_mockSignedInAuth()),
          memoryStoreProvider.overrideWithValue(store),
          ..._seededPassFourFiveOverrides().overrides,
          clockProvider.overrideWithValue(clock.call),
          aiUpdateProvider.overrideWith(
            (ref) => MockAiUpdate(
              memoryStore: ref.watch(memoryStoreProvider),
              appController: ref.read(appControllerProvider.notifier),
              onMemoryWritten: () {
                final c = ref.read(clockProvider);
                ref.read(memoryEpochProvider.notifier).bump(c());
              },
              failOnApply: true,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      final before = await container.read(recommendationsProvider.future);

      final mike = container
          .read(appControllerProvider)
          .connections
          .firstWhere((c) => c.id == 'mike');
      final memory = await container.read(memoryProvider('mike').future);
      final adapter = container.read(aiUpdateProvider);
      final result = await adapter.run(
        contact: mike,
        userInput: 'Will roll back.',
        currentMemory: memory,
        attachments: const [],
      );
      clock.now = clock.now.add(const Duration(seconds: 1));
      await expectLater(
        adapter.commit(result),
        throwsA(isA<AiUpdateFailure>()),
      );

      // The save succeeded then the apply threw; the epoch was
      // bumped after the save and is not unbumped on rollback. The
      // documented behavior is one extra recompute that produces the
      // same output (engine input is unchanged because the state
      // delta was rolled back).
      final after = await container.read(recommendationsProvider.future);
      expect(identical(before, after), isFalse);
      expect(
        after.map((r) => r.contactId).toList(),
        before.map((r) => r.contactId).toList(),
      );
    });
  });
}
