import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/connections/in_memory_interaction_store.dart';
import 'package:connect_me/src/state/connections/interaction_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for [InMemoryInteractionStore] (Pass 4.5 #067).
///
/// Mirrors `test/state/connections/connection_store_test.dart`
/// shape from #064. Pure Dart, no Firebase; the snapshot stream
/// contract is exercised here so the same surface lights up
/// identically for [FirebaseInteractionStore] under the emulator
/// (deferred to #073).
void main() {
  CrmInteraction makeInteraction(
    String id, {
    String contactId = 'sarah',
    InteractionType type = InteractionType.interaction,
    String title = 'Sample',
    String note = 'Note',
    DateTime? date,
    List<AttachmentRef> attachments = const <AttachmentRef>[],
    InteractionSource source = InteractionSource.manual,
  }) {
    return CrmInteraction(
      id: id,
      contactId: contactId,
      type: type,
      title: title,
      note: note,
      date: date ?? DateTime.utc(2026, 5, 26, 12, 0, 0),
      attachments: attachments,
      source: source,
    );
  }

  group('InMemoryInteractionStore — async surface', () {
    test('save then load round-trips the same interaction', () async {
      final store = InMemoryInteractionStore();
      final i = makeInteraction(
        'i1',
        contactId: 'sarah',
        title: 'Coffee chat',
        note: 'Discussed the migration project',
      );

      await store.save(i);

      final loaded = await store.load('i1');
      expect(loaded, isNotNull);
      expect(loaded!.id, 'i1');
      expect(loaded.contactId, 'sarah');
      expect(loaded.title, 'Coffee chat');
      expect(loaded.note, 'Discussed the migration project');
    });

    test('load returns null for a missing id', () async {
      final store = InMemoryInteractionStore();
      expect(await store.load('does-not-exist'), isNull);
    });

    test('delete is a no-op for a missing id', () async {
      final store = InMemoryInteractionStore();
      // Must not throw.
      await store.delete('does-not-exist');
      expect(await store.listAll(), isEmpty);
    });

    test('delete removes an existing entry', () async {
      final store = InMemoryInteractionStore();
      await store.save(makeInteraction('i1'));
      await store.delete('i1');
      expect(await store.load('i1'), isNull);
      expect(await store.listAll(), isEmpty);
    });

    test('listAll returns an empty map for a fresh store', () async {
      final store = InMemoryInteractionStore();
      final all = await store.listAll();
      expect(all, isEmpty);
    });

    test('listAll returns every saved interaction keyed by id', () async {
      final store = InMemoryInteractionStore();
      await store.save(makeInteraction('i1', title: 'One'));
      await store.save(makeInteraction('i2', title: 'Two'));

      final all = await store.listAll();
      expect(all.keys, unorderedEquals(<String>['i1', 'i2']));
      expect(all['i1']!.title, 'One');
      expect(all['i2']!.title, 'Two');
    });

    test('save overwrites an existing entry under the same id', () async {
      final store = InMemoryInteractionStore();
      await store.save(makeInteraction('i1', title: 'First'));
      await store.save(makeInteraction('i1', title: 'Second'));

      final loaded = await store.load('i1');
      expect(loaded!.title, 'Second');
      final all = await store.listAll();
      expect(all, hasLength(1));
    });

    test('listAll snapshots are independent of the live store', () async {
      // Mutating a returned listAll map must not corrupt the store.
      final store = InMemoryInteractionStore();
      await store.save(makeInteraction('i1'));
      final snapshot = await store.listAll();
      expect(
        () => snapshot['rogue'] = makeInteraction('rogue'),
        throwsUnsupportedError,
        reason:
            'listAll must return an unmodifiable view to keep callers '
            'from mutating the underlying store by accident.',
      );
    });

    test('attachments and source round-trip through save/load', () async {
      final store = InMemoryInteractionStore();
      final i = makeInteraction(
        'i1',
        attachments: const [AttachmentRef(name: 'file.txt', path: '/tmp/f')],
        source: InteractionSource.aiSuggested,
      );
      await store.save(i);
      final loaded = await store.load('i1');
      expect(loaded!.attachments, hasLength(1));
      expect(loaded.attachments.first.name, 'file.txt');
      expect(loaded.source, InteractionSource.aiSuggested);
    });
  });

  group('InMemoryInteractionStore — snapshot stream', () {
    test(
      'snapshotSync starts null until the first event has emitted',
      () async {
        final store = InMemoryInteractionStore();
        expect(store.snapshotSync(), isNull);
      },
    );

    test('snapshot emits the current state on first subscribe', () async {
      final store = InMemoryInteractionStore();
      await store.save(makeInteraction('i1'));

      final first = await store.snapshot().first;
      expect(first.keys, contains('i1'));
    });

    test('snapshot emits an updated map after save', () async {
      final store = InMemoryInteractionStore();

      final emitted = <Map<String, CrmInteraction>>[];
      final sub = store.snapshot().listen(emitted.add);
      await Future<void>.delayed(Duration.zero);

      await store.save(makeInteraction('i1', title: 'Coffee'));
      await Future<void>.delayed(Duration.zero);

      expect(emitted.last.keys, contains('i1'));
      expect(emitted.last['i1']!.title, 'Coffee');
      expect(store.snapshotSync(), isNotNull);
      expect(store.snapshotSync()!['i1']!.title, 'Coffee');

      await sub.cancel();
    });

    test('snapshot emits an updated map after delete', () async {
      final store = InMemoryInteractionStore();
      await store.save(makeInteraction('i1'));

      final emitted = <Map<String, CrmInteraction>>[];
      final sub = store.snapshot().listen(emitted.add);
      await Future<void>.delayed(Duration.zero);

      await store.delete('i1');
      await Future<void>.delayed(Duration.zero);

      expect(emitted.last.containsKey('i1'), isFalse);
      expect(store.snapshotSync()!.containsKey('i1'), isFalse);

      await sub.cancel();
    });

    test(
      'snapshot is a broadcast stream — multiple listeners both receive',
      () async {
        final store = InMemoryInteractionStore();

        final aEvents = <Map<String, CrmInteraction>>[];
        final bEvents = <Map<String, CrmInteraction>>[];
        final subA = store.snapshot().listen(aEvents.add);
        final subB = store.snapshot().listen(bEvents.add);
        await Future<void>.delayed(Duration.zero);

        await store.save(makeInteraction('i1'));
        await Future<void>.delayed(Duration.zero);

        expect(aEvents.last.keys, contains('i1'));
        expect(bEvents.last.keys, contains('i1'));

        await subA.cancel();
        await subB.cancel();
      },
    );

    test('clear empties the store and emits an empty map', () async {
      final store = InMemoryInteractionStore();
      await store.save(makeInteraction('i1'));
      await store.save(makeInteraction('i2'));

      final emitted = <Map<String, CrmInteraction>>[];
      final sub = store.snapshot().listen(emitted.add);
      await Future<void>.delayed(Duration.zero);

      await store.clear();
      await Future<void>.delayed(Duration.zero);

      expect(emitted.last, isEmpty);
      expect(await store.listAll(), isEmpty);

      await sub.cancel();
    });

    test('dispose is idempotent', () async {
      final store = InMemoryInteractionStore();
      await store.dispose();
      // Second call must not throw.
      await store.dispose();
    });
  });

  group('InteractionStore — interface contract', () {
    test('InMemoryInteractionStore is-a InteractionStore', () {
      // Compile-time assertion that the in-memory adapter implements
      // the seam, so the production override path stays type-safe.
      final InteractionStore store = InMemoryInteractionStore();
      expect(store, isA<InteractionStore>());
    });
  });
}
