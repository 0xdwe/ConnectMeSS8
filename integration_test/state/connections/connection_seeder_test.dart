/// Integration tests for [ConnectionSeeder] (Pass 4.5, #069).
///
/// Lives under `integration_test/` because the seeder calls into
/// `cloud_firestore` and `firebase_auth`. Run via:
///
///     firebase emulators:exec --only firestore,auth \
///       --project connect-me-rules-test \
///       "flutter test integration_test -d <udid>"
///
/// Mirrors the shape of the per-store integration tests from
/// #065/#067/#068. GREEN-confirmed run is deferred to #073 because
/// the macOS desktop run target hits `[firebase_auth/keychain-error]`
/// on `signInAnonymously`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:connect_me/src/state/connections/connection_seeder.dart';

import '../../firebase_test_setup.dart';

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

  Future<DocumentSnapshot<Map<String, dynamic>>> readUserDoc(String uid) async {
    return firestore.collection('users').doc(uid).get();
  }

  Future<int> countCollection(String uid, String name) async {
    final query = await firestore
        .collection('users')
        .doc(uid)
        .collection(name)
        .get();
    return query.docs.length;
  }

  test(
    'samples branch: fresh UID writes 5 connections + 3 interactions + 5 events',
    () async {
      final uid = currentUid();
      final seeder = ConnectionSeeder(firestore: firestore, uid: uid);

      final result = await seeder.run(choice: SeederChoice.samples);
      expect(result.didSeed, isTrue);
      expect(result.didNoOp, isFalse);
      expect(result.connectionsWritten, 5);
      expect(result.interactionsWritten, 3);
      expect(result.eventsWritten, 5);

      expect(await countCollection(uid, 'connections'), 5);
      expect(await countCollection(uid, 'interactions'), 3);
      expect(await countCollection(uid, 'events'), 5);
    },
  );

  test('samples branch: all five sentinels land on the user doc', () async {
    final uid = currentUid();
    final seeder = ConnectionSeeder(firestore: firestore, uid: uid);
    await seeder.run(choice: SeederChoice.samples);

    final userDoc = await readUserDoc(uid);
    expect(userDoc.exists, isTrue);
    final data = userDoc.data()!;
    for (final sentinel in SeederSentinels.all) {
      expect(
        data[sentinel],
        isA<Timestamp>(),
        reason: 'sentinel $sentinel must be a Timestamp after seeding',
      );
    }
    expect(data['categories'], isA<List<dynamic>>());
    expect(data['eventTypes'], isA<List<dynamic>>());
    expect((data['categories'] as List).length, isPositive);
    expect((data['eventTypes'] as List).length, isPositive);
  });

  test(
    'fresh branch: writes empty collections but seeds categories + eventTypes',
    () async {
      final uid = currentUid();
      final seeder = ConnectionSeeder(firestore: firestore, uid: uid);

      final result = await seeder.run(choice: SeederChoice.fresh);
      expect(
        result.didSeed,
        isFalse,
        reason: 'fresh branch is sentinel-only for the three collections',
      );
      expect(
        result.didNoOp,
        isFalse,
        reason:
            'fresh branch still writes categories + eventTypes + '
            'three sentinel-only timestamps',
      );
      expect(result.connectionsWritten, 0);
      expect(result.interactionsWritten, 0);
      expect(result.eventsWritten, 0);

      expect(await countCollection(uid, 'connections'), 0);
      expect(await countCollection(uid, 'interactions'), 0);
      expect(await countCollection(uid, 'events'), 0);

      final userDoc = await readUserDoc(uid);
      final data = userDoc.data()!;
      for (final sentinel in SeederSentinels.all) {
        expect(
          data[sentinel],
          isA<Timestamp>(),
          reason:
              'fresh branch must still set $sentinel so a future '
              'launch does not re-prompt or re-seed',
        );
      }
      expect(data['categories'], isA<List<dynamic>>());
      expect(data['eventTypes'], isA<List<dynamic>>());
    },
  );

  test('idempotency: re-running with samples is a no-op', () async {
    final uid = currentUid();
    final seeder = ConnectionSeeder(firestore: firestore, uid: uid);

    final first = await seeder.run(choice: SeederChoice.samples);
    expect(first.didSeed, isTrue);

    final second = await seeder.run(choice: SeederChoice.samples);
    expect(second.didSeed, isFalse);
    expect(second.didNoOp, isTrue);

    // Counts unchanged from the first run.
    expect(await countCollection(uid, 'connections'), 5);
    expect(await countCollection(uid, 'interactions'), 3);
    expect(await countCollection(uid, 'events'), 5);
  });

  test('idempotency: re-running with fresh is a no-op', () async {
    final uid = currentUid();
    final seeder = ConnectionSeeder(firestore: firestore, uid: uid);

    final first = await seeder.run(choice: SeederChoice.fresh);
    expect(first.didNoOp, isFalse);

    final second = await seeder.run(choice: SeederChoice.fresh);
    expect(
      second.didNoOp,
      isTrue,
      reason: 'second fresh run must be a true no-op',
    );

    expect(await countCollection(uid, 'connections'), 0);
    expect(await countCollection(uid, 'interactions'), 0);
    expect(await countCollection(uid, 'events'), 0);
  });

  test('partial-state recovery: with categoriesSeededAt pre-set, the seeder '
      'still writes the other targets', () async {
    final uid = currentUid();

    // Manually pre-seed a categories sentinel as if a previous run
    // had succeeded for that branch only.
    await firestore.collection('users').doc(uid).set({
      SeederSentinels.categories: FieldValue.serverTimestamp(),
      'categories': const ['Custom-Cat'],
    }, SetOptions(merge: true));

    final seeder = ConnectionSeeder(firestore: firestore, uid: uid);
    final result = await seeder.run(choice: SeederChoice.samples);

    expect(result.didSeed, isTrue);
    expect(result.connectionsWritten, 5);
    expect(result.interactionsWritten, 3);
    expect(result.eventsWritten, 5);

    final userDoc = await readUserDoc(uid);
    final data = userDoc.data()!;
    expect(
      data['categories'],
      <String>['Custom-Cat'],
      reason:
          'pre-existing categories must not be overwritten when '
          'the categoriesSeededAt sentinel was already set.',
    );
  });

  test(
    'samples branch coexists with Pass 4.2 #059 migratedFromDiskAt',
    () async {
      final uid = currentUid();

      // A user who came in via Pass 4.2 already has migratedFromDiskAt
      // on their user doc. Pass 4.5's seeder must not clobber it.
      await firestore.collection('users').doc(uid).set({
        'migratedFromDiskAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final seeder = ConnectionSeeder(firestore: firestore, uid: uid);
      await seeder.run(choice: SeederChoice.samples);

      final userDoc = await readUserDoc(uid);
      final data = userDoc.data()!;
      expect(
        data['migratedFromDiskAt'],
        isA<Timestamp>(),
        reason: 'Pass 4.2 sentinel must survive the Pass 4.5 seeder.',
      );
      for (final sentinel in SeederSentinels.all) {
        expect(data[sentinel], isA<Timestamp>());
      }
    },
  );
}
