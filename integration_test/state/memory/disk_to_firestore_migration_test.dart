/// Integration tests for [DiskToFirestoreMigration] (Pass 4.2 #059).
///
/// Lives under `integration_test/` because the production sentinel
/// is [FirestoreMigrationSentinel], which calls into `cloud_firestore`
/// and requires a real Flutter engine to load the plugin channel.
///
/// Run via:
///
///     firebase emulators:exec --only firestore,auth \
///       --project connect-me-rules-test \
///       "flutter test integration_test -d 'iPhone 16 Pro'"
library;

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:connect_me/src/state/memory/disk_to_firestore_migration.dart';
import 'package:connect_me/src/state/memory/file_memory_store.dart';
import 'package:connect_me/src/state/memory/firebase_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';

import '../../firebase_test_setup.dart';

MemoryDocument _doc(String id, {String? name, String summary = ''}) {
  return MemoryDocument(
    contactId: id,
    displayName: name ?? id,
    lastUpdated: DateTime.utc(2026, 5, 24, 12, 0, 0),
    version: 1,
    summary: summary,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore firestore;
  late Directory tempRoot;

  setUpAll(() async {
    await setUpEmulators();
    firestore = FirebaseFirestore.instance;
  });

  setUp(() async {
    await tearDownEmulators();
    final cred = await FirebaseAuth.instance.signInAnonymously();
    expect(cred.user, isNotNull, reason: 'anonymous sign-in must succeed');
    tempRoot = Directory.systemTemp.createTempSync('connectme_migration_int_');
  });

  tearDown(() {
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  String currentUid() {
    final user = FirebaseAuth.instance.currentUser;
    expect(user, isNotNull);
    return user!.uid;
  }

  DocumentReference<Map<String, dynamic>> userDocRef(String uid) =>
      firestore.collection('users').doc(uid);

  DiskToFirestoreMigration buildMigration() {
    final uid = currentUid();
    return DiskToFirestoreMigration(
      source: FileMemoryStore(directoryOverride: tempRoot),
      target: FirebaseMemoryStore(firestore: firestore, uid: uid),
      sentinel: FirestoreMigrationSentinel(firestore: firestore, uid: uid),
    );
  }

  test('happy path: seeds two docs on disk, migrates, sentinel set, '
      'sources preserved', () async {
    // Seed two markdown files on disk.
    final source = FileMemoryStore(directoryOverride: tempRoot);
    await source.save(_doc('sarah', name: 'Sarah Chen', summary: 'A'));
    await source.save(_doc('mike', name: 'Mike Lee', summary: 'B'));

    final memoriesDir = Directory('${tempRoot.path}/memories');
    final beforeNames = memoriesDir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toSet();
    expect(beforeNames, {'sarah.md', 'mike.md'});

    final uid = currentUid();
    final count = await buildMigration().ensureMigrated();
    expect(count, 2);

    // Remote collection has both contacts.
    final target = FirebaseMemoryStore(firestore: firestore, uid: uid);
    final remote = await target.listAll();
    expect(remote.keys, unorderedEquals({'sarah', 'mike'}));
    expect(remote['sarah']!.summary, 'A');
    expect(remote['mike']!.summary, 'B');

    // Sentinel set on the user doc.
    final userSnap = await userDocRef(uid).get();
    expect(userSnap.exists, isTrue);
    expect(
      userSnap.data()?[DiskToFirestoreMigration.sentinelField],
      isA<Timestamp>(),
      reason: 'sentinel field must be a Firestore Timestamp.',
    );

    // Source files untouched on disk.
    final afterNames = memoriesDir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toSet();
    expect(afterNames, {
      'sarah.md',
      'mike.md',
    }, reason: 'PRD Q6: source files MUST remain on disk as backup.');
  });

  test(
    'source-empty: returns 0, sentinel still written, target empty',
    () async {
      final uid = currentUid();
      final count = await buildMigration().ensureMigrated();

      expect(count, 0);
      final target = FirebaseMemoryStore(firestore: firestore, uid: uid);
      expect(await target.listAll(), isEmpty);

      final userSnap = await userDocRef(uid).get();
      expect(
        userSnap.data()?[DiskToFirestoreMigration.sentinelField],
        isNotNull,
      );
    },
  );

  test('already migrated (sentinel + non-empty target): returns 0, '
      'target unchanged', () async {
    final uid = currentUid();
    final target = FirebaseMemoryStore(firestore: firestore, uid: uid);
    await target.save(_doc('seed', summary: 'already there'));
    await FirestoreMigrationSentinel(
      firestore: firestore,
      uid: uid,
    ).set(DateTime.utc(2026, 5, 1));

    final source = FileMemoryStore(directoryOverride: tempRoot);
    await source.save(_doc('sarah', summary: 'should NOT migrate'));

    final count = await buildMigration().ensureMigrated();

    expect(count, 0);
    final remote = await target.listAll();
    expect(
      remote.keys,
      ['seed'],
      reason:
          'fully-migrated state must be left alone; the local '
          'sarah.md must not be re-uploaded.',
    );
  });

  test('re-running migration twice: second invocation is a no-op', () async {
    final uid = currentUid();
    final source = FileMemoryStore(directoryOverride: tempRoot);
    await source.save(_doc('sarah', summary: 'first'));

    final firstCount = await buildMigration().ensureMigrated();
    expect(firstCount, 1);

    final secondCount = await buildMigration().ensureMigrated();
    expect(
      secondCount,
      0,
      reason: 'sentinel + non-empty remote = full no-op fast path.',
    );

    final target = FirebaseMemoryStore(firestore: firestore, uid: uid);
    final remote = await target.listAll();
    expect(remote.keys, ['sarah']);
    expect(
      remote['sarah']!.summary,
      'first',
      reason: 'second run must not overwrite the first run\'s data.',
    );
  });

  test('non-empty target without sentinel: skips migration, writes '
      'sentinel for the future', () async {
    final uid = currentUid();
    final target = FirebaseMemoryStore(firestore: firestore, uid: uid);
    await target.save(_doc('seed', summary: 'arrived through some other path'));
    // Note: sentinel is NOT pre-set here.

    final source = FileMemoryStore(directoryOverride: tempRoot);
    await source.save(_doc('sarah', summary: 'should not migrate'));

    final count = await buildMigration().ensureMigrated();
    expect(count, 0);

    final remote = await target.listAll();
    expect(remote.keys, ['seed']);

    final userSnap = await userDocRef(uid).get();
    expect(
      userSnap.data()?[DiskToFirestoreMigration.sentinelField],
      isNotNull,
      reason: 'sentinel is now set so the next launch fast-paths.',
    );
  });
}
