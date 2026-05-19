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
}) {
  return MemoryDocument(
    contactId: contactId,
    displayName: displayName,
    lastUpdated: DateTime.utc(2026, 5, 19),
    topics: topics,
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
        _memory(topics: const [
          'promotion',
          'startup',
          'wedding',
          'marathon',
          'birthday',
          'house',
        ]),
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
      final topics = topicsForContact(
        _connection(category: 'Mystery'),
        null,
      );
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

  group('suggestionsForTopic', () {
    test('returns the curated suggestions for a known (category, topic)', () {
      final suggestions =
          suggestionsForTopic('Work', 'Projects', 'Mike Chen');
      expect(suggestions, [
        'Ask what they\'re working on',
        'Share a recent project win',
        'Trade notes on a tough problem',
      ]);
    });

    test('returns generic suggestions for an unknown category', () {
      // Templated fallback for memory-extracted topics is #044.
      final suggestions =
          suggestionsForTopic('UnknownCategory', 'whatever', 'Sam');
      expect(suggestions, [
        'Ask an open question about how they\'ve been',
        'Share a recent update from your own life',
        'Suggest meeting up',
      ]);
    });

    test('returns generic suggestions for an unknown topic in a known category',
        () {
      final suggestions =
          suggestionsForTopic('Work', 'promotion', 'Mike Chen');
      expect(suggestions, [
        'Ask an open question about how they\'ve been',
        'Share a recent update from your own life',
        'Suggest meeting up',
      ]);
    });

    test('contactName is accepted but does not change static-map output', () {
      // Per #043, contactName is wired through but not yet consumed.
      // The templated {firstName} fallback lands in #044.
      final a = suggestionsForTopic('Family', 'Family updates', 'Alice');
      final b = suggestionsForTopic('Family', 'Family updates', 'Bob');
      expect(a, b);
    });
  });
}
