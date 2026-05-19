import 'package:connect_me/src/ai/ai_update.dart';
import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/app_state.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test-callable wall clock. Implements `call` so the bare instance
/// can be passed where `DateTime Function()` is expected.
class _FakeClock {
  _FakeClock(this.now);
  DateTime now;
  DateTime call() => now;
}

ProviderContainer _container({_FakeClock? clock}) {
  return ProviderContainer(overrides: [
    memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
    if (clock != null) clockProvider.overrideWithValue(clock.call),
  ]);
}

void main() {
  group('recommendationsProvider', () {
    test('emits a list ranked per the engine on initial read', () {
      final container = _container();
      addTearDown(container.dispose);

      final recs = container.read(recommendationsProvider);

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

    test('rebuilds when state.connections changes', () {
      final container = _container();
      addTearDown(container.dispose);

      final before = container.read(recommendationsProvider);

      container.read(appControllerProvider.notifier).addConnection(
            name: 'Drifting Dana',
            email: 'dana@test.com',
            category: 'Friends',
            notes: 'new contact',
          );

      // The new contact has lastContact = now, so it's filtered by the
      // 24h cooldown. The provider still recomputes; result identity
      // changes even when content is similar because Provider returns a
      // fresh list per read.
      final after = container.read(recommendationsProvider);
      expect(identical(before, after), isFalse);
    });

    test("deleted contact's recommendation card is no longer present", () {
      final container = _container();
      addTearDown(container.dispose);

      // 'mike' is in the seeded fixture and lands in the top 3 because
      // he's drifting (bond 68 = steady actually) with a 39-day gap.
      // Verify he's present, then verify deletion drops him.
      final before = container
          .read(recommendationsProvider)
          .map((r) => r.contactId)
          .toList();
      expect(before, contains('mike'));

      container.read(appControllerProvider.notifier).deleteConnection('mike');

      final after = container
          .read(recommendationsProvider)
          .map((r) => r.contactId)
          .toList();
      expect(after, isNot(contains('mike')));
    });

    test('returned recommendations carry deterministic priority strings',
        () {
      final container = _container();
      addTearDown(container.dispose);

      final recs = container.read(recommendationsProvider);
      const allowedPriorities = {
        'high priority',
        'medium priority',
        'low priority',
      };
      for (final rec in recs) {
        expect(allowedPriorities, contains(rec.priority));
        expect(rec, isA<Recommendation>());
      }
    });
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
    test('cache is served on a second read when no invalidation fires', () {
      // Fake clock pinned at a time well after the seeded `lastContact`
      // values so the engine produces a non-empty list.
      final clock = _FakeClock(DateTime(2026, 6, 1, 12));
      final container = _container(clock: clock);
      addTearDown(container.dispose);

      final first = container.read(recommendationsProvider);
      final second = container.read(recommendationsProvider);

      // Same list reference — the notifier returned the cached value
      // verbatim rather than recomputing.
      expect(identical(first, second), isTrue);
    });

    test('memory-change signal invalidates the cache on next read', () {
      final clock = _FakeClock(DateTime(2026, 6, 1, 12));
      final container = _container(clock: clock);
      addTearDown(container.dispose);

      final before = container.read(recommendationsProvider);

      // Bump the memory epoch to a moment after computedAt. This is
      // what `MockAiUpdate.commit` does after a successful save.
      container
          .read(memoryEpochProvider.notifier)
          .bump(clock.now.add(const Duration(seconds: 1)));

      final after = container.read(recommendationsProvider);

      // Recompute happened — a fresh list reference comes back.
      expect(identical(before, after), isFalse);
      // Content matches because the engine input did not change.
      expect(
        after.map((r) => r.contactId).toList(),
        before.map((r) => r.contactId).toList(),
      );
    });

    test('elapsed time > 6h invalidates the cache on next read', () {
      final clock = _FakeClock(DateTime(2026, 6, 1, 12));
      final container = _container(clock: clock);
      addTearDown(container.dispose);

      final before = container.read(recommendationsProvider);

      // Advance the wall clock past the 6h freshness window. Because
      // `read` alone does not re-run `build` (Riverpod treats the
      // notifier state as cached too), simulate the next-screen-read
      // freshness check by invalidating and re-reading. In production
      // any read on Home or the recommendations screen drives a
      // rebuild via the consumer; the test models that with
      // `container.invalidate`.
      clock.now = clock.now.add(
        recommendationsFreshness + const Duration(milliseconds: 1),
      );
      container.invalidate(recommendationsProvider);

      final after = container.read(recommendationsProvider);
      expect(identical(before, after), isFalse);
    });

    test('cache survives reads at exactly the 6h boundary minus one tick',
        () {
      final clock = _FakeClock(DateTime(2026, 6, 1, 12));
      final container = _container(clock: clock);
      addTearDown(container.dispose);

      final before = container.read(recommendationsProvider);

      // Just inside the freshness window. Re-reading should not
      // recompute even after an explicit invalidate — build runs but
      // the cache check returns the prior list.
      clock.now = clock.now.add(
        recommendationsFreshness - const Duration(seconds: 1),
      );
      container.invalidate(recommendationsProvider);
      final after = container.read(recommendationsProvider);

      expect(identical(before, after), isTrue);
    });

    test(
        'AI update commit bumps memoryEpoch which invalidates '
        'recommendations cache', () async {
      final store = InMemoryMemoryStore();
      final clock = _FakeClock(DateTime(2026, 6, 1, 12));
      final container = ProviderContainer(overrides: [
        memoryStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(clock.call),
      ]);
      addTearDown(container.dispose);

      // Prime the cache.
      final before = container.read(recommendationsProvider);

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

      // Reading the provider again must observe the epoch bump and
      // recompute. The state delta from `commit` also bumps
      // `lastContact`, so the recompute reflects the updated input.
      final after = container.read(recommendationsProvider);
      expect(identical(before, after), isFalse);
    });

    test(
        'failed commit (failOnApply) still bumps the epoch — a transient '
        'extra recompute is acceptable per the rollback contract', () async {
      final store = InMemoryMemoryStore();
      final clock = _FakeClock(DateTime(2026, 6, 1, 12));
      final container = ProviderContainer(overrides: [
        memoryStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(clock.call),
        aiUpdateProvider.overrideWith((ref) => MockAiUpdate(
              memoryStore: ref.watch(memoryStoreProvider),
              appController: ref.read(appControllerProvider.notifier),
              onMemoryWritten: () {
                final c = ref.read(clockProvider);
                ref.read(memoryEpochProvider.notifier).bump(c());
              },
              failOnApply: true,
            )),
      ]);
      addTearDown(container.dispose);

      final before = container.read(recommendationsProvider);

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
      final after = container.read(recommendationsProvider);
      expect(identical(before, after), isFalse);
      expect(
        after.map((r) => r.contactId).toList(),
        before.map((r) => r.contactId).toList(),
      );
    });
  });
}
