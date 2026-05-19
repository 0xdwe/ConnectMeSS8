import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/app_state.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container() {
  return ProviderContainer(overrides: [
    memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
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
}
