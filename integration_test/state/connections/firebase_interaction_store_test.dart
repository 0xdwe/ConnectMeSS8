/// Adapter tests for `FirebaseInteractionStore` (Pass 4.5, #067).
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
/// from #065. GREEN-confirmed run is deferred to #073 because the
/// macOS desktop run target hits `[firebase_auth/keychain-error]`
/// on `signInAnonymously` (no entitlement equivalent to the iOS
/// keychain-access-groups entitlement Pass 4.2 #058 added).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/connections/firebase_interaction_store.dart';
import 'package:connect_me/src/state/connections/interaction_providers.dart';

import '../../firebase_test_setup.dart';

/// Convenience: build a [CrmInteraction] with a known shape.
CrmInteraction _interaction({
  required String id,
  String contactId = 'sarah',
  InteractionType type = InteractionType.interaction,
  String title = 'Coffee chat',
  String note = 'Notes',
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

  test('load on missing interaction returns null', () async {
    final store =
        FirebaseInteractionStore(firestore: firestore, uid: currentUid());
    addTearDown(store.dispose);

    expect(await store.load('does-not-exist'), isNull);
  });

  test('round-trip: save then load returns the same interaction', () async {
    final store =
        FirebaseInteractionStore(firestore: firestore, uid: currentUid());
    addTearDown(store.dispose);

    final input = _interaction(
      id: 'i-1',
      contactId: 'sarah',
      type: InteractionType.sharedActivity,
      title: 'Lunch',
      note: 'Talked about the migration plan',
      date: DateTime.utc(2026, 5, 1, 12, 30, 0),
      source: InteractionSource.aiSuggested,
    );

    await store.save(input);
    final loaded = await store.load('i-1');

    expect(loaded, isNotNull);
    expect(loaded!.id, input.id);
    expect(loaded.contactId, input.contactId);
    expect(loaded.type, input.type);
    expect(loaded.title, input.title);
    expect(loaded.note, input.note);
    expect(loaded.date, input.date);
    expect(loaded.source, input.source);
  });

  test(
      'listAll returns every saved interaction keyed by id; empty when none',
      () async {
    final store =
        FirebaseInteractionStore(firestore: firestore, uid: currentUid());
    addTearDown(store.dispose);

    expect(await store.listAll(), isEmpty);

    await store.save(_interaction(id: 'i-1', title: 'One'));
    await store.save(_interaction(id: 'i-2', title: 'Two'));

    final all = await store.listAll();
    expect(all.keys, unorderedEquals({'i-1', 'i-2'}));
    expect(all['i-1']!.title, 'One');
    expect(all['i-2']!.title, 'Two');
  });

  test('delete removes the doc; subsequent load returns null', () async {
    final store =
        FirebaseInteractionStore(firestore: firestore, uid: currentUid());
    addTearDown(store.dispose);

    await store.save(_interaction(id: 'i-1'));
    expect(await store.load('i-1'), isNotNull);

    await store.delete('i-1');
    expect(await store.load('i-1'), isNull);
    expect(await store.listAll(), isEmpty);
  });

  test('delete on missing doc is a no-op (no exception)', () async {
    final store =
        FirebaseInteractionStore(firestore: firestore, uid: currentUid());
    addTearDown(store.dispose);

    await store.delete('never-existed');
    expect(await store.listAll(), isEmpty);
  });

  test(
      'save writes all required fields plus schemaVersion: 1 and an '
      'updatedAt server timestamp',
      () async {
    final uid = currentUid();
    final store = FirebaseInteractionStore(firestore: firestore, uid: uid);
    addTearDown(store.dispose);

    await store.save(_interaction(id: 'i-1', title: 'Test'));

    final raw = await firestore
        .collection('users')
        .doc(uid)
        .collection('interactions')
        .doc('i-1')
        .get();

    expect(raw.exists, isTrue);
    final data = raw.data()!;
    expect(
      data.keys,
      containsAll([
        'id', 'contactId', 'type', 'title', 'note', 'date',
        'schemaVersion', 'updatedAt', 'attachments', 'source',
      ]),
    );
    expect(data['id'], 'i-1');
    expect(data['type'], 'interaction');
    expect(data['source'], 'manual');
    expect(data['schemaVersion'], 1);
    expect(data['date'], isA<Timestamp>());
    expect(data['updatedAt'], isA<Timestamp>());
    expect(data['attachments'], isA<List<dynamic>>());
  });

  test(
      'snapshot listener emits initial empty map and then updates on '
      'cross-instance writes (same UID)',
      () async {
    final uid = currentUid();
    final storeReader =
        FirebaseInteractionStore(firestore: firestore, uid: uid);
    addTearDown(storeReader.dispose);
    final storeWriter =
        FirebaseInteractionStore(firestore: firestore, uid: uid);
    addTearDown(storeWriter.dispose);

    final events = <Map<String, CrmInteraction>>[];
    final sub = storeReader.snapshot().listen(events.add);
    addTearDown(sub.cancel);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(events.isNotEmpty, isTrue,
        reason: 'snapshot listener must emit at least once after subscribe');
    expect(events.first, isEmpty);

    await storeWriter.save(_interaction(id: 'i-1', title: 'Coffee'));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(events.last.containsKey('i-1'), isTrue,
        reason:
            'cross-instance write under the same UID must surface in the '
            'snapshot listener of the reader store');
    expect(events.last['i-1']!.title, 'Coffee');
  });

  test(
      'snapshotSync starts null, settles to a map after the first '
      'snapshot resolves',
      () async {
    final store =
        FirebaseInteractionStore(firestore: firestore, uid: currentUid());
    addTearDown(store.dispose);

    expect(store.snapshotSync(), isNull);

    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(store.snapshotSync(), isNotNull);
    expect(store.snapshotSync(), isEmpty);

    await store.save(_interaction(id: 'i-1'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(store.snapshotSync(), isNotNull);
    expect(store.snapshotSync()!.containsKey('i-1'), isTrue);
  });

  test(
      'dispose cancels the listener; subsequent cross-instance writes '
      'do not emit on the disposed stream',
      () async {
    final uid = currentUid();
    final reader = FirebaseInteractionStore(firestore: firestore, uid: uid);
    final writer = FirebaseInteractionStore(firestore: firestore, uid: uid);
    addTearDown(writer.dispose);

    final events = <Map<String, CrmInteraction>>[];
    final errors = <Object>[];
    final sub = reader.snapshot().listen(events.add, onError: errors.add);
    addTearDown(sub.cancel);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    final beforeDispose = events.length;

    await reader.dispose();
    // Idempotent.
    await reader.dispose();

    await writer.save(_interaction(id: 'after-dispose'));
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(events.length, beforeDispose,
        reason: 'no further events should land on a disposed reader');
    expect(errors, isEmpty,
        reason: 'dispose should not surface errors on the stream');
  });

  test('two stores for two UIDs are isolated', () async {
    final uidA = currentUid();
    final storeA =
        FirebaseInteractionStore(firestore: firestore, uid: uidA);
    addTearDown(storeA.dispose);
    await storeA.save(_interaction(id: 'only-a', title: 'Only A'));
    expect((await storeA.listAll()).keys, contains('only-a'));

    await FirebaseAuth.instance.signOut();
    final credB = await FirebaseAuth.instance.signInAnonymously();
    final uidB = credB.user!.uid;
    expect(uidB, isNot(uidA));

    final storeB =
        FirebaseInteractionStore(firestore: firestore, uid: uidB);
    addTearDown(storeB.dispose);
    expect(await storeB.listAll(), isEmpty);
    expect(await storeB.load('only-a'), isNull);
  });

  test(
      "user B cannot read user A's interactions (rules-enforced isolation)",
      () async {
    final uidA = currentUid();
    final storeA =
        FirebaseInteractionStore(firestore: firestore, uid: uidA);
    addTearDown(storeA.dispose);
    await storeA.save(_interaction(id: 'private', title: 'A private'));

    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();

    final spoofStore =
        FirebaseInteractionStore(firestore: firestore, uid: uidA);
    addTearDown(spoofStore.dispose);
    await expectLater(
      spoofStore.load('private'),
      throwsA(isA<FirebaseException>().having(
        (e) => e.code,
        'code',
        'permission-denied',
      )),
    );
  });

  test(
      'snapshot listener forwards permission-denied errors to the stream '
      "error channel without corrupting the mirror (PRD §Q6 contract)",
      () async {
    final uidA = currentUid();
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();

    final spoof =
        FirebaseInteractionStore(firestore: firestore, uid: uidA);
    addTearDown(spoof.dispose);

    final events = <Map<String, CrmInteraction>>[];
    final errors = <Object>[];
    final sub = spoof.snapshot().listen(events.add, onError: errors.add);
    addTearDown(sub.cancel);

    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(errors, isNotEmpty,
        reason: 'permission-denied snapshot event must surface on '
            'the stream error channel.');
    expect(
      errors.first,
      isA<FirebaseException>().having(
        (e) => e.code,
        'code',
        'permission-denied',
      ),
      reason: 'forwarded error must preserve the FirebaseException '
          'code so callers can distinguish rules denial from '
          'transient network errors.',
    );
    expect(events, isEmpty,
        reason: 'no data events should land on a denied subscription.');
    expect(spoof.snapshotSync(), isNull,
        reason: 'mirror must remain null when the listener has only '
            'errored.');
  });

  test(
      'malformed write (invalid type enum) is rejected by rules',
      () async {
    final uid = currentUid();
    final docRef = firestore
        .collection('users')
        .doc(uid)
        .collection('interactions')
        .doc('bad');

    await expectLater(
      docRef.set(<String, dynamic>{
        'id': 'bad',
        'contactId': 'sarah',
        'type': 'gossip', // not in the enum set
        'title': 'Bad',
        'note': '',
        'date': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'schemaVersion': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      throwsA(isA<FirebaseException>().having(
        (e) => e.code,
        'code',
        'permission-denied',
      )),
    );
  });

  test(
      'interactionStoreProvider rebuilds for a new user and the new '
      'store sees an empty collection',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final userAUid = currentUid();
    final storeA = container.read(interactionStoreProvider);
    expect(storeA, isA<FirebaseInteractionStore>(),
        reason: 'signed-in interactionStoreProvider must return the '
            'Firestore-backed adapter (Pass 4.5 #067 type guard).');

    await storeA.save(_interaction(id: 'a-only', title: 'A only'));
    expect((await storeA.listAll()).keys, contains('a-only'));

    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();
    final userBUid = currentUid();
    expect(userBUid, isNot(equals(userAUid)));

    await Future<void>.delayed(const Duration(milliseconds: 100));

    final storeB = container.read(interactionStoreProvider);
    expect(storeB, isA<FirebaseInteractionStore>());
    expect(identical(storeA, storeB), isFalse,
        reason: 'interactionStoreProvider must rebuild when the auth '
            'user changes.');

    expect(await storeB.listAll(), isEmpty,
        reason: 'user B starts with an empty interactions collection.');
  });
}
