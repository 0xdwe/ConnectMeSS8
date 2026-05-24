import 'package:connect_me/src/state/app_state.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_overrides.dart';

void main() {
  group('memorySeedingProvider', () {
    test('writes one doc per seeded connection on an empty store',
        () async {
      final store = InMemoryMemoryStore();
      final container = ProviderContainer(overrides: [
        ...signedInDemoOverrides(),
        memoryStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container.dispose);

      // AppState.seeded() carries 5 connections.
      final seededConnections =
          container.read(appControllerProvider).connections;
      expect(seededConnections, hasLength(5));

      await container.read(memorySeedingProvider.future);

      final all = await store.listAll();
      expect(all, hasLength(seededConnections.length));
      for (final connection in seededConnections) {
        final doc = all[connection.id];
        expect(doc, isNotNull,
            reason: 'expected a memory doc for ${connection.id}');
        expect(doc!.displayName, connection.name);
        // The seed pass populates summary from the connection's notes.
        expect(doc.summary, connection.notes);
      }
    });

    test('starter topics are derived from the connection category',
        () async {
      final store = InMemoryMemoryStore();
      final container = ProviderContainer(overrides: [
        ...signedInDemoOverrides(),
        memoryStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container.dispose);

      await container.read(memorySeedingProvider.future);
      final all = await store.listAll();

      // david → Family
      expect(all['david']!.topics, ['family']);
      // sarah → Friends
      expect(all['sarah']!.topics, ['friends']);
      // emily → Work
      expect(all['emily']!.topics, ['work']);
      // jessica → College
      expect(all['jessica']!.topics, ['college']);
      // mike → High School
      expect(all['mike']!.topics, ['high school']);
    });

    test('is idempotent: a non-empty store is not overwritten', () async {
      final store = InMemoryMemoryStore();
      final preExisting = MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah Johnson',
        lastUpdated: DateTime.utc(2020, 1, 1),
        summary: 'do not overwrite me',
        topics: const ['custom'],
      );
      await store.save(preExisting);

      final container = ProviderContainer(overrides: [
        ...signedInDemoOverrides(),
        memoryStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container.dispose);

      await container.read(memorySeedingProvider.future);

      final all = await store.listAll();
      // The seed pass saw a non-empty store and skipped, so only the
      // pre-existing doc remains. The other 4 seeded connections are
      // *not* added — they get empty docs lazily via memoryProvider.
      expect(all, hasLength(1));
      expect(all['sarah']!.summary, 'do not overwrite me');
      expect(all['sarah']!.topics, ['custom']);
    });
  });
}
