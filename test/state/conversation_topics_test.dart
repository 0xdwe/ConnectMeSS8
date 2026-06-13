import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/conversation_topics.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:flutter_test/flutter_test.dart';

Connection _connection({
  String id = 'mike',
  String name = 'Mike Chen',
  String category = 'Work',
}) {
  return Connection(
    id: id,
    name: name,
    email: 'test@example.com',
    category: category,
    avatar: '🧑',
    bondScore: 70,
    nextStep: 'Send a casual hello',
    lastContact: DateTime(2026, 5, 1),
    notes: '',
    knownSince: DateTime(2020, 1, 1),
    preferredChannels: const ['Text'],
  );
}

MemoryDocument _memory({
  String contactId = 'mike',
  String displayName = 'Mike Chen',
  List<String> topics = const [],
  List<TopicSuggestionGroup> topicSuggestions = const [],
}) {
  return MemoryDocument(
    contactId: contactId,
    displayName: displayName,
    lastUpdated: DateTime.utc(2026, 5, 19),
    topics: topics,
    topicSuggestions: topicSuggestions,
  );
}

void main() {
  group('topicsForContact', () {
    test('returns category defaults when memory is null', () {
      final topics = topicsForContact(_connection(category: 'Work'), null);
      expect(topics, ['Projects', 'Career', 'Industry news', 'Team updates']);
    });

    test('returns category defaults when memory.topics is empty', () {
      final topics = topicsForContact(
        _connection(category: 'Work'),
        _memory(topics: const []),
      );
      expect(topics, ['Projects', 'Career', 'Industry news', 'Team updates']);
    });

    test('returns memory.topics when present, capped at 4', () {
      final topics = topicsForContact(
        _connection(category: 'Work'),
        _memory(
          topics: const [
            'promotion',
            'startup',
            'wedding',
            'marathon',
            'birthday',
            'house',
          ],
        ),
      );
      expect(topics, ['promotion', 'startup', 'wedding', 'marathon']);
    });

    test('returns memory.topics unchanged when fewer than 4', () {
      final topics = topicsForContact(
        _connection(category: 'Family'),
        _memory(topics: const ['baby']),
      );
      expect(topics, ['baby']);
    });

    test('falls back to generic defaults for an unknown category', () {
      final topics = topicsForContact(_connection(category: 'Mystery'), null);
      expect(topics, [
        'Recent updates',
        'Shared interests',
        'Life events',
        'Future plans',
      ]);
    });

    test('returned list is unmodifiable (cannot mutate the static map)', () {
      final topics = topicsForContact(_connection(category: 'Work'), null);
      // Lists from List.toList(growable: false) cannot grow.
      expect(() => topics.add('extra'), throwsUnsupportedError);
    });
  });

  group('preferredSuggestionsForTopic', () {
    test('prefers prepared non-expired Topic Suggestions from memory', () {
      final suggestions = preferredSuggestionsForTopic(
        category: 'Friends',
        topic: 'Paris trip',
        contactName: 'Sarah Chen',
        memory: _memory(
          topics: const ['Paris trip'],
          topicSuggestions: [
            TopicSuggestionGroup(
              topic: 'Paris trip',
              lastMentionedAt: DateTime.utc(2026, 6, 4),
              mentionCount: 2,
              suggestions: const [
                TopicSuggestion(
                  kind: TopicSuggestionKind.ask,
                  text: 'Ask how the Paris plans are coming together.',
                ),
                TopicSuggestion(
                  kind: TopicSuggestionKind.share,
                  text: 'Send a café rec if you spot one.',
                ),
              ],
            ),
          ],
        ),
        now: DateTime.utc(2026, 6, 5),
      );

      expect(suggestions, [
        const TopicSuggestion(
          kind: TopicSuggestionKind.ask,
          text: 'Ask how the Paris plans are coming together.',
        ),
        const TopicSuggestion(
          kind: TopicSuggestionKind.share,
          text: 'Send a café rec if you spot one.',
        ),
      ]);
    });

    test('falls back to deterministic suggestions when prepared missing', () {
      final suggestions = preferredSuggestionsForTopic(
        category: 'Friends',
        topic: 'kindergarten',
        contactName: 'Sarah Chen',
        memory: _memory(topics: const ['kindergarten']),
        now: DateTime.utc(2026, 6, 5),
      );

      expect(suggestions, [
        const TopicSuggestion(
          kind: TopicSuggestionKind.ask,
          text: "How's the kindergarten going?",
        ),
        const TopicSuggestion(
          kind: TopicSuggestionKind.ask,
          text: 'Last time you mentioned kindergarten \u2014 anything new?',
        ),
        const TopicSuggestion(
          kind: TopicSuggestionKind.ask,
          text: "Curious how Sarah's kindergarten is going.",
        ),
      ]);
    });

    test('drops blank prepared suggestions and caps at three', () {
      final suggestions = preferredSuggestionsForTopic(
        category: 'Friends',
        topic: 'Paris trip',
        contactName: 'Sarah Chen',
        memory: _memory(
          topics: const ['Paris trip'],
          topicSuggestions: [
            TopicSuggestionGroup(
              topic: 'Paris trip',
              suggestions: const [
                TopicSuggestion(kind: TopicSuggestionKind.ask, text: '  '),
                TopicSuggestion(kind: TopicSuggestionKind.ask, text: 'First.'),
                TopicSuggestion(
                  kind: TopicSuggestionKind.share,
                  text: 'Second.',
                ),
                TopicSuggestion(kind: TopicSuggestionKind.plan, text: 'Third.'),
                TopicSuggestion(
                  kind: TopicSuggestionKind.remember,
                  text: 'Fourth should not surface.',
                ),
              ],
            ),
          ],
        ),
        now: DateTime.utc(2026, 6, 5),
      );

      expect(suggestions, [
        const TopicSuggestion(kind: TopicSuggestionKind.ask, text: 'First.'),
        const TopicSuggestion(kind: TopicSuggestionKind.share, text: 'Second.'),
        const TopicSuggestion(kind: TopicSuggestionKind.plan, text: 'Third.'),
      ]);
    });

    test('falls back when prepared suggestions are blank after trimming', () {
      final suggestions = preferredSuggestionsForTopic(
        category: 'Friends',
        topic: 'Paris trip',
        contactName: 'Sarah Chen',
        memory: _memory(
          topics: const ['Paris trip'],
          topicSuggestions: [
            TopicSuggestionGroup(
              topic: 'Paris trip',
              suggestions: const [
                TopicSuggestion(kind: TopicSuggestionKind.ask, text: '  '),
              ],
            ),
          ],
        ),
        now: DateTime.utc(2026, 6, 5),
      );

      expect(suggestions, [
        const TopicSuggestion(
          kind: TopicSuggestionKind.ask,
          text: "How's the Paris trip going?",
        ),
        const TopicSuggestion(
          kind: TopicSuggestionKind.ask,
          text: 'Last time you mentioned Paris trip \u2014 anything new?',
        ),
        const TopicSuggestion(
          kind: TopicSuggestionKind.ask,
          text: "Curious how Sarah's Paris trip is going.",
        ),
      ]);
    });

    test('falls back to deterministic suggestions when prepared expired', () {
      final suggestions = preferredSuggestionsForTopic(
        category: 'Friends',
        topic: 'Paris trip',
        contactName: 'Sarah Chen',
        memory: _memory(
          topics: const ['Paris trip'],
          topicSuggestions: [
            TopicSuggestionGroup(
              topic: 'Paris trip',
              expiresAt: DateTime.utc(2026, 6, 1),
              suggestions: const [
                TopicSuggestion(
                  kind: TopicSuggestionKind.ask,
                  text: 'Ask how the Paris plans are coming together.',
                ),
              ],
            ),
          ],
        ),
        now: DateTime.utc(2026, 6, 5),
      );

      expect(suggestions, [
        const TopicSuggestion(
          kind: TopicSuggestionKind.ask,
          text: "How's the Paris trip going?",
        ),
        const TopicSuggestion(
          kind: TopicSuggestionKind.ask,
          text: 'Last time you mentioned Paris trip \u2014 anything new?',
        ),
        const TopicSuggestion(
          kind: TopicSuggestionKind.ask,
          text: "Curious how Sarah's Paris trip is going.",
        ),
      ]);
    });
  });

  group('suggestionsForTopic', () {
    test('returns the curated suggestions for a known (category, topic)', () {
      final suggestions = suggestionsForTopic('Work', 'Projects', 'Mike Chen');
      expect(suggestions, [
        'Ask what they\'re working on',
        'Share a recent project win',
        'Trade notes on a tough problem',
      ]);
    });

    test('curated-map hit wins over the templated fallback', () {
      // Sanity check: even when contactName would otherwise drive a
      // distinct templated render, a curated hit short-circuits.
      final a = suggestionsForTopic('Family', 'Family updates', 'Alice');
      final b = suggestionsForTopic('Family', 'Family updates', 'Bob');
      expect(a, b);
      expect(a.first, 'Ask how the family is doing');
    });

    test(
      'returns templated fallback when topic is missing from the curated map',
      () {
        final suggestions = suggestionsForTopic(
          'Friends',
          'kindergarten',
          'Sarah Chen',
        );
        expect(suggestions, [
          "How's the kindergarten going?",
          'Last time you mentioned kindergarten \u2014 anything new?',
          "Curious how Sarah's kindergarten is going.",
        ]);
      },
    );

    test('templated fallback also fires for an unknown category', () {
      final suggestions = suggestionsForTopic(
        'UnknownCategory',
        'violin',
        'Mike Chen',
      );
      expect(suggestions, [
        "How's the violin going?",
        'Last time you mentioned violin \u2014 anything new?',
        "Curious how Mike's violin is going.",
      ]);
    });

    test('templated fallback uses the first whitespace-split token only', () {
      final suggestions = suggestionsForTopic('Friends', 'violin', 'Mike Chen');
      expect(suggestions, contains("Curious how Mike's violin is going."));
      expect(
        suggestions,
        isNot(contains("Curious how Mike Chen's violin is going.")),
      );
    });

    test('single-name contact uses the whole name as the first name', () {
      final suggestions = suggestionsForTopic('Friends', 'pottery', 'Mike');
      expect(suggestions, contains("Curious how Mike's pottery is going."));
    });

    test('contactName with surrounding whitespace is trimmed before split', () {
      final suggestions = suggestionsForTopic(
        'Friends',
        'climbing',
        '  Sarah  Chen  ',
      );
      expect(suggestions, contains("Curious how Sarah's climbing is going."));
    });

    test('topic with surrounding whitespace is trimmed before rendering', () {
      final suggestions = suggestionsForTopic(
        'Friends',
        '  violin  ',
        'Sarah Chen',
      );
      expect(suggestions, [
        "How's the violin going?",
        'Last time you mentioned violin \u2014 anything new?',
        "Curious how Sarah's violin is going.",
      ]);
    });

    test('empty topic falls back to the generic three-line list', () {
      final suggestions = suggestionsForTopic('Friends', '', 'Sarah Chen');
      expect(suggestions, [
        'Ask an open question about how they\'ve been',
        'Share a recent update from your own life',
        'Suggest meeting up',
      ]);
    });

    test('whitespace-only topic falls back to the generic list', () {
      final suggestions = suggestionsForTopic('Friends', '   ', 'Sarah Chen');
      expect(suggestions, [
        'Ask an open question about how they\'ve been',
        'Share a recent update from your own life',
        'Suggest meeting up',
      ]);
    });

    test('empty contactName falls back to the generic list', () {
      final suggestions = suggestionsForTopic('Friends', 'pottery', '');
      expect(suggestions, [
        'Ask an open question about how they\'ve been',
        'Share a recent update from your own life',
        'Suggest meeting up',
      ]);
    });

    test('whitespace-only contactName falls back to the generic list', () {
      final suggestions = suggestionsForTopic('Friends', 'pottery', '   ');
      expect(suggestions, [
        'Ask an open question about how they\'ve been',
        'Share a recent update from your own life',
        'Suggest meeting up',
      ]);
    });
  });
}
