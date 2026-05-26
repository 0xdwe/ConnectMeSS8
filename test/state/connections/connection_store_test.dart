import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/connections/connection_store.dart';
import 'package:connect_me/src/state/connections/in_memory_connection_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for [InMemoryConnectionStore] (Pass 4.5 #064).
///
/// Mirrors `test/state/memory/memory_store_test.dart` shape from
/// Pass 3 / Pass 4.2. Pure Dart, no Firebase; the snapshot stream
/// contract is exercised here so the same surface lights up
/// identically when [FirebaseConnectionStore] arrives in #065.
void main() {
  Connection makeConnection(
    String id, {
    String name = 'Sample',
    int bondScore = 50,
  }) {
    return Connection(
      id: id,
      name: name,
      email: '$id@example.com',
      category: 'Friends',
      avatar: id,
      bondScore: bondScore,
      nextStep: '',
      lastContact: DateTime.utc(2026, 5, 26),
      notes: '',
      knownSince: DateTime.utc(2024, 1, 1),
      preferredChannels: const ['email'],
    );
  }

  group('InMemoryConnectionStore — async surface', () {
    test('save then load round-trips the same connection', () async {
      final store = InMemoryConnectionStore();
      final sarah = makeConnection('sarah', name: 'Sarah');

      await store.save(sarah);

      final loaded = await store.load('sarah');
      expect(loaded, isNotNull);
      expect(loaded!.id, 'sarah');
      expect(loaded.name, 'Sarah');
    });

    test('load returns null for a missing id', () async {
      final store = InMemoryConnectionStore();
      expect(await store.load('does-not-exist'), isNull);
    });

    test('delete is a no-op for a missing id', () async {
      final store = InMemoryConnectionStore();
      // Must not throw.
      await store.delete('does-not-exist');
      expect(await store.listAll(), isEmpty);
    });

    test('delete removes an existing entry', () async {
      final store = InMemoryConnectionStore();
      await store.save(makeConnection('sarah'));
      await store.delete('sarah');
      expect(await store.load('sarah'), isNull);
      expect(await store.listAll(), isEmpty);
    });

    test('listAll returns an empty map for a fresh store', () async {
      final store = InMemoryConnectionStore();
      final all = await store.listAll();
      expect(all, isEmpty);
    });

    test('listAll returns every saved connection keyed by id', () async {
      final store = InMemoryConnectionStore();
      await store.save(makeConnection('sarah', name: 'Sarah'));
      await store.save(makeConnection('mike', name: 'Mike'));

      final all = await store.listAll();
      expect(all.keys, unorderedEquals(<String>['sarah', 'mike']));
      expect(all['sarah']!.name, 'Sarah');
      expect(all['mike']!.name, 'Mike');
    });

    test('save overwrites an existing entry under the same id', () async {
      final store = InMemoryConnectionStore();
      await store.save(makeConnection('sarah', name: 'Sarah', bondScore: 50));
      await store.save(
        makeConnection('sarah', name: 'Sarah Q.', bondScore: 80),
      );

      final loaded = await store.load('sarah');
      expect(loaded!.name, 'Sarah Q.');
      expect(loaded.bondScore, 80);
      final all = await store.listAll();
      expect(all, hasLength(1));
    });

    test('listAll snapshots are independent of the live store', () async {
      // Mutating a returned listAll map must not corrupt the store.
      final store = InMemoryConnectionStore();
      await store.save(makeConnection('sarah'));
      final snapshot = await store.listAll();
      expect(
          () => snapshot['mike'] = makeConnection('mike'),
          throwsUnsupportedError,
          reason:
              'listAll must return an unmodifiable view to keep callers from '
              'mutating the underlying store by accident.');
    });
  });

  group('InMemoryConnectionStore — snapshot stream', () {
    test('snapshotSync starts null until the first event has emitted',
        () async {
      final store = InMemoryConnectionStore();
      // Before anyone subscribes / before any save, the mirror has not
      // yet been published. Mirrors the FirebaseConnectionStore contract
      // documented in #065 ACs.
      expect(store.snapshotSync(), isNull);
    });

    test('snapshot emits the current state on first subscribe', () async {
      final store = InMemoryConnectionStore();
      await store.save(makeConnection('sarah'));

      final first = await store.snapshot().first;
      expect(first.keys, contains('sarah'));
    });

    test('snapshot emits an updated map after save', () async {
      final store = InMemoryConnectionStore();

      final emitted = <Map<String, Connection>>[];
      final sub = store.snapshot().listen(emitted.add);
      // Allow the initial replay to run.
      await Future<void>.delayed(Duration.zero);

      await store.save(makeConnection('sarah', name: 'Sarah'));
      await Future<void>.delayed(Duration.zero);

      expect(emitted.last.keys, contains('sarah'));
      expect(emitted.last['sarah']!.name, 'Sarah');
      expect(store.snapshotSync(), isNotNull);
      expect(store.snapshotSync()!['sarah']!.name, 'Sarah');

      await sub.cancel();
    });

    test('snapshot emits an updated map after delete', () async {
      final store = InMemoryConnectionStore();
      await store.save(makeConnection('sarah'));

      final emitted = <Map<String, Connection>>[];
      final sub = store.snapshot().listen(emitted.add);
      await Future<void>.delayed(Duration.zero);

      await store.delete('sarah');
      await Future<void>.delayed(Duration.zero);

      expect(emitted.last.containsKey('sarah'), isFalse);
      expect(store.snapshotSync()!.containsKey('sarah'), isFalse);

      await sub.cancel();
    });

    test('snapshot is a broadcast stream — multiple listeners both receive',
        () async {
      final store = InMemoryConnectionStore();

      final aEvents = <Map<String, Connection>>[];
      final bEvents = <Map<String, Connection>>[];
      final subA = store.snapshot().listen(aEvents.add);
      final subB = store.snapshot().listen(bEvents.add);
      await Future<void>.delayed(Duration.zero);

      await store.save(makeConnection('sarah'));
      await Future<void>.delayed(Duration.zero);

      expect(aEvents.last.keys, contains('sarah'));
      expect(bEvents.last.keys, contains('sarah'));

      await subA.cancel();
      await subB.cancel();
    });

    test('clear empties the store and emits an empty map', () async {
      final store = InMemoryConnectionStore();
      await store.save(makeConnection('sarah'));
      await store.save(makeConnection('mike'));

      final emitted = <Map<String, Connection>>[];
      final sub = store.snapshot().listen(emitted.add);
      await Future<void>.delayed(Duration.zero);

      await store.clear();
      await Future<void>.delayed(Duration.zero);

      expect(emitted.last, isEmpty);
      expect(await store.listAll(), isEmpty);

      await sub.cancel();
    });
  });

  group('ConnectionStore — interface contract', () {
    test('InMemoryConnectionStore is-a ConnectionStore', () {
      // Compile-time assertion that the in-memory adapter implements
      // the seam, so the production override path stays type-safe.
      final ConnectionStore store = InMemoryConnectionStore();
      expect(store, isA<ConnectionStore>());
    });
  });
}
