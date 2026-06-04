import 'dart:convert';
import 'dart:io';

import 'package:connect_me/src/state/memory/file_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:flutter_test/flutter_test.dart';

MemoryDocument _doc(
  String id, {
  String name = 'Person',
  String summary = '',
  String history = '',
  List<String> topics = const [],
}) {
  return MemoryDocument(
    contactId: id,
    displayName: name,
    lastUpdated: DateTime.utc(2026, 5, 19, 12, 0, 0),
    summary: summary,
    history: history,
    topics: topics,
  );
}

/// Build a history string with `count` bullets each filled with a
/// roughly `padBytes`-byte payload. Returns the assembled history
/// suitable for `MemoryDocument.history`.
String _bulletyHistory(int count, {int padBytes = 1024}) {
  final pad = 'x' * padBytes;
  final buf = StringBuffer();
  for (var i = 0; i < count; i++) {
    final stamp = '2026-05-${(i % 28 + 1).toString().padLeft(2, '0')}';
    buf.writeln('- $stamp bullet#$i $pad');
  }
  return buf.toString();
}

void main() {
  group('FileMemoryStore', () {
    late Directory tempRoot;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync('connectme_memory_test_');
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('save then load round-trips', () async {
      final store = FileMemoryStore(directoryOverride: tempRoot);
      final doc = _doc(
        'sarah',
        name: 'Sarah Chen',
        summary: 'long-time friend',
        topics: ['coffee', 'travel'],
      );

      await store.save(doc);
      final loaded = await store.load('sarah');

      expect(loaded, isNotNull);
      expect(loaded!.contactId, 'sarah');
      expect(loaded.displayName, 'Sarah Chen');
      expect(loaded.summary, 'long-time friend');
      expect(loaded.topics, ['coffee', 'travel']);
    });

    test('load on unknown id returns null', () async {
      final store = FileMemoryStore(directoryOverride: tempRoot);
      expect(await store.load('nope'), isNull);
    });

    test('delete removes the file; load after delete returns null', () async {
      final store = FileMemoryStore(directoryOverride: tempRoot);
      await store.save(_doc('mike'));
      await store.delete('mike');

      expect(await store.load('mike'), isNull);
    });

    test('delete on missing id is a no-op', () async {
      final store = FileMemoryStore(directoryOverride: tempRoot);
      await store.delete('not-there');
      expect(await store.load('not-there'), isNull);
    });

    test('listAll returns every saved document', () async {
      final store = FileMemoryStore(directoryOverride: tempRoot);
      await store.save(_doc('a'));
      await store.save(_doc('b'));
      await store.save(_doc('c'));

      final all = await store.listAll();
      expect(all.keys, containsAll(['a', 'b', 'c']));
      expect(all, hasLength(3));
    });

    test('listAll snapshot is unmodifiable', () async {
      final store = FileMemoryStore(directoryOverride: tempRoot);
      await store.save(_doc('a'));
      final all = await store.listAll();
      expect(() => all['b'] = _doc('b'), throwsUnsupportedError);
    });

    test('save leaves no .md.tmp file behind on success', () async {
      final store = FileMemoryStore(directoryOverride: tempRoot);
      await store.save(_doc('sarah', summary: 'hi'));

      final memoriesDir = Directory('${tempRoot.path}/memories');
      final names = memoriesDir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toList();
      expect(names, contains('sarah.md'));
      expect(names.where((n) => n.endsWith('.md.tmp')), isEmpty);
    });

    test(
      'an orphan .md.tmp from a previous crash is replaced on save',
      () async {
        final store = FileMemoryStore(directoryOverride: tempRoot);
        // First save creates the memories directory.
        await store.save(_doc('sarah', summary: 'first'));

        final memoriesDir = Directory('${tempRoot.path}/memories');
        final orphan = File('${memoriesDir.path}/sarah.md.tmp');
        await orphan.writeAsString('half-written garbage');

        // Save overwrites; rename of the new tmp claims the same path.
        await store.save(_doc('sarah', summary: 'second'));

        final loaded = await store.load('sarah');
        expect(loaded!.summary, 'second');
        // The new save's rename consumes its tmp; the pre-existing
        // orphan from the manual write was replaced by that rename.
        final orphans = memoriesDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.md.tmp'))
            .toList();
        expect(orphans, isEmpty);
      },
    );

    test('listAll skips files whose parsed contactId is empty', () async {
      final store = FileMemoryStore(directoryOverride: tempRoot);
      await store.save(_doc('sarah', summary: 'real one'));

      // Drop a non-memory markdown file alongside the real one.
      final memoriesDir = Directory('${tempRoot.path}/memories');
      await File(
        '${memoriesDir.path}/garbage.md',
      ).writeAsString('no frontmatter here\n## Summary\nnope\n');

      final all = await store.listAll();
      expect(all.keys, ['sarah']);
    });

    test('64KB cap drops oldest history bullets until the doc fits', () async {
      final store = FileMemoryStore(directoryOverride: tempRoot);
      // 100 bullets × ~1KB each = ~100KB of history, well over 64KB.
      final big = _doc('sarah', history: _bulletyHistory(100));
      final inputBulletCount = big.history
          .split('\n')
          .where((l) => l.startsWith('- '))
          .length;
      expect(inputBulletCount, 100);

      await store.save(big);
      final loaded = await store.load('sarah');

      final keptBullets = loaded!.history
          .split('\n')
          .where((l) => l.startsWith('- '))
          .length;
      expect(keptBullets, lessThan(inputBulletCount));
      // The on-disk file fits in the cap.
      final size = await File('${tempRoot.path}/memories/sarah.md').length();
      expect(size, lessThanOrEqualTo(64 * 1024));
    });

    test('64KB cap throws when no history bullets remain and doc still '
        'exceeds the cap', () async {
      final store = FileMemoryStore(directoryOverride: tempRoot);
      final hugeSummary = 'x' * (70 * 1024);
      final pathological = _doc('sarah', summary: hugeSummary);

      await expectLater(
        store.save(pathological),
        throwsA(isA<MemoryCapExceededException>()),
      );
    });

    test(
      'cap-dropped save preserves Topics, Summary, Preferences, Upcoming',
      () async {
        final store = FileMemoryStore(directoryOverride: tempRoot);
        final doc = MemoryDocument(
          contactId: 'sarah',
          displayName: 'Sarah Chen',
          lastUpdated: DateTime.utc(2026, 5, 19),
          summary: 'persistent summary',
          history: _bulletyHistory(100),
          preferences: 'texts on weekends',
          topics: const ['coffee', 'travel'],
          topicSuggestions: [
            TopicSuggestionGroup(
              topic: 'travel',
              lastMentionedAt: DateTime(2026, 5, 19),
              mentionCount: 2,
              suggestions: const [
                TopicSuggestion(
                  kind: TopicSuggestionKind.ask,
                  text: 'Ask how the trip planning is going.',
                ),
              ],
            ),
          ],
          upcoming: [
            UpcomingEntry(
              startDate: DateTime(2026, 6, 1),
              description: 'birthday',
            ),
          ],
        );

        await store.save(doc);
        final loaded = await store.load('sarah');

        expect(loaded!.summary, 'persistent summary');
        expect(loaded.preferences, 'texts on weekends');
        expect(loaded.topics, ['coffee', 'travel']);
        expect(loaded.topicSuggestions, hasLength(1));
        expect(loaded.topicSuggestions.single.topic, 'travel');
        expect(
          loaded.topicSuggestions.single.suggestions.single.text,
          'Ask how the trip planning is going.',
        );
        expect(loaded.upcoming, hasLength(1));
        expect(loaded.upcoming.first.description, 'birthday');
      },
    );
  });

  group('trimToCap (pure)', () {
    test('returns the doc unchanged when already under the cap', () {
      final doc = MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah Chen',
        lastUpdated: DateTime.utc(2026, 5, 19),
        history: '- 2026-05-01 coffee\n- 2026-05-02 lunch',
      );
      final out = trimToCap(doc, capBytes: 64 * 1024);
      expect(out.history, doc.history);
    });

    test('drops oldest bullets first', () {
      final history = [
        '- 2026-05-01 oldest',
        '- 2026-05-02 middle',
        '- 2026-05-03 newest',
      ].join('\n');
      final doc = MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah Chen',
        lastUpdated: DateTime.utc(2026, 5, 19),
        history: history,
      );

      // Force a tiny cap so trimming has to drop bullets to fit.
      final renderedSize = utf8.encode(doc.render()).length;
      final tightCap = renderedSize - 10;
      final out = trimToCap(doc, capBytes: tightCap);

      expect(out.history.contains('oldest'), isFalse);
      expect(out.history.contains('newest'), isTrue);
    });

    test('throws when no history bullets remain and doc still exceeds cap', () {
      final doc = MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah Chen',
        lastUpdated: DateTime.utc(2026, 5, 19),
        summary: 'x' * 1024,
      );
      expect(
        () => trimToCap(doc, capBytes: 100),
        throwsA(isA<MemoryCapExceededException>()),
      );
    });

    test('counts Topic Suggestions toward cap and drops oldest history first', () {
      final history = [
        '- 2026-05-01 oldest',
        '- 2026-05-02 middle',
        '- 2026-05-03 newest',
      ].join('\n');
      final doc = MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah Chen',
        lastUpdated: DateTime.utc(2026, 5, 19),
        history: history,
        topicSuggestions: [
          TopicSuggestionGroup(
            topic: 'Paris trip',
            suggestions: [
              TopicSuggestion(
                kind: TopicSuggestionKind.ask,
                text: 'Ask how planning is going ${'x' * 120}.',
              ),
              TopicSuggestion(
                kind: TopicSuggestionKind.share,
                text: 'Share a café recommendation ${'y' * 120}.',
              ),
              TopicSuggestion(
                kind: TopicSuggestionKind.plan,
                text: 'Plan a quick catch-up ${'z' * 120}.',
              ),
            ],
          ),
        ],
      );
      final capThatFitsOnlyNewest = utf8.encode(
        doc.copyWith(history: '- 2026-05-03 newest').render(),
      ).length;

      final out = trimToCap(doc, capBytes: capThatFitsOnlyNewest);

      expect(out.topicSuggestions, doc.topicSuggestions);
      expect(out.history.contains('oldest'), isFalse);
      expect(out.history.contains('middle'), isFalse);
      expect(out.history.contains('newest'), isTrue);
      expect(
        utf8.encode(out.render()).length,
        lessThanOrEqualTo(capThatFitsOnlyNewest),
      );
    });
  });
}
