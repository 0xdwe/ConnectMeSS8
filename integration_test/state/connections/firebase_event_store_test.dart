/// Adapter tests for `FirebaseEventStore` (Pass 4.5, #068).
///
/// Lives under `integration_test/` because the adapter calls into
/// `cloud_firestore` and `firebase_auth`, both of which require a
/// real Flutter engine to load their plugin channels. Run via:
///
///     firebase emulators:exec --only firestore,auth \
///       --project connect-me-rules-test \
///       "flutter test integration_test -d <udid>"
///
/// Mirrors the shape of
/// `integration_test/state/connections/firebase_connection_store_test.dart`
/// from #065 and `firebase_interaction_store_test.dart` from #067.
/// GREEN-confirmed run is deferred to #073 (macOS desktop firebase_auth
/// keychain block).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/connections/event_providers.dart';
import 'package:connect_me/src/state/connections/firebase_event_store.dart';

import '../../firebase_test_setup.dart';

PlannerEvent _event({
  required String id,
  String title = "Sarah's birthday",
  String? contactId = 'sarah',
  String category = 'birthdays',
  DateTime? date,
  String note = '',
  String eventType = 'Birthday',
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
    date: date ?? DateTime.utc(2026, 6, 15, 12, 0, 0),
    note: note,
    eventType: eventType,
    isAllDay: isAllDay,
    startTimeMinutes: startTimeMinutes,
    endTimeMinutes: endTimeMinutes,
    isRecurring: isRecurring,
    recurrencePattern: recurrencePattern,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore firestore;

  setUpAll(() async {
    await setUpEmulators();
    firestore = FirebaseFirestore.instance;
  });

  setUp(() async {
    await tearDownEmulators();
    final cred = await FirebaseAuth.instance.signInAnonymously();
    expect(cred.user, isNotNull, reason: 'anonymous sign-in must succeed');
  });

  String currentUid() {
    final user = FirebaseAuth.instance.currentUser;
    expect(user, isNotNull);
    return user!.uid;
  }

  test('load on missing event returns null', () async {
    final store = FirebaseEventStore(firestore: firestore, uid: currentUid());
    addTearDown(store.dispose);

    expect(await store.load('does-not-exist'), isNull);
  });

  test('round-trip: save then load returns the same event', () async {
    final store = FirebaseEventStore(firestore: firestore, uid: currentUid());
    addTearDown(store.dispose);

    final input = _event(
      id: 'e-1',
      title: 'Coffee with Sarah',
      contactId: 'sarah',
      category: 'social',
      date: DateTime.utc(2026, 6, 1, 9, 0, 0),
      note: 'Discuss migration',
      eventType: 'Coffee',
      isAllDay: false,
      startTimeMinutes: 540,
      endTimeMinutes: 600,
      isRecurring: true,
      recurrencePattern: RecurrencePattern.weekly,
    );

    await store.save(input);
    final loaded = await store.load('e-1');

    expect(loaded, isNotNull);
    expect(loaded!.id, input.id);
    expect(loaded.title, input.title);
    expect(loaded.contactId, input.contactId);
    expect(loaded.category, input.category);
    expect(loaded.date, input.date);
    expect(loaded.note, input.note);
    expect(loaded.eventType, input.eventType);
    expect(loaded.isAllDay, input.isAllDay);
    expect(loaded.startTimeMinutes, input.startTimeMinutes);
    expect(loaded.endTimeMinutes, input.endTimeMinutes);
    expect(loaded.isRecurring, input.isRecurring);
    expect(loaded.recurrencePattern, input.recurrencePattern);
  });

  test('round-trip: save then load preserves null optional fields', () async {
    final store = FirebaseEventStore(firestore: firestore, uid: currentUid());
    addTearDown(store.dispose);

    final input = _event(
      id: 'e-bare',
      title: 'Bare',
      contactId: null,
      isAllDay: true,
    );

    await store.save(input);
    final loaded = await store.load('e-bare');

    expect(loaded, isNotNull);
    expect(loaded!.contactId, isNull);
    expect(loaded.startTimeMinutes, isNull);
    expect(loaded.endTimeMinutes, isNull);
    expect(loaded.recurrencePattern, isNull);
  });

  test(
    'listAll returns every saved event keyed by id; empty when none',
    () async {
      final store = FirebaseEventStore(firestore: firestore, uid: currentUid());
      addTearDown(store.dispose);

      expect(await store.listAll(), isEmpty);

      await store.save(_event(id: 'e-1', title: 'One'));
      await store.save(_event(id: 'e-2', title: 'Two'));

      final all = await store.listAll();
      expect(all.keys, unorderedEquals({'e-1', 'e-2'}));
      expect(all['e-1']!.title, 'One');
      expect(all['e-2']!.title, 'Two');
    },
  );

  test('delete removes the doc; subsequent load returns null', () async {
    final store = FirebaseEventStore(firestore: firestore, uid: currentUid());
    addTearDown(store.dispose);

    await store.save(_event(id: 'e-1'));
    expect(await store.load('e-1'), isNotNull);

    await store.delete('e-1');
    expect(await store.load('e-1'), isNull);
    expect(await store.listAll(), isEmpty);
  });

  test('delete on missing doc is a no-op (no exception)', () async {
    final store = FirebaseEventStore(firestore: firestore, uid: currentUid());
    addTearDown(store.dispose);

    await store.delete('never-existed');
    expect(await store.listAll(), isEmpty);
  });

  test('save writes required fields plus schemaVersion: 1 and an '
      'updatedAt server timestamp; omits null optional fields', () async {
    final uid = currentUid();
    final store = FirebaseEventStore(firestore: firestore, uid: uid);
    addTearDown(store.dispose);

    await store.save(_event(id: 'e-1', contactId: null));

    final raw = await firestore
        .collection('users')
        .doc(uid)
        .collection('events')
        .doc('e-1')
        .get();

    expect(raw.exists, isTrue);
    final data = raw.data()!;
    expect(
      data.keys,
      containsAll([
        'id',
        'title',
        'category',
        'date',
        'note',
        'eventType',
        'isAllDay',
        'isRecurring',
        'schemaVersion',
        'updatedAt',
      ]),
    );
    // Omitted optional fields must not be present at all so the
    // present-and-typed-or-absent rule guards apply uniformly.
    expect(
      data.keys.contains('contactId'),
      isFalse,
      reason: 'null optional contactId must not be written.',
    );
    expect(data.keys.contains('startTimeMinutes'), isFalse);
    expect(data.keys.contains('endTimeMinutes'), isFalse);
    expect(data.keys.contains('recurrencePattern'), isFalse);
    expect(data['id'], 'e-1');
    expect(data['eventType'], 'Birthday');
    expect(data['schemaVersion'], 1);
    expect(data['date'], isA<Timestamp>());
    expect(data['updatedAt'], isA<Timestamp>());
  });

  test('snapshot listener emits initial empty map and then updates on '
      'cross-instance writes (same UID)', () async {
    final uid = currentUid();
    final storeReader = FirebaseEventStore(firestore: firestore, uid: uid);
    addTearDown(storeReader.dispose);
    final storeWriter = FirebaseEventStore(firestore: firestore, uid: uid);
    addTearDown(storeWriter.dispose);

    final events = <Map<String, PlannerEvent>>[];
    final sub = storeReader.snapshot().listen(events.add);
    addTearDown(sub.cancel);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(events.isNotEmpty, isTrue);
    expect(events.first, isEmpty);

    await storeWriter.save(_event(id: 'e-1', title: 'Coffee'));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(events.last.containsKey('e-1'), isTrue);
    expect(events.last['e-1']!.title, 'Coffee');
  });

  test('snapshotSync starts null, settles to a map after the first '
      'snapshot resolves', () async {
    final store = FirebaseEventStore(firestore: firestore, uid: currentUid());
    addTearDown(store.dispose);

    expect(store.snapshotSync(), isNull);

    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(store.snapshotSync(), isNotNull);
    expect(store.snapshotSync(), isEmpty);

    await store.save(_event(id: 'e-1'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(store.snapshotSync()!.containsKey('e-1'), isTrue);
  });

  test('dispose cancels the listener; subsequent cross-instance writes '
      'do not emit on the disposed stream', () async {
    final uid = currentUid();
    final reader = FirebaseEventStore(firestore: firestore, uid: uid);
    final writer = FirebaseEventStore(firestore: firestore, uid: uid);
    addTearDown(writer.dispose);

    final events = <Map<String, PlannerEvent>>[];
    final errors = <Object>[];
    final sub = reader.snapshot().listen(events.add, onError: errors.add);
    addTearDown(sub.cancel);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    final beforeDispose = events.length;

    await reader.dispose();
    await reader.dispose(); // idempotent

    await writer.save(_event(id: 'after-dispose'));
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(events.length, beforeDispose);
    expect(errors, isEmpty);
  });

  test('two stores for two UIDs are isolated', () async {
    final uidA = currentUid();
    final storeA = FirebaseEventStore(firestore: firestore, uid: uidA);
    addTearDown(storeA.dispose);
    await storeA.save(_event(id: 'only-a', title: 'Only A'));
    expect((await storeA.listAll()).keys, contains('only-a'));

    await FirebaseAuth.instance.signOut();
    final credB = await FirebaseAuth.instance.signInAnonymously();
    final uidB = credB.user!.uid;
    expect(uidB, isNot(uidA));

    final storeB = FirebaseEventStore(firestore: firestore, uid: uidB);
    addTearDown(storeB.dispose);
    expect(await storeB.listAll(), isEmpty);
    expect(await storeB.load('only-a'), isNull);
  });

  test(
    "user B cannot read user A's events (rules-enforced isolation)",
    () async {
      final uidA = currentUid();
      final storeA = FirebaseEventStore(firestore: firestore, uid: uidA);
      addTearDown(storeA.dispose);
      await storeA.save(_event(id: 'private', title: 'A private'));

      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInAnonymously();

      final spoofStore = FirebaseEventStore(firestore: firestore, uid: uidA);
      addTearDown(spoofStore.dispose);
      await expectLater(
        spoofStore.load('private'),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    },
  );

  test(
    'snapshot listener forwards permission-denied errors to the stream '
    "error channel without corrupting the mirror (PRD §Q6 contract)",
    () async {
      final uidA = currentUid();
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInAnonymously();

      final spoof = FirebaseEventStore(firestore: firestore, uid: uidA);
      addTearDown(spoof.dispose);

      final events = <Map<String, PlannerEvent>>[];
      final errors = <Object>[];
      final sub = spoof.snapshot().listen(events.add, onError: errors.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(errors, isNotEmpty);
      expect(
        errors.first,
        isA<FirebaseException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        ),
      );
      expect(events, isEmpty);
      expect(spoof.snapshotSync(), isNull);
    },
  );

  test(
    'malformed write (invalid recurrencePattern) is rejected by rules',
    () async {
      final uid = currentUid();
      final docRef = firestore
          .collection('users')
          .doc(uid)
          .collection('events')
          .doc('bad');

      await expectLater(
        docRef.set(<String, dynamic>{
          'id': 'bad',
          'title': 'Bad',
          'category': 'general',
          'date': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
          'note': '',
          'eventType': 'Plan',
          'isAllDay': true,
          'isRecurring': true,
          'recurrencePattern': 'biweekly', // not in the enum set
          'schemaVersion': 1,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    },
  );

  test('eventStoreProvider rebuilds for a new user and the new '
      'store sees an empty collection', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final userAUid = currentUid();
    final storeA = container.read(eventStoreProvider);
    expect(
      storeA,
      isA<FirebaseEventStore>(),
      reason:
          'signed-in eventStoreProvider must return the '
          'Firestore-backed adapter (Pass 4.5 #068 type guard).',
    );

    await storeA.save(_event(id: 'a-only', title: 'A only'));
    expect((await storeA.listAll()).keys, contains('a-only'));

    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();
    final userBUid = currentUid();
    expect(userBUid, isNot(equals(userAUid)));

    await Future<void>.delayed(const Duration(milliseconds: 100));

    final storeB = container.read(eventStoreProvider);
    expect(storeB, isA<FirebaseEventStore>());
    expect(identical(storeA, storeB), isFalse);
    expect(await storeB.listAll(), isEmpty);
  });
}
