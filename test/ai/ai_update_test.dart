import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/app_state.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container({InMemoryMemoryStore? store}) {
  final memoryStore = store ?? InMemoryMemoryStore();
  return ProviderContainer(overrides: [
    memoryStoreProvider.overrideWithValue(memoryStore),
  ]);
}

Connection _connection(AppState state, String id) =>
    state.connections.firstWhere((c) => c.id == id);

void main() {
  group('MockAiUpdate.run', () {
    test('produces an interaction with the categorized type and AI source',
        () async {
      final container = _container();
      addTearDown(container.dispose);

      final mike = _connection(container.read(appControllerProvider), 'mike');
      final memory = await container.read(memoryProvider('mike').future);

      final result = await container.read(aiUpdateProvider).run(
            contact: mike,
            userInput: 'Remember to follow up with Mike next week.',
            currentMemory: memory,
            attachments: const [],
          );

      expect(result.interactions, hasLength(1));
      final interaction = result.interactions.single;
      expect(interaction.contactId, 'mike');
      expect(interaction.type, InteractionType.reminder);
      expect(interaction.title, 'Follow-up reminder created');
      expect(interaction.source, InteractionSource.aiSuggested);
      expect(result.contactId, 'mike');
      expect(result.summary, isNotEmpty);
    });

    test('appends a date-stamped bullet to memory.history', () async {
      final container = _container();
      addTearDown(container.dispose);

      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      final memory = await container.read(memoryProvider('sarah').future);
      expect(memory.history, isEmpty);

      final result = await container.read(aiUpdateProvider).run(
            contact: sarah,
            userInput: 'Coffee at the new place on Main Street.',
            currentMemory: memory,
            attachments: const [],
          );

      final newMemory = result.memoryDocument!;
      expect(newMemory.history, isNotEmpty);
      // Bullet shape: "- YYYY-MM-DD — <input>".
      expect(newMemory.history, startsWith('- '));
      expect(newMemory.history, contains(' — '));
      expect(newMemory.history,
          contains('Coffee at the new place on Main Street.'));
      // Date stamp matches today (yyyy-mm-dd).
      final today = DateTime.now();
      final stamp =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      expect(newMemory.history, contains(stamp));
    });

    test('two runs with the same input produce structurally identical output',
        () async {
      final container = _container();
      addTearDown(container.dispose);

      final mike = _connection(container.read(appControllerProvider), 'mike');
      final memory = await container.read(memoryProvider('mike').future);

      final adapter = container.read(aiUpdateProvider);
      final a = await adapter.run(
        contact: mike,
        userInput: 'Birthday next week, get a card.',
        currentMemory: memory,
        attachments: const [],
      );
      final b = await adapter.run(
        contact: mike,
        userInput: 'Birthday next week, get a card.',
        currentMemory: memory,
        attachments: const [],
      );

      // Determinism: type, title, note, source identical (modulo IDs
      // and timestamps).
      expect(a.interactions.single.type, b.interactions.single.type);
      expect(a.interactions.single.title, b.interactions.single.title);
      expect(a.interactions.single.note, b.interactions.single.note);
      expect(a.interactions.single.source, b.interactions.single.source);
      expect(a.summary, b.summary);

      // Memory history bodies match modulo the date stamp; since both
      // ran in the same millisecond bucket, they should be identical.
      expect(a.memoryDocument!.history, b.memoryDocument!.history);
    });

    test('a second run on a memory with prior history appends rather than overwrites',
        () async {
      final container = _container();
      addTearDown(container.dispose);

      final mike = _connection(container.read(appControllerProvider), 'mike');
      final memory = await container.read(memoryProvider('mike').future);

      final adapter = container.read(aiUpdateProvider);
      final first = await adapter.run(
        contact: mike,
        userInput: 'First update — coffee yesterday.',
        currentMemory: memory,
        attachments: const [],
      );

      final second = await adapter.run(
        contact: mike,
        userInput: 'Second update — dinner tonight.',
        currentMemory: first.memoryDocument!,
        attachments: const [],
      );

      final history = second.memoryDocument!.history;
      expect(history, contains('First update'));
      expect(history, contains('Second update'));
      // Two bullets — exactly two newlines splitting two non-empty
      // lines (both starting with `- `).
      final bullets = history.split('\n').where((l) => l.startsWith('- ')).toList();
      expect(bullets, hasLength(2));
    });

    test('preview-then-commit two-step persists memory and applies state delta',
        () async {
      final store = InMemoryMemoryStore();
      final container = _container(store: store);
      addTearDown(container.dispose);

      final beforeInteractions =
          container.read(appControllerProvider).interactions.length;
      final mike = _connection(container.read(appControllerProvider), 'mike');
      final beforeBond = mike.bondScore;

      final memory = await container.read(memoryProvider('mike').future);

      final adapter = container.read(aiUpdateProvider);
      final result = await adapter.run(
        contact: mike,
        userInput: 'Sent Mike a follow-up email about the job application.',
        currentMemory: memory,
        attachments: const [],
      );

      // Pre-commit: store still has the empty seeded doc.
      expect((await store.load('mike'))!.history, isEmpty);
      expect(
        container.read(appControllerProvider).interactions.length,
        beforeInteractions,
      );

      await adapter.commit(result);

      // Post-commit: store carries the new history bullet.
      final stored = await store.load('mike');
      expect(stored, isNotNull);
      expect(stored!.history, contains('Sent Mike a follow-up email'));

      // State delta applied: interaction appended, bond bumped.
      final afterState = container.read(appControllerProvider);
      expect(afterState.interactions.length, beforeInteractions + 1);
      expect(afterState.lastAiSummary, isNotNull);
      final updatedMike = _connection(afterState, 'mike');
      expect(updatedMike.bondScore, greaterThan(beforeBond));
    });

    test('cancel — run produces a result, commit is never called, store is untouched',
        () async {
      final store = InMemoryMemoryStore();
      // Seed a known memory the test will assert is unchanged.
      await store.save(MemoryDocument(
        contactId: 'mike',
        displayName: 'Mike Chen',
        lastUpdated: DateTime.utc(2026, 5, 19),
        summary: 'pre-cancel summary',
        history: '- 2026-05-01 — already there',
      ));

      final container = _container(store: store);
      addTearDown(container.dispose);

      final beforeInteractions =
          container.read(appControllerProvider).interactions.length;
      final mike = _connection(container.read(appControllerProvider), 'mike');
      final beforeMemory = await container.read(memoryProvider('mike').future);

      // Run produces a candidate, we discard it (simulating cancel).
      final result = await container.read(aiUpdateProvider).run(
            contact: mike,
            userInput: 'This will be cancelled.',
            currentMemory: beforeMemory,
            attachments: const [],
          );
      expect(result.memoryDocument!.history, contains('This will be cancelled.'));

      // No commit. The store and the state must be untouched.
      final storedAfter = await store.load('mike');
      expect(storedAfter!.history, '- 2026-05-01 — already there');
      expect(storedAfter.summary, 'pre-cancel summary');
      expect(
        container.read(appControllerProvider).interactions.length,
        beforeInteractions,
      );
    });

    test('empty user input falls back to attachment-count note', () async {
      final container = _container();
      addTearDown(container.dispose);

      final mike = _connection(container.read(appControllerProvider), 'mike');
      final memory = await container.read(memoryProvider('mike').future);

      final result = await container.read(aiUpdateProvider).run(
            contact: mike,
            userInput: '',
            currentMemory: memory,
            attachments: const [
              AttachmentRef(name: 'a.png', path: '/tmp/a.png'),
              AttachmentRef(name: 'b.png', path: '/tmp/b.png'),
            ],
          );

      expect(result.interactions.single.note, 'AI reviewed 2 attachment(s).');
      expect(result.interactions.single.attachments, hasLength(2));
      expect(result.memoryDocument!.history,
          contains('AI reviewed 2 attachment(s).'));
    });
  });

  group('MockAiUpdate topic extraction', () {
    test('extracts known keywords from user input', () async {
      final container = _container();
      addTearDown(container.dispose);

      final mike = _connection(container.read(appControllerProvider), 'mike');
      final memory = await container.read(memoryProvider('mike').future);

      final result = await container.read(aiUpdateProvider).run(
            contact: mike,
            userInput: 'Had coffee, she got a promotion at her startup.',
            currentMemory: memory,
            attachments: const [],
          );

      final topics = result.memoryDocument!.topics;
      expect(topics, contains('promotion'));
      expect(topics, contains('startup'));
    });

    test('dedupes topics case-insensitively, existing entry wins', () async {
      final store = InMemoryMemoryStore();
      // Pre-seed memory with 'Promotion' (capitalized) so that an
      // input mentioning 'promotion' would otherwise create a duplicate.
      await store.save(MemoryDocument(
        contactId: 'mike',
        displayName: 'Mike Chen',
        lastUpdated: DateTime.utc(2026, 5, 19),
        topics: const ['Promotion'],
      ));

      final container = _container(store: store);
      addTearDown(container.dispose);

      final mike = _connection(container.read(appControllerProvider), 'mike');
      final memory = await container.read(memoryProvider('mike').future);

      final result = await container.read(aiUpdateProvider).run(
            contact: mike,
            userInput: 'She got a promotion last week.',
            currentMemory: memory,
            attachments: const [],
          );

      final topics = result.memoryDocument!.topics;
      // Existing 'Promotion' kept; lowercase 'promotion' is not added.
      expect(topics, ['Promotion']);
    });

    test('caps topics at 8 with oldest-first eviction', () async {
      final store = InMemoryMemoryStore();
      // Pre-seed memory with 8 topics, none of which match the input
      // keyword so the merge has to evict the oldest.
      await store.save(MemoryDocument(
        contactId: 'mike',
        displayName: 'Mike Chen',
        lastUpdated: DateTime.utc(2026, 5, 19),
        topics: const [
          'oldest',
          'two',
          'three',
          'four',
          'five',
          'six',
          'seven',
          'eight',
        ],
      ));

      final container = _container(store: store);
      addTearDown(container.dispose);

      final mike = _connection(container.read(appControllerProvider), 'mike');
      final memory = await container.read(memoryProvider('mike').future);

      final result = await container.read(aiUpdateProvider).run(
            contact: mike,
            // Single keyword. Phrasing is chosen to avoid incidental
            // substring hits like 'art' inside 'quarter' under PRD-Q7
            // substring matching.
            userInput: 'Mike got a promotion this week.',
            currentMemory: memory,
            attachments: const [],
          );

      final topics = result.memoryDocument!.topics;
      // One new keyword merged; oldest pre-existing topic evicted to
      // keep the cap at 8.
      expect(topics.length, MemoryDocument.topicCap);
      expect(topics, isNot(contains('oldest')));
      expect(topics.first, 'two');
      expect(topics.last, 'promotion');
    });

    test('topic order is deterministic across runs', () async {
      final container = _container();
      addTearDown(container.dispose);

      final mike = _connection(container.read(appControllerProvider), 'mike');
      final memory = await container.read(memoryProvider('mike').future);

      final adapter = container.read(aiUpdateProvider);
      // 'birthday' first in the input, 'promotion' second; the
      // extractor must still emit them in keyword-list order
      // (career cluster before milestones), not input order.
      const input = 'Got a birthday card and a promotion.';
      final a = await adapter.run(
        contact: mike,
        userInput: input,
        currentMemory: memory,
        attachments: const [],
      );
      final b = await adapter.run(
        contact: mike,
        userInput: input,
        currentMemory: memory,
        attachments: const [],
      );

      expect(a.memoryDocument!.topics, b.memoryDocument!.topics);
      expect(a.memoryDocument!.topics, ['promotion', 'birthday']);
    });

    test('input with no keywords leaves topics unchanged', () async {
      final store = InMemoryMemoryStore();
      await store.save(MemoryDocument(
        contactId: 'mike',
        displayName: 'Mike Chen',
        lastUpdated: DateTime.utc(2026, 5, 19),
        topics: const ['existing-topic'],
      ));

      final container = _container(store: store);
      addTearDown(container.dispose);

      final mike = _connection(container.read(appControllerProvider), 'mike');
      final memory = await container.read(memoryProvider('mike').future);

      final result = await container.read(aiUpdateProvider).run(
            contact: mike,
            userInput: 'just chatting, nothing special to mention',
            currentMemory: memory,
            attachments: const [],
          );

      expect(result.memoryDocument!.topics, ['existing-topic']);
    });
  });
}
