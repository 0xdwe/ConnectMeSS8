import 'package:connect_me/src/ai/memory_topic_enricher.dart';
import 'package:connect_me/src/ai/llm_ai_update_response.dart';
import 'package:connect_me/src/state/app_state.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:connect_me/src/state/memory/memory_topic_backfill_runner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_overrides.dart';

class _RecordingBackfillSentinel implements BackfillSentinel {
  bool _set = false;
  final List<DateTime> setCalls = [];

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

void main() {
  group('MemoryTopicBackfillRunner', () {
    test(
      'skips contacts with no useful memory text and no recent interactions',
      () async {
        final store = InMemoryMemoryStore();

        final container = ProviderContainer(
          overrides: [
            ...signedInDemoOverrides(),
            memoryStoreProvider.overrideWithValue(store),
          ],
        );
        addTearDown(container.dispose);

        // David has context text, Jessica has none and no interactions.
        final davidMemory = MemoryDocument(
          contactId: 'david',
          displayName: 'David Kim',
          lastUpdated: DateTime.utc(2026, 6, 1),
          summary: 'David has some context text',
        );
        final jessicaMemory = MemoryDocument(
          contactId: 'jessica',
          displayName: 'Jessica Taylor',
          lastUpdated: DateTime.utc(2026, 6, 1),
          summary: '', // blank
        );
        await store.save(davidMemory);
        await store.save(jessicaMemory);

        final sentinel = _RecordingBackfillSentinel();
        final enricher = FakeMemoryTopicEnricher(
          topicsToReturn: ['gardening'],
          suggestionsToReturn: [
            const LlmTopicSuggestionGroup(
              topic: 'gardening',
              suggestions: [
                LlmTopicSuggestion(
                  kind: LlmTopicSuggestionKind.ask,
                  text: 'tomato check',
                ),
              ],
            ),
          ],
        );

        final runner = MemoryTopicBackfillRunner(
          store: store,
          enricher: enricher,
          sentinel: sentinel,
          appState: container.read(appControllerProvider),
          clock: () => DateTime.utc(2026, 6, 13),
        );

        await runner.runBackfill();

        // David should be enriched (since he has useful memory text)
        final davidEnriched = await store.load('david');
        expect(davidEnriched!.topics, ['gardening']);

        // Jessica should be skipped (blank memory summary and no interactions)
        final jessicaEnriched = await store.load('jessica');
        expect(jessicaEnriched!.topics, isEmpty);

        // Sentinel should still be set since Jessica was legally skipped
        expect(sentinel._set, isTrue);
      },
    );

    test('skips contacts already possessing prepared suggestions', () async {
      final store = InMemoryMemoryStore();

      final container = ProviderContainer(
        overrides: [
          ...signedInDemoOverrides(),
          memoryStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);

      final davidMemory = MemoryDocument(
        contactId: 'david',
        displayName: 'David Kim',
        lastUpdated: DateTime.utc(2026, 6, 1),
        summary: 'context',
        topics: const ['pottery'],
        topicSuggestions: const [
          TopicSuggestionGroup(
            topic: 'pottery',
            suggestions: [
              TopicSuggestion(
                kind: TopicSuggestionKind.ask,
                text: 'ask question',
              ),
            ],
          ),
        ],
      );
      await store.save(davidMemory);

      final sentinel = _RecordingBackfillSentinel();
      final enricher = FakeMemoryTopicEnricher(
        topicsToReturn: ['gardening'],
        suggestionsToReturn: [
          const LlmTopicSuggestionGroup(
            topic: 'gardening',
            suggestions: [
              LlmTopicSuggestion(
                kind: LlmTopicSuggestionKind.ask,
                text: 'tomato check',
              ),
            ],
          ),
        ],
      );

      final runner = MemoryTopicBackfillRunner(
        store: store,
        enricher: enricher,
        sentinel: sentinel,
        appState: container.read(appControllerProvider),
        clock: () => DateTime.utc(2026, 6, 13),
      );

      await runner.runBackfill();

      // David should NOT be enriched because he already has prepared suggestions.
      final davidLoaded = await store.load('david');
      expect(davidLoaded!.topics, ['pottery']);
      expect(sentinel._set, isTrue);
    });

    test('if any eligible contact fails, does not write sentinel', () async {
      final store = InMemoryMemoryStore();

      final container = ProviderContainer(
        overrides: [
          ...signedInDemoOverrides(),
          memoryStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);

      final davidMemory = MemoryDocument(
        contactId: 'david',
        displayName: 'David Kim',
        lastUpdated: DateTime.utc(2026, 6, 1),
        summary: 'context',
      );
      await store.save(davidMemory);

      final sentinel = _RecordingBackfillSentinel();
      final enricher = FakeMemoryTopicEnricher(
        topicsToReturn: ['gardening'],
        suggestionsToReturn: const [],
        failOnNetwork: true, // triggers exception
      );

      final runner = MemoryTopicBackfillRunner(
        store: store,
        enricher: enricher,
        sentinel: sentinel,
        appState: container.read(appControllerProvider),
        clock: () => DateTime.utc(2026, 6, 13),
      );

      await runner.runBackfill();

      // David failed, so topics should be empty
      final davidLoaded = await store.load('david');
      expect(davidLoaded!.topics, isEmpty);

      // Sentinel should NOT be written
      expect(sentinel._set, isFalse);
    });

    test('no-ops if sentinel is already set', () async {
      final store = InMemoryMemoryStore();

      final container = ProviderContainer(
        overrides: [
          ...signedInDemoOverrides(),
          memoryStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);

      final davidMemory = MemoryDocument(
        contactId: 'david',
        displayName: 'David Kim',
        lastUpdated: DateTime.utc(2026, 6, 1),
        summary: 'context',
      );
      await store.save(davidMemory);

      final sentinel = _RecordingBackfillSentinel()..preset();
      final enricher = FakeMemoryTopicEnricher(
        topicsToReturn: ['gardening'],
        suggestionsToReturn: const [],
      );

      final runner = MemoryTopicBackfillRunner(
        store: store,
        enricher: enricher,
        sentinel: sentinel,
        appState: container.read(appControllerProvider),
        clock: () => DateTime.utc(2026, 6, 13),
      );

      await runner.runBackfill();

      // Should bypass the run completely, so topics remains empty
      final davidLoaded = await store.load('david');
      expect(davidLoaded!.topics, isEmpty);
    });
  });
}
