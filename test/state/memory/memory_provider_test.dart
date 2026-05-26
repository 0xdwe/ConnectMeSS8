import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:connect_me/src/state/memory/memory_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../test_overrides.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('memoryProvider', () {
    test('returns the stored doc when one exists for the contact', () async {
      final store = InMemoryMemoryStore();
      final stored = MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah Johnson',
        lastUpdated: DateTime.utc(2026, 5, 19),
        summary: 'persisted summary',
      );
      await store.save(stored);

      final container = ProviderContainer(overrides: [
        ...signedInDemoOverrides(),
        memoryStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container.dispose);

      final doc = await container.read(memoryProvider('sarah').future);
      expect(doc.summary, 'persisted summary');
      expect(doc.displayName, 'Sarah Johnson');
    });

    test('lazy-creates an empty doc with displayName from connections',
        () async {
      final store = InMemoryMemoryStore();
      final container = ProviderContainer(overrides: [
        ...signedInDemoOverrides(),
        memoryStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container.dispose);

      // Seeded AppState carries 'sarah' → 'Sarah Johnson'.
      final doc = await container.read(memoryProvider('sarah').future);
      expect(doc.contactId, 'sarah');
      expect(doc.displayName, 'Sarah Johnson');
      expect(doc.summary, '');
    });

    test('falls back to contactId when no matching connection exists',
        () async {
      final store = InMemoryMemoryStore();
      final container = ProviderContainer(overrides: [
        ...signedInDemoOverrides(),
        memoryStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container.dispose);

      final doc = await container.read(memoryProvider('ghost').future);
      expect(doc.contactId, 'ghost');
      expect(doc.displayName, 'ghost');
    });

    test('lazy creation persists via store.save', () async {
      final store = InMemoryMemoryStore();
      final container = ProviderContainer(overrides: [
        ...signedInDemoOverrides(),
        memoryStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container.dispose);

      await container.read(memoryProvider('mike').future);

      // The provider should have written the empty doc back to the
      // store on miss; a second store.load proves that.
      final fromStore = await store.load('mike');
      expect(fromStore, isNotNull);
      expect(fromStore!.contactId, 'mike');
    });
  });

  group('memoryStoreProvider override', () {
    test('returns the override instance', () {
      final store = InMemoryMemoryStore();
      final container = ProviderContainer(overrides: [
        ...signedInDemoOverrides(),
        memoryStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container.dispose);

      final MemoryStore got = container.read(memoryStoreProvider);
      expect(identical(got, store), isTrue);
    });
  });
}
