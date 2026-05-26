/// Adapter tests for `FirebaseConnectionStore` (Pass 4.5, #065).
///
/// Lives under `integration_test/` because the adapter calls into
/// `cloud_firestore` and `firebase_auth`, both of which require a
/// real Flutter engine to load their plugin channels. Run via:
///
///     firebase emulators:exec --only firestore,auth \
///       --project connect-me-rules-test \
///       "flutter test integration_test -d macos"
///
/// Mirrors the shape of
/// `integration_test/state/memory/firebase_memory_store_test.dart`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/connections/connection_providers.dart';
import 'package:connect_me/src/state/connections/firebase_connection_store.dart';

import '../../firebase_test_setup.dart';

/// Convenience: build a [Connection] with a known shape.
Connection _conn({
  required String id,
  String name = 'Sample',
  String email = 'sample@example.com',
  String category = 'Friends',
  String avatar = 'sample',
  int bondScore = 50,
  String nextStep = 'Catch up',
  DateTime? lastContact,
  String notes = '',
  DateTime? knownSince,
  List<String> preferredChannels = const ['email'],
  bool isSample = false,
}) {
  return Connection(
    id: id,
    name: name,
    email: email,
    category: category,
    avatar: avatar,
    bondScore: bondScore,
    nextStep: nextStep,
    lastContact: lastContact ?? DateTime.utc(2026, 5, 26, 12, 0, 0),
    notes: notes,
    knownSince: knownSince ?? DateTime.utc(2024, 1, 1),
    preferredChannels: preferredChannels,
    isSample: isSample,
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

  test('load on missing contact returns null', () async {
    final store =
        FirebaseConnectionStore(firestore: firestore, uid: currentUid());
    addTearDown(store.dispose);

    expect(await store.load('does-not-exist'), isNull);
  });

  test('round-trip: save then load returns the same connection', () async {
    final store =
        FirebaseConnectionStore(firestore: firestore, uid: currentUid());
    addTearDown(store.dispose);

    final input = _conn(
      id: 'sarah-c',
      name: 'Sarah Chen',
      email: 'sarah@example.com',
      category: 'Work',
      avatar: 'sarah',
      bondScore: 73,
      nextStep: 'Schedule lunch',
      lastContact: DateTime.utc(2026, 5, 1, 10, 0, 0),
      notes: 'Migration project lead',
      knownSince: DateTime.utc(2022, 3, 15),
      preferredChannels: const ['email', 'phone'],
      isSample: true,
    );

    await store.save(input);
    final loaded = await store.load('sarah-c');

    expect(loaded, isNotNull);
    expect(loaded!.id, input.id);
    expect(loaded.name, input.name);
    expect(loaded.email, input.email);
    expect(loaded.category, input.category);
    expect(loaded.avatar, input.avatar);
    expect(loaded.bondScore, input.bondScore);
    expect(loaded.nextStep, input.nextStep);
    expect(loaded.lastContact, input.lastContact);
    expect(loaded.notes, input.notes);
    expect(loaded.knownSince, input.knownSince);
    expect(loaded.preferredChannels, input.preferredChannels);
    expect(loaded.isSample, input.isSample);
  });

  test(
      'listAll returns every saved connection keyed by id; empty when none',
      () async {
    final store =
        FirebaseConnectionStore(firestore: firestore, uid: currentUid());
    addTearDown(store.dispose);

    expect(await store.listAll(), isEmpty);

    await store.save(_conn(id: 'a', name: 'A'));
    await store.save(_conn(id: 'b', name: 'B'));

    final all = await store.listAll();
    expect(all.keys, unorderedEquals({'a', 'b'}));
    expect(all['a']!.name, 'A');
    expect(all['b']!.name, 'B');
  });

  test('delete removes the doc; subsequent load returns null', () async {
    final store =
        FirebaseConnectionStore(firestore: firestore, uid: currentUid());
    addTearDown(store.dispose);

    await store.save(_conn(id: 'mike'));
    expect(await store.load('mike'), isNotNull);

    await store.delete('mike');
    expect(await store.load('mike'), isNull);
    expect(await store.listAll(), isEmpty);
  });

  test('delete on missing doc is a no-op (no exception)', () async {
    final store =
        FirebaseConnectionStore(firestore: firestore, uid: currentUid());
    addTearDown(store.dispose);

    await store.delete('never-existed');
    expect(await store.listAll(), isEmpty);
  });

  test(
      'save writes all 14 fields including schemaVersion: 1 and an '
      'updatedAt server timestamp',
      () async {
    final uid = currentUid();
    final store = FirebaseConnectionStore(firestore: firestore, uid: uid);
    addTearDown(store.dispose);

    await store.save(_conn(id: 'c1', name: 'C One'));

    final raw = await firestore
        .collection('users')
        .doc(uid)
        .collection('connections')
        .doc('c1')
        .get();

    expect(raw.exists, isTrue);
    final data = raw.data()!;
    expect(
      data.keys,
      unorderedEquals({
        'id', 'name', 'email', 'category', 'avatar', 'bondScore',
        'nextStep', 'lastContact', 'notes', 'knownSince',
        'preferredChannels', 'isSample', 'schemaVersion', 'updatedAt',
      }),
    );
    expect(data['id'], 'c1');
    expect(data['name'], 'C One');
    expect(data['schemaVersion'], 1);
    expect(data['lastContact'], isA<Timestamp>());
    expect(data['knownSince'], isA<Timestamp>());
    expect(data['preferredChannels'], isA<List<dynamic>>());
    expect(data['updatedAt'], isA<Timestamp>());
  });

  test(
      'snapshot listener emits initial empty map and then updates on '
      'cross-instance writes (same UID)',
      () async {
    final uid = currentUid();
    final storeReader =
        FirebaseConnectionStore(firestore: firestore, uid: uid);
    addTearDown(storeReader.dispose);
    final storeWriter =
        FirebaseConnectionStore(firestore: firestore, uid: uid);
    addTearDown(storeWriter.dispose);

    final events = <Map<String, Connection>>[];
    final sub = storeReader.snapshot().listen(events.add);
    addTearDown(sub.cancel);

    // Wait for the initial empty snapshot to land.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(events.isNotEmpty, isTrue,
        reason: 'snapshot listener must emit at least once after subscribe');
    expect(events.first, isEmpty);

    // Write through the second store; the first store's subscription
    // must observe the change.
    await storeWriter.save(_conn(id: 'sarah', name: 'Sarah'));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(
      events.last.containsKey('sarah'),
      isTrue,
      reason:
          'cross-instance write under the same UID must surface in the '
          'snapshot listener of the reader store',
    );
    expect(events.last['sarah']!.name, 'Sarah');
  });

  test(
      'snapshotSync starts null, settles to a map after the first '
      'snapshot resolves',
      () async {
    final store =
        FirebaseConnectionStore(firestore: firestore, uid: currentUid());
    addTearDown(store.dispose);

    // Synchronous read before the listener has had a chance to fire
    // returns null per PRD §Q6 contract.
    expect(store.snapshotSync(), isNull);

    // Wait for the first snapshot to land. Empty map = signed-in but
    // empty collection (vs null = loading).
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(store.snapshotSync(), isNotNull);
    expect(store.snapshotSync(), isEmpty);

    await store.save(_conn(id: 'a'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(store.snapshotSync(), isNotNull);
    expect(store.snapshotSync()!.containsKey('a'), isTrue);
  });

  test(
      'dispose cancels the listener; subsequent cross-instance writes '
      'do not emit on the disposed stream',
      () async {
    final uid = currentUid();
    final reader = FirebaseConnectionStore(firestore: firestore, uid: uid);
    final writer = FirebaseConnectionStore(firestore: firestore, uid: uid);
    addTearDown(writer.dispose);

    final events = <Map<String, Connection>>[];
    final errors = <Object>[];
    final sub = reader.snapshot().listen(
      events.add,
      onError: errors.add,
    );
    addTearDown(sub.cancel);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    final beforeDispose = events.length;

    await reader.dispose();
    // Dispose is idempotent — second call must not throw.
    await reader.dispose();

    await writer.save(_conn(id: 'after-dispose'));
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(events.length, beforeDispose,
        reason: 'no further events should land on a disposed reader');
    expect(errors, isEmpty,
        reason: 'dispose should not surface errors on the stream');
  });

  test('two stores for two UIDs are isolated', () async {
    // Save under user A.
    final uidA = currentUid();
    final storeA = FirebaseConnectionStore(firestore: firestore, uid: uidA);
    addTearDown(storeA.dispose);
    await storeA.save(_conn(id: 'only-a', name: 'Only A'));
    expect((await storeA.listAll()).keys, contains('only-a'));

    // Sign out, sign in as a different anonymous user, build store B
    // bound to the new UID.
    await FirebaseAuth.instance.signOut();
    final credB = await FirebaseAuth.instance.signInAnonymously();
    final uidB = credB.user!.uid;
    expect(uidB, isNot(uidA));

    final storeB = FirebaseConnectionStore(firestore: firestore, uid: uidB);
    addTearDown(storeB.dispose);
    expect(await storeB.listAll(), isEmpty);
    expect(await storeB.load('only-a'), isNull);
  });

  test(
      "user B cannot read user A's connections (rules-enforced isolation)",
      () async {
    // Save under user A.
    final uidA = currentUid();
    final storeA = FirebaseConnectionStore(firestore: firestore, uid: uidA);
    addTearDown(storeA.dispose);
    await storeA.save(_conn(id: 'private', name: 'A private'));

    // Switch to user B.
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();

    // Build a store bound to *user A's* UID but operated by user B.
    // The rules require `request.auth.uid == uid` on the path, so
    // user B's load attempt is denied.
    final spoofStore =
        FirebaseConnectionStore(firestore: firestore, uid: uidA);
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
    // Sign in as user A and capture A's UID, then switch to user B.
    // A spoof store bound to user A's UID but operated by user B will
    // open a `users/{uidA}/connections.snapshots()` subscription that
    // the rules deny — the underlying stream emits an error event,
    // and the adapter must forward it onto the broadcast stream's
    // error channel without ever populating `_mirror`.
    final uidA = currentUid();
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();

    final spoof =
        FirebaseConnectionStore(firestore: firestore, uid: uidA);
    addTearDown(spoof.dispose);

    final events = <Map<String, Connection>>[];
    final errors = <Object>[];
    final sub = spoof.snapshot().listen(
      events.add,
      onError: errors.add,
    );
    addTearDown(sub.cancel);

    // Wait for the listener to surface the rules-denied event. The
    // sleep is bounded by the same precedent the rest of the suite
    // uses (200-500ms) — flaky-wait substitution is tracked in the
    // PRD as a non-blocking improvement.
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
            'errored — the adapter must not synthesize an empty map '
            'on error, since that would be indistinguishable from '
            '"signed-in but empty" per the null-while-loading contract.');
  });

  test(
      'malformed write (out-of-range bondScore) is rejected by rules',
      () async {
    // The rules from #066 enforce bondScore in 0..100. A direct
    // write that bypasses the adapter encoder must be rejected
    // server-side. The adapter itself only writes well-formed
    // documents, so this guards against a future encoder bug.
    final uid = currentUid();
    final docRef = firestore
        .collection('users')
        .doc(uid)
        .collection('connections')
        .doc('bad');

    await expectLater(
      docRef.set(<String, dynamic>{
        'id': 'bad',
        'name': 'Bad',
        'email': '',
        'category': 'Friends',
        'avatar': 'bad',
        'bondScore': 500,
        'nextStep': '',
        'lastContact': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'notes': '',
        'knownSince': Timestamp.fromDate(DateTime.utc(2024, 1, 1)),
        'preferredChannels': const <String>[],
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
      'connectionStoreProvider rebuilds for a new user and the new '
      'store sees an empty collection (Pass 4.5 #065 type guard)',
      () async {
    // Sign in as user A through the real (emulator) FirebaseAuth and
    // build a ProviderContainer. connectionStoreProvider should hand
    // out a UID-bound FirebaseConnectionStore for user A; saving a
    // connection and re-listing through the provider should observe
    // it.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final userAUid = currentUid();
    final storeA = container.read(connectionStoreProvider);
    expect(storeA, isA<FirebaseConnectionStore>(),
        reason: 'signed-in connectionStoreProvider must return the '
            'Firestore-backed adapter (Pass 4.5 #065 type guard).');

    await storeA.save(_conn(id: 'a-only', name: 'A only'));
    expect((await storeA.listAll()).keys, contains('a-only'));

    // Switch to user B by signing out + back in anonymously. This
    // emits on `authStateChanges`, which fires the listener inside
    // `currentUserProvider` and invalidates it — the next read of
    // connectionStoreProvider rebuilds with the new UID.
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();
    final userBUid = currentUid();
    expect(userBUid, isNot(equals(userAUid)),
        reason: 'anonymous sign-in must produce a fresh UID.');

    // Pump a microtask so the StreamSubscription callback runs and
    // the provider invalidation is observed.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final storeB = container.read(connectionStoreProvider);
    expect(storeB, isA<FirebaseConnectionStore>());
    expect(identical(storeA, storeB), isFalse,
        reason: 'connectionStoreProvider must rebuild when the auth '
            'user changes; user B must not share user A\'s store '
            'instance.');

    expect(await storeB.listAll(), isEmpty,
        reason: 'user B starts with an empty connections collection; '
            "user A's data must not leak into user B's session.");
  });
}
