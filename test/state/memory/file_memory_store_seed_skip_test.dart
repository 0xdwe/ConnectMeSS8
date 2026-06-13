import 'dart:io';

import 'package:connect_me/src/state/app_state.dart';
import 'package:connect_me/src/state/memory/file_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_overrides.dart';

/// Mirrors the bootstrap path in `connect_me_app.dart`: a real
/// `FileMemoryStore` rooted at a temp directory, plus the
/// `memorySeedingProvider` driven by a `ProviderContainer`. Verifies
/// AC: "On second launch with seeded memories already on disk, the
/// seed migration is skipped." (#041 spec / PRD Q9)
void main() {
  group('FileMemoryStore + memorySeedingProvider', () {
    late Directory tempRoot;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'connectme_seed_skip_test_',
      );
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('first launch: empty disk → seed pass writes one file per '
        'connection', () async {
      final store = FileMemoryStore(directoryOverride: tempRoot);
      final container = ProviderContainer(
        overrides: [
          ...signedInDemoOverrides(),
          memoryStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);

      final connections = container.read(appControllerProvider).connections;
      expect(connections, isNotEmpty);

      await container.read(memorySeedingProvider.future);

      final all = await store.listAll();
      expect(all, hasLength(connections.length));
      for (final connection in connections) {
        expect(
          all[connection.id],
          isNotNull,
          reason: 'expected memory file for ${connection.id}',
        );
      }
    });

    test('second launch: pre-populated disk → seed pass is a no-op '
        '(filesystem-inferred state)', () async {
      // Hand-write a memory file as if a previous launch had seeded.
      final memoriesDir = Directory('${tempRoot.path}/memories');
      await memoriesDir.create(recursive: true);
      final preDoc = MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah Johnson',
        lastUpdated: DateTime.utc(2025, 1, 1),
        summary: 'persisted across launches',
        topics: const ['custom-topic'],
      );
      await File('${memoriesDir.path}/sarah.md').writeAsString(preDoc.render());

      final store = FileMemoryStore(directoryOverride: tempRoot);
      final container = ProviderContainer(
        overrides: [
          ...signedInDemoOverrides(),
          memoryStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);

      // Snapshot before the seed pass observes the store.
      final beforeNames = memoriesDir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(beforeNames, {'sarah.md'});

      await container.read(memorySeedingProvider.future);

      // listAll must be unchanged from the pre-populated state.
      final all = await store.listAll();
      expect(all.keys, ['sarah']);
      expect(all['sarah']!.summary, 'persisted across launches');
      expect(all['sarah']!.topics, ['custom-topic']);

      // No extra files were written for the other seeded connections.
      final afterNames = memoriesDir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(afterNames, {'sarah.md'});
    });

    test('memory persists across "restarts" (two FileMemoryStore '
        'instances over the same dir)', () async {
      // First "session": save a doc.
      final s1 = FileMemoryStore(directoryOverride: tempRoot);
      final original = MemoryDocument(
        contactId: 'mike',
        displayName: 'Mike Chen',
        lastUpdated: DateTime.utc(2026, 5, 19),
        summary: 'session-one summary',
        topics: const ['hiking'],
      );
      await s1.save(original);

      // Second "session": new instance, same directory.
      final s2 = FileMemoryStore(directoryOverride: tempRoot);
      final loaded = await s2.load('mike');

      expect(loaded, isNotNull);
      expect(loaded!.summary, 'session-one summary');
      expect(loaded.topics, ['hiking']);
    });
  });
}
