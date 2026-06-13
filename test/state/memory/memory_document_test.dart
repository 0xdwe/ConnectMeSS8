import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MemoryDocument.parse', () {
    test('round-trips a fully populated document', () {
      final original = MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah Johnson',
        lastUpdated: DateTime.utc(2026, 5, 19, 12, 30, 0),
        version: 1,
        summary: 'Long-time friend who loves coffee.',
        history: 'Met in 2020. Coffee in April.',
        preferences: 'Texts work best on weekends.',
        topics: const ['coffee', 'travel', 'music'],
        topicSuggestions: [
          TopicSuggestionGroup(
            topic: 'travel',
            lastMentionedAt: DateTime(2026, 5, 19),
            mentionCount: 2,
            expiresAt: DateTime(2026, 6, 1),
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
        upcoming: [
          UpcomingEntry(
            startDate: DateTime(2026, 5, 19),
            description: 'birthday lunch',
          ),
          UpcomingEntry(
            startDate: DateTime(2026, 5, 19),
            endDate: DateTime(2026, 5, 26),
            description: 'USA trip',
          ),
        ],
      );

      final parsed = MemoryDocument.parse(original.render());

      expect(parsed.contactId, original.contactId);
      expect(parsed.displayName, original.displayName);
      expect(parsed.version, original.version);
      expect(parsed.summary, original.summary);
      expect(parsed.history, original.history);
      expect(parsed.preferences, original.preferences);
      expect(parsed.topics, original.topics);
      expect(parsed.topicSuggestions, original.topicSuggestions);
      expect(parsed.upcoming, original.upcoming);
      expect(parsed.parseErrors, isEmpty);
      // lastUpdated round-trips at ISO-8601 second precision.
      expect(
        parsed.lastUpdated.toIso8601String(),
        original.lastUpdated.toIso8601String(),
      );
    });

    test('missing optional sections parse without error', () {
      const raw = '''---
contactId: 'mike'
displayName: 'Mike Chen'
lastUpdated: '2026-05-19T00:00:00.000Z'
version: 1
---

## Summary
Just a summary.

## History
A line of history.

## Topics
- school
''';

      final doc = MemoryDocument.parse(raw);

      expect(doc.parseErrors, isEmpty);
      expect(doc.summary, 'Just a summary.');
      expect(doc.history, 'A line of history.');
      expect(doc.preferences, '');
      expect(doc.upcoming, isEmpty);
      expect(doc.topics, ['school']);
      expect(doc.topicSuggestions, isEmpty);
    });

    test(
      'parses Topic Suggestions section with metadata and capped suggestions',
      () {
        const raw = '''---
contactId: 'sarah'
displayName: 'Sarah Johnson'
lastUpdated: '2026-05-19T00:00:00.000Z'
version: 1
---

## Topics
- Paris trip

## Topic Suggestions

### Paris trip
lastMentionedAt: 2026-06-04
mentionCount: 2
expiresAt: 2026-06-20
- ask: Ask how the Paris plans are coming together.
- share: Send a café rec if you spot one.
- plan: Suggest a quick call before the trip.
- remember: This fourth suggestion is dropped.
''';

        final doc = MemoryDocument.parse(raw);

        expect(doc.parseErrors, isEmpty);
        expect(doc.topicSuggestions, hasLength(1));
        final group = doc.topicSuggestions.single;
        expect(group.topic, 'Paris trip');
        expect(group.lastMentionedAt, DateTime(2026, 6, 4));
        expect(group.mentionCount, 2);
        expect(group.expiresAt, DateTime(2026, 6, 20));
        expect(group.suggestions, hasLength(3));
        expect(group.suggestions.first.kind, TopicSuggestionKind.ask);
        expect(
          group.suggestions.first.text,
          'Ask how the Paris plans are coming together.',
        );
      },
    );

    test(
      'parses and renders Topic Suggestions with context',
      () {
        const raw = '''---
contactId: 'sarah'
displayName: 'Sarah Johnson'
lastUpdated: '2026-05-19T00:00:00.000Z'
version: 1
---

## Topic Suggestions

### Paris trip
- ask: Ask how the Paris plans are coming together. | he talked about his plan to Paris last time and he was very excited about it
- share: Send a café rec if you spot one.
''';

        final doc = MemoryDocument.parse(raw);

        expect(doc.parseErrors, isEmpty);
        expect(doc.topicSuggestions, hasLength(1));
        final group = doc.topicSuggestions.single;
        expect(group.suggestions, hasLength(2));
        expect(group.suggestions.first.kind, TopicSuggestionKind.ask);
        expect(
          group.suggestions.first.text,
          'Ask how the Paris plans are coming together.',
        );
        expect(
          group.suggestions.first.context,
          'he talked about his plan to Paris last time and he was very excited about it',
        );
        expect(group.suggestions.last.kind, TopicSuggestionKind.share);
        expect(group.suggestions.last.text, 'Send a café rec if you spot one.');
        expect(group.suggestions.last.context, isNull);

        final rendered = doc.render();
        expect(
          rendered,
          contains(
            '- ask: Ask how the Paris plans are coming together. | he talked about his plan to Paris last time and he was very excited about it',
          ),
        );
        expect(rendered, contains('- share: Send a café rec if you spot one.'));
      },
    );

    test(
      'malformed Topic Suggestions lines are ignored without parse errors',
      () {
        const raw = '''---
contactId: 'sarah'
displayName: 'Sarah Johnson'
lastUpdated: '2026-05-19T00:00:00.000Z'
version: 1
---

## Topic Suggestions

### Paris trip
lastMentionedAt: not-a-date
mentionCount: nope
expiresAt: also-bad
- ask: Ask how planning is going.
- unknown: Drop this unknown kind.
- share:
this line is not metadata or a suggestion
''';

        final doc = MemoryDocument.parse(raw);

        expect(doc.parseErrors, isEmpty);
        expect(doc.topicSuggestions, hasLength(1));
        final group = doc.topicSuggestions.single;
        expect(group.lastMentionedAt, isNull);
        expect(group.mentionCount, 0);
        expect(group.expiresAt, isNull);
        expect(group.suggestions, [
          const TopicSuggestion(
            kind: TopicSuggestionKind.ask,
            text: 'Ask how planning is going.',
          ),
        ]);
      },
    );

    test('render emits Topic Suggestions after Topics before Upcoming', () {
      final doc = MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah Johnson',
        lastUpdated: DateTime.utc(2026, 5, 19),
        topics: const ['Paris trip'],
        topicSuggestions: [
          TopicSuggestionGroup(
            topic: 'Paris trip',
            lastMentionedAt: DateTime(2026, 6, 4),
            mentionCount: 2,
            suggestions: const [
              TopicSuggestion(
                kind: TopicSuggestionKind.ask,
                text: 'Ask how planning is going.',
              ),
            ],
          ),
        ],
      );

      final rendered = doc.render();

      expect(
        rendered.indexOf('## Topics'),
        lessThan(rendered.indexOf('## Topic Suggestions')),
      );
      expect(
        rendered.indexOf('## Topic Suggestions'),
        lessThan(rendered.indexOf('## Upcoming')),
      );
      expect(rendered, contains('### Paris trip'));
      expect(rendered, contains('lastMentionedAt: 2026-06-04'));
      expect(rendered, contains('mentionCount: 2'));
      expect(rendered, contains('- ask: Ask how planning is going.'));
    });

    test('render caps Topic Suggestions to three per topic group', () {
      final doc = MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah Johnson',
        lastUpdated: DateTime.utc(2026, 5, 19),
        topicSuggestions: [
          TopicSuggestionGroup(
            topic: 'Paris trip',
            suggestions: const [
              TopicSuggestion(kind: TopicSuggestionKind.ask, text: 'First.'),
              TopicSuggestion(kind: TopicSuggestionKind.share, text: 'Second.'),
              TopicSuggestion(kind: TopicSuggestionKind.plan, text: 'Third.'),
              TopicSuggestion(
                kind: TopicSuggestionKind.remember,
                text: 'Fourth should not render.',
              ),
            ],
          ),
        ],
      );

      final rendered = doc.render();

      expect(rendered, contains('- ask: First.'));
      expect(rendered, contains('- share: Second.'));
      expect(rendered, contains('- plan: Third.'));
      expect(rendered, isNot(contains('Fourth should not render.')));
    });

    test(
      'malformed frontmatter populates parseErrors but body still parses',
      () {
        const raw = '''---
not: [valid
---
## Summary
Body still here.
''';

        final doc = MemoryDocument.parse(raw);

        expect(doc.parseErrors, isNotEmpty);
        // The body section after the broken frontmatter should still be
        // recoverable. Either the frontmatter regex bails (treating the
        // whole input as body) or yaml fails and we fall back to body —
        // both paths must reach the Summary section.
        expect(doc.summary, 'Body still here.');
      },
    );

    test('empty string does not throw and yields a parseError', () {
      final doc = MemoryDocument.parse('');

      expect(doc.parseErrors, contains('missing contactId'));
      expect(doc.contactId, '');
      expect(doc.summary, '');
    });

    test('garbage bytes do not throw', () {
      final raw = String.fromCharCodes(
        List<int>.generate(64, (i) => (i * 7) % 256),
      );

      // The contract: no exception. Anything else is fine.
      expect(() => MemoryDocument.parse(raw), returnsNormally);
    });

    test('Upcoming entry with only startDate round-trips', () {
      const raw = '''---
contactId: 'sarah'
displayName: 'Sarah Johnson'
lastUpdated: '2026-05-19T00:00:00.000Z'
version: 1
---

## Upcoming
- 2026-05-19 trip
''';
      final doc = MemoryDocument.parse(raw);
      expect(doc.upcoming, hasLength(1));
      expect(doc.upcoming.first.startDate, DateTime(2026, 5, 19));
      expect(doc.upcoming.first.endDate, isNull);
      expect(doc.upcoming.first.description, 'trip');

      final reparsed = MemoryDocument.parse(doc.render());
      expect(reparsed.upcoming, doc.upcoming);
    });

    test('Upcoming entry with both dates round-trips', () {
      const raw = '''---
contactId: 'sarah'
displayName: 'Sarah Johnson'
lastUpdated: '2026-05-19T00:00:00.000Z'
version: 1
---

## Upcoming
- 2026-05-19/2026-05-26 USA trip
''';
      final doc = MemoryDocument.parse(raw);
      expect(doc.upcoming, hasLength(1));
      expect(doc.upcoming.first.startDate, DateTime(2026, 5, 19));
      expect(doc.upcoming.first.endDate, DateTime(2026, 5, 26));
      expect(doc.upcoming.first.description, 'USA trip');

      final reparsed = MemoryDocument.parse(doc.render());
      expect(reparsed.upcoming, doc.upcoming);
    });

    test('Topics dedup case-insensitively, first-occurrence case wins', () {
      const raw = '''---
contactId: 'sarah'
displayName: 'Sarah Johnson'
lastUpdated: '2026-05-19T00:00:00.000Z'
version: 1
---

## Topics
- coffee
- Coffee
- COFFEE
''';
      final doc = MemoryDocument.parse(raw);
      expect(doc.topics, ['coffee']);
    });

    test('Topics cap drops trailing entries beyond 8', () {
      const raw = '''---
contactId: 'sarah'
displayName: 'Sarah Johnson'
lastUpdated: '2026-05-19T00:00:00.000Z'
version: 1
---

## Topics
- t1
- t2
- t3
- t4
- t5
- t6
- t7
- t8
- t9
- t10
- t11
- t12
''';
      final doc = MemoryDocument.parse(raw);
      expect(doc.topics, hasLength(MemoryDocument.topicCap));
      expect(doc.topics, ['t1', 't2', 't3', 't4', 't5', 't6', 't7', 't8']);
    });

    test('unknown sections are dropped and reported via parseErrors', () {
      const raw = '''---
contactId: 'sarah'
displayName: 'Sarah Johnson'
lastUpdated: '2026-05-19T00:00:00.000Z'
version: 1
---

## Mystery
should not survive
''';
      final doc = MemoryDocument.parse(raw);
      expect(doc.parseErrors, contains('unknown section: Mystery'));
    });
  });

  group('MemoryDocument.empty', () {
    test('yields a v1 doc with empty narrative sections', () {
      final now = DateTime.utc(2026, 5, 19);
      final doc = MemoryDocument.empty(
        contactId: 'sarah',
        displayName: 'Sarah Johnson',
        now: now,
      );
      expect(doc.contactId, 'sarah');
      expect(doc.displayName, 'Sarah Johnson');
      expect(doc.lastUpdated, now);
      expect(doc.version, 1);
      expect(doc.summary, '');
      expect(doc.history, '');
      expect(doc.preferences, '');
      expect(doc.topics, isEmpty);
      expect(doc.upcoming, isEmpty);
    });
  });
}
