import 'package:connect_me/src/ai/memory_topic_enricher.dart';
import 'package:connect_me/src/ai/llm_ai_update_response.dart';
import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MemoryTopicEnricher Merge and Ranking Logic', () {
    test('returned topics are ranked first and respect the cap of 8', () {
      final existing = ['existing1', 'existing2'];
      final gemini = [
        'rank1',
        'rank2',
        'rank3',
        'rank4',
        'rank5',
        'rank6',
        'rank7',
        'rank8',
        'rank9',
      ];

      final merged = LlmMemoryTopicEnricher.mergeTopics(
        existingTopics: existing,
        geminiTopics: gemini,
      );

      // Gemini ranked topics must appear first, up to the cap of 8.
      expect(merged, hasLength(8));
      expect(merged, [
        'rank1',
        'rank2',
        'rank3',
        'rank4',
        'rank5',
        'rank6',
        'rank7',
        'rank8',
      ]);
    });

    test(
      'generic seeded starter topics are removed when better AI-ranked topics are returned',
      () {
        final existing = [
          'family',
          'friends',
          'work',
          'college',
          'high school',
          'non-generic',
        ];
        final gemini = ['pottery', 'gardening'];

        final merged = LlmMemoryTopicEnricher.mergeTopics(
          existingTopics: existing,
          geminiTopics: gemini,
        );

        expect(merged.contains('family'), isFalse);
        expect(merged.contains('friends'), isFalse);
        expect(merged.contains('work'), isFalse);
        expect(merged.contains('college'), isFalse);
        expect(merged.contains('high school'), isFalse);
        expect(merged.contains('non-generic'), isTrue);
        expect(merged, ['pottery', 'gardening', 'non-generic']);
      },
    );

    test(
      'non-generic existing topics are preserved after Gemini topics only if room remains',
      () {
        final existing = ['non-generic1', 'non-generic2', 'non-generic3'];
        final gemini = ['new1', 'new2', 'new3', 'new4', 'new5', 'new6'];

        final merged = LlmMemoryTopicEnricher.mergeTopics(
          existingTopics: existing,
          geminiTopics: gemini,
        );

        expect(merged, hasLength(8));
        expect(merged, [
          'new1',
          'new2',
          'new3',
          'new4',
          'new5',
          'new6',
          'non-generic1',
          'non-generic2',
        ]);
      },
    );

    test('when gemini return is empty, keeps existing topics', () {
      final existing = ['family', 'non-generic'];
      final merged = LlmMemoryTopicEnricher.mergeTopics(
        existingTopics: existing,
        geminiTopics: const [],
      );

      expect(merged, ['family', 'non-generic']);
    });
  });

  group('MemoryTopicEnricher Suggestion Merging', () {
    test('topic suggestions are grouped by selected topic and capped to 3', () {
      final existing = <TopicSuggestionGroup>[];
      final incoming = [
        LlmTopicSuggestionGroup(
          topic: 'pottery',
          suggestions: const [
            LlmTopicSuggestion(kind: LlmTopicSuggestionKind.ask, text: 'S1'),
            LlmTopicSuggestion(kind: LlmTopicSuggestionKind.share, text: 'S2'),
            LlmTopicSuggestion(kind: LlmTopicSuggestionKind.plan, text: 'S3'),
            LlmTopicSuggestion(
              kind: LlmTopicSuggestionKind.remember,
              text: 'S4',
            ),
          ],
        ),
      ];

      final merged = LlmMemoryTopicEnricher.mergeTopicSuggestions(
        existing: existing,
        incoming: incoming,
        mergedTopics: ['pottery'],
        now: DateTime.utc(2026, 6, 13),
      );

      expect(merged, hasLength(1));
      expect(merged.first.topic, 'pottery');
      expect(merged.first.suggestions, hasLength(3));
      expect(merged.first.suggestions[0].text, 'S1');
      expect(merged.first.suggestions[1].text, 'S2');
      expect(merged.first.suggestions[2].text, 'S3');
    });

    test(
      'existing prepared suggestions are preserved when Gemini does not return new ones',
      () {
        final existing = [
          const TopicSuggestionGroup(
            topic: 'pottery',
            suggestions: [
              TopicSuggestion(
                kind: TopicSuggestionKind.ask,
                text: 'Preserved S1',
              ),
            ],
          ),
        ];
        final incoming = <LlmTopicSuggestionGroup>[];

        final merged = LlmMemoryTopicEnricher.mergeTopicSuggestions(
          existing: existing,
          incoming: incoming,
          mergedTopics: ['pottery'],
          now: DateTime.utc(2026, 6, 13),
        );

        expect(merged, hasLength(1));
        expect(merged.first.topic, 'pottery');
        expect(merged.first.suggestions, hasLength(1));
        expect(merged.first.suggestions.first.text, 'Preserved S1');
      },
    );
  });

  group('FakeMemoryTopicEnricher Seam Behavior', () {
    Connection _connection() {
      return Connection(
        id: 'test',
        name: 'Test Person',
        email: 'test@example.com',
        category: 'Friends',
        avatar: '🧑',
        bondScore: 75,
        nextStep: 'Send a hello',
        lastContact: DateTime(2026, 5, 1),
        notes: 'Pre-existing notes',
        knownSince: DateTime(2020, 1, 1),
        preferredChannels: const ['Text'],
      );
    }

    test(
      'enricher does not create CrmInteractions, modify bond score, or append history',
      () async {
        final contact = _connection();
        final memory = MemoryDocument(
          contactId: contact.id,
          displayName: contact.name,
          lastUpdated: DateTime.utc(2026, 6, 1),
          summary: 'Original summary',
          history: '- 2026-06-01 — Talked about pottery.',
        );

        final enricher = FakeMemoryTopicEnricher(
          topicsToReturn: ['gardening'],
          suggestionsToReturn: [
            const LlmTopicSuggestionGroup(
              topic: 'gardening',
              suggestions: [
                LlmTopicSuggestion(
                  kind: LlmTopicSuggestionKind.ask,
                  text: 'Ask about tomatoes',
                ),
              ],
            ),
          ],
        );

        final beforeBond = contact.bondScore;

        final enriched = await enricher.enrich(
          contact: contact,
          currentMemory: memory,
          recentInteractions: const [],
        );

        // Verify returned candidate document changes
        expect(enriched.topics, ['gardening']);
        expect(enriched.topicSuggestions.first.topic, 'gardening');

        // Verify constraints: MemoryDocument fields that should be untouched
        expect(enriched.summary, memory.summary);
        expect(enriched.history, memory.history); // No append to history!

        // Verify no changes to contact bond score (the enricher is constructive/pure)
        expect(contact.bondScore, beforeBond);
      },
    );
  });
}
