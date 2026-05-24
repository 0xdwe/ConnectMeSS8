import 'dart:io';

import 'package:connect_me/src/state/memory/disk_to_firestore_migration.dart';
import 'package:connect_me/src/state/memory/file_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/state/memory/memory_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Headless state-level tests for [DiskToFirestoreMigration].
///
/// What this file covers vs `integration_test/state/memory/`:
///
///   * **Here**: gate logic + source/target hand-off semantics.
///     Asserts that a real `FileMemoryStore` rooted in a temp dir
///     is read, each document is forwarded to the target via
///     `save()`, source files are preserved, and the migration is
///     idempotent against an already-migrated collection.
///   * **Integration test**: Firestore round-trip — the production
///     [FirestoreMigrationSentinel] writing through a transaction,
///     the rules' shape enforcement, and the cross-device race.
///
/// Both halves use the same [MigrationSentinel] interface; headless
/// tests pass [_RecordingSentinel], integration tests pass
/// [FirestoreMigrationSentinel] against the emulator.
///
/// PRD Q6.
void main() {
  group('DiskToFirestoreMigration', () {
    late Directory tempRoot;
    late FileMemoryStore source;
    late _RecordingTargetStore target;
    late _RecordingSentinel sentinel;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'connectme_migration_test_',
      );
      source = FileMemoryStore(directoryOverride: tempRoot);
      target = _RecordingTargetStore();
      sentinel = _RecordingSentinel();
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    DiskToFirestoreMigration buildMigration() {
      return DiskToFirestoreMigration(
        source: source,
        target: target,
        sentinel: sentinel,
        clock: () => DateTime.utc(2026, 5, 24, 12, 0, 0),
      );
    }

    test('source-empty: returns 0, writes the sentinel, no saves',
        () async {
      final count = await buildMigration().ensureMigrated();

      expect(count, 0);
      expect(target.saveCalls, isEmpty);
      expect(sentinel.setCalls, hasLength(1),
          reason: 'sentinel must be written so the next launch can '
              'skip the listAll round-trip.');
    });

    test('happy path: copies every source doc and writes the sentinel',
        () async {
      await source.save(_doc('sarah', 'Sarah Chen', summary: 'A'));
      await source.save(_doc('mike', 'Mike Lee', summary: 'B'));

      final count = await buildMigration().ensureMigrated();

      expect(count, 2);
      expect(target.saveCalls.map((d) => d.contactId),
          unorderedEquals({'sarah', 'mike'}));
      expect(sentinel.setCalls, hasLength(1));
    });

    test('source files remain on disk after migration (backup invariant)',
        () async {
      await source.save(_doc('sarah', 'Sarah Chen'));
      await source.save(_doc('mike', 'Mike Lee'));

      final memoriesDir = Directory('${tempRoot.path}/memories');
      final beforeNames = memoriesDir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(beforeNames, {'sarah.md', 'mike.md'});

      await buildMigration().ensureMigrated();

      final afterNames = memoriesDir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(afterNames, {'sarah.md', 'mike.md'},
          reason: 'PRD Q6: source files must NEVER be deleted.');
    });

    test(
        'non-empty target without sentinel: skips, sets sentinel, no saves',
        () async {
      // Simulate "another device migrated already" or "user has
      // their own writes through a different path."
      await target.save(_doc('sarah', 'Sarah from elsewhere'));
      await source.save(_doc('sarah', 'Sarah local copy'));
      await source.save(_doc('mike', 'Mike local copy'));

      target.saveCalls.clear();
      final count = await buildMigration().ensureMigrated();

      expect(count, 0);
      expect(target.saveCalls, isEmpty,
          reason: 'a non-empty remote must skip migration entirely.');
      expect(sentinel.setCalls, hasLength(1),
          reason: 'sentinel still gets set for future launches.');
    });

    test('non-empty target WITH sentinel: returns 0 immediately',
        () async {
      await target.save(_doc('sarah', 'Sarah from elsewhere'));
      sentinel.preset();
      target.saveCalls.clear();
      sentinel.setCalls.clear();

      final count = await buildMigration().ensureMigrated();

      expect(count, 0);
      expect(target.saveCalls, isEmpty);
      expect(sentinel.setCalls, isEmpty,
          reason: 'fully-migrated state stays no-op; sentinel is '
              'not re-written on every launch.');
    });

    test(
        'sentinel set but remote empty: defensive re-migrate (partial '
        'previous run)',
        () async {
      // Sentinel exists but there\'s nothing on the remote — looks
      // like a previous run got the sentinel down without any
      // contacts surviving. Local copy still has data; restore it.
      sentinel.preset();
      sentinel.setCalls.clear();
      await source.save(_doc('sarah', 'Sarah Chen'));

      final count = await buildMigration().ensureMigrated();

      expect(count, 1,
          reason: 'PRD Q6: a partially-migrated account whose '
              'remote went empty should still recover from the '
              'local backup.');
      expect(target.saveCalls.map((d) => d.contactId), ['sarah']);
      expect(sentinel.setCalls, hasLength(1));
    });

    test(
        're-running migration after a successful run is idempotent',
        () async {
      await source.save(_doc('sarah', 'Sarah Chen'));

      final first = await buildMigration().ensureMigrated();
      expect(first, 1);

      target.saveCalls.clear();
      // Simulate the production sentinel sticking across runs.
      sentinel.preset();
      sentinel.setCalls.clear();

      final second = await buildMigration().ensureMigrated();
      expect(second, 0);
      expect(target.saveCalls, isEmpty);
      expect(sentinel.setCalls, isEmpty,
          reason: 'sentinel-set + non-empty target is the full no-op '
              'fast path.');
    });

    test('per-contact save failure is best-effort: the rest still copy',
        () async {
      await source.save(_doc('sarah', 'Sarah Chen'));
      await source.save(_doc('mike', 'Mike Lee'));
      await source.save(_doc('jessica', 'Jessica Park'));

      target.failOnContactId = 'mike';

      final count = await buildMigration().ensureMigrated();

      expect(count, 2,
          reason: 'sarah + jessica succeeded; mike threw and was '
              'skipped per the best-effort migration contract.');
      expect(
        target.saveCalls.map((d) => d.contactId).toSet(),
        containsAll({'sarah', 'jessica'}),
      );
      expect(sentinel.setCalls, hasLength(1),
          reason: 'sentinel still gets set even on a partial run; '
              'the next launch will see a non-empty remote and '
              'skip, so partial state stops here.');
    });
  });
}

MemoryDocument _doc(
  String id,
  String name, {
  String summary = '',
}) {
  return MemoryDocument(
    contactId: id,
    displayName: name,
    lastUpdated: DateTime.utc(2026, 5, 19),
    version: 1,
    summary: summary,
  );
}

/// In-memory `MemoryStore` substitute. Records every save call so
/// tests can assert what migration forwarded; supports a
/// `failOnContactId` switch for the best-effort path.
class _RecordingTargetStore implements MemoryStore {
  final List<MemoryDocument> saveCalls = [];
  final Map<String, MemoryDocument> _byId = {};

  String? failOnContactId;

  @override
  Future<MemoryDocument?> load(String contactId) async => _byId[contactId];

  @override
  Future<void> save(MemoryDocument doc) async {
    if (failOnContactId == doc.contactId) {
      throw const _MigrationTestException('forced-failure');
    }
    saveCalls.add(doc);
    _byId[doc.contactId] = doc;
  }

  @override
  Future<void> delete(String contactId) async => _byId.remove(contactId);

  @override
  Future<Map<String, MemoryDocument>> listAll() async =>
      Map.unmodifiable(_byId);
}

class _MigrationTestException implements Exception {
  const _MigrationTestException(this.message);
  final String message;
  @override
  String toString() => 'MigrationTestException: $message';
}

/// In-memory [MigrationSentinel]. Flips to "set" via [set] or
/// [preset]; records every [set] call for assertion.
class _RecordingSentinel implements MigrationSentinel {
  bool _set = false;
  final List<DateTime> setCalls = [];

  /// Pretend a previous run already wrote the sentinel.
  void preset() {
    _set = true;
  }

  @override
  Future<bool> isSet() async => _set;

  @override
  Future<void> set(DateTime timestamp) async {
    _set = true;
    setCalls.add(timestamp);
  }
}
