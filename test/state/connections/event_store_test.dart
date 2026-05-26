import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/connections/event_store.dart';
import 'package:connect_me/src/state/connections/in_memory_event_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for [InMemoryEventStore] (Pass 4.5 #068).
///
/// Mirrors `test/state/connections/connection_store_test.dart` and
/// `interaction_store_test.dart` shape from #064 / #067. Pure Dart,
/// no Firebase; the snapshot stream contract is exercised here so
/// the same surface lights up identically for [FirebaseEventStore]
/// under the emulator (deferred to #073).
void main() {
  PlannerEvent makeEvent(
    String id, {
    String title = 'Sample',
    String? contactId,
    String category = 'general',
    DateTime? date,
    String note = '',
    String eventType = 'Plan',
    bool isAllDay = true,
    int? startTimeMinutes,
    int? endTimeMinutes,
    bool isRecurring = false,
    RecurrencePattern? recurrencePattern,
  }) {
    return PlannerEvent(
      id: id,
      title: title,
      contactId: contactId,
      category: category,
      date: date ?? DateTime.utc(2026, 5, 26),
      note: note,
      eventType: eventType,
      isAllDay: isAllDay,
      startTimeMinutes: startTimeMinutes,
      endTimeMinutes: endTimeMinutes,
      isRecurring: isRecurring,
      recurrencePattern: recurrencePattern,
    );
  }

  group('InMemoryEventStore — async surface', () {
    test('save then load round-trips the same event', () async {
      final store = InMemoryEventStore();
      final e = makeEvent(
        'e1',
        title: "Sarah's birthday",
        contactId: 'sarah',
        category: 'birthdays',
        eventType: 'Birthday',
      );

      await store.save(e);

      final loaded = await store.load('e1');
      expect(loaded, isNotNull);
      expect(loaded!.id, 'e1');
      expect(loaded.title, "Sarah's birthday");
      expect(loaded.contactId, 'sarah');
      expect(loaded.category, 'birthdays');
      expect(loaded.eventType, 'Birthday');
    });

    test('load returns null for a missing id', () async {
      final store = InMemoryEventStore();
      expect(await store.load('does-not-exist'), isNull);
    });

    test('delete is a no-op for a missing id', () async {
      final store = InMemoryEventStore();
      await store.delete('does-not-exist');
      expect(await store.listAll(), isEmpty);
    });

    test('delete removes an existing entry', () async {
      final store = InMemoryEventStore();
      await store.save(makeEvent('e1'));
      await store.delete('e1');
      expect(await store.load('e1'), isNull);
      expect(await store.listAll(), isEmpty);
    });

    test('listAll returns an empty map for a fresh store', () async {
      final store = InMemoryEventStore();
      final all = await store.listAll();
      expect(all, isEmpty);
    });

    test('listAll returns every saved event keyed by id', () async {
      final store = InMemoryEventStore();
      await store.save(makeEvent('e1', title: 'One'));
      await store.save(makeEvent('e2', title: 'Two'));

      final all = await store.listAll();
      expect(all.keys, unorderedEquals(<String>['e1', 'e2']));
      expect(all['e1']!.title, 'One');
      expect(all['e2']!.title, 'Two');
    });

    test('save overwrites an existing entry under the same id', () async {
      final store = InMemoryEventStore();
      await store.save(makeEvent('e1', title: 'First'));
      await store.save(makeEvent('e1', title: 'Second'));

      final loaded = await store.load('e1');
      expect(loaded!.title, 'Second');
      final all = await store.listAll();
      expect(all, hasLength(1));
    });

    test('listAll snapshots are independent of the live store', () async {
      final store = InMemoryEventStore();
      await store.save(makeEvent('e1'));
      final snapshot = await store.listAll();
      expect(
          () => snapshot['rogue'] = makeEvent('rogue'),
          throwsUnsupportedError,
          reason:
              'listAll must return an unmodifiable view to keep callers '
              'from mutating the underlying store by accident.');
    });

    test('all-optional fields round-trip through save/load', () async {
      // PlannerEvent has 4 nullable fields the rules guard with the
      // present-and-typed-or-absent pattern. The in-memory adapter
      // is null-transparent, but exercising the case here pins the
      // headless contract.
      final store = InMemoryEventStore();

      // Event with no optional fields.
      await store.save(makeEvent('e-bare', title: 'Bare'));
      final bare = await store.load('e-bare');
      expect(bare!.contactId, isNull);
      expect(bare.startTimeMinutes, isNull);
      expect(bare.endTimeMinutes, isNull);
      expect(bare.recurrencePattern, isNull);

      // Event with every optional field present.
      await store.save(makeEvent(
        'e-full',
        title: 'Full',
        contactId: 'sarah',
        startTimeMinutes: 540,
        endTimeMinutes: 600,
        isRecurring: true,
        recurrencePattern: RecurrencePattern.weekly,
      ));
      final full = await store.load('e-full');
      expect(full!.contactId, 'sarah');
      expect(full.startTimeMinutes, 540);
      expect(full.endTimeMinutes, 600);
      expect(full.isRecurring, isTrue);
      expect(full.recurrencePattern, RecurrencePattern.weekly);
    });
  });

  group('InMemoryEventStore — snapshot stream', () {
    test('snapshotSync starts null until the first event has emitted',
        () async {
      final store = InMemoryEventStore();
      expect(store.snapshotSync(), isNull);
    });

    test('snapshot emits the current state on first subscribe', () async {
      final store = InMemoryEventStore();
      await store.save(makeEvent('e1'));

      final first = await store.snapshot().first;
      expect(first.keys, contains('e1'));
    });

    test('snapshot emits an updated map after save', () async {
      final store = InMemoryEventStore();

      final emitted = <Map<String, PlannerEvent>>[];
      final sub = store.snapshot().listen(emitted.add);
      await Future<void>.delayed(Duration.zero);

      await store.save(makeEvent('e1', title: 'Coffee'));
      await Future<void>.delayed(Duration.zero);

      expect(emitted.last.keys, contains('e1'));
      expect(emitted.last['e1']!.title, 'Coffee');
      expect(store.snapshotSync(), isNotNull);
      expect(store.snapshotSync()!['e1']!.title, 'Coffee');

      await sub.cancel();
    });

    test('snapshot emits an updated map after delete', () async {
      final store = InMemoryEventStore();
      await store.save(makeEvent('e1'));

      final emitted = <Map<String, PlannerEvent>>[];
      final sub = store.snapshot().listen(emitted.add);
      await Future<void>.delayed(Duration.zero);

      await store.delete('e1');
      await Future<void>.delayed(Duration.zero);

      expect(emitted.last.containsKey('e1'), isFalse);
      expect(store.snapshotSync()!.containsKey('e1'), isFalse);

      await sub.cancel();
    });

    test('snapshot is a broadcast stream — multiple listeners both receive',
        () async {
      final store = InMemoryEventStore();

      final aEvents = <Map<String, PlannerEvent>>[];
      final bEvents = <Map<String, PlannerEvent>>[];
      final subA = store.snapshot().listen(aEvents.add);
      final subB = store.snapshot().listen(bEvents.add);
      await Future<void>.delayed(Duration.zero);

      await store.save(makeEvent('e1'));
      await Future<void>.delayed(Duration.zero);

      expect(aEvents.last.keys, contains('e1'));
      expect(bEvents.last.keys, contains('e1'));

      await subA.cancel();
      await subB.cancel();
    });

    test('clear empties the store and emits an empty map', () async {
      final store = InMemoryEventStore();
      await store.save(makeEvent('e1'));
      await store.save(makeEvent('e2'));

      final emitted = <Map<String, PlannerEvent>>[];
      final sub = store.snapshot().listen(emitted.add);
      await Future<void>.delayed(Duration.zero);

      await store.clear();
      await Future<void>.delayed(Duration.zero);

      expect(emitted.last, isEmpty);
      expect(await store.listAll(), isEmpty);

      await sub.cancel();
    });

    test('dispose is idempotent', () async {
      final store = InMemoryEventStore();
      await store.dispose();
      await store.dispose();
    });
  });

  group('EventStore — interface contract', () {
    test('InMemoryEventStore is-a EventStore', () {
      final EventStore store = InMemoryEventStore();
      expect(store, isA<EventStore>());
    });
  });
}
