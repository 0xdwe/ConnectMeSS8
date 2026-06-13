import 'package:connect_me/src/ai/llm_ai_update_response.dart';
import 'package:connect_me/src/models/social_models.dart' show InteractionType;
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _validBase() => <String, dynamic>{
  'interactionType': 'sharedActivity',
  'interactionTitle': 'Coffee at Brew & Co',
  'interactionNote': 'Caught up over an oat-milk latte.',
  'memoryUpdate': <String, dynamic>{
    'summary': null,
    'newHistoryBullet': '- 2026-05-27 \u2014 Caught up at Brew & Co.',
    'topicsToAdd': <String>['oat milk'],
    'preferencesToAdd': <String>[],
    'upcomingToAdd': <Map<String, dynamic>>[],
    'topicSuggestions': <Map<String, dynamic>>[],
  },
  'interactionDepth': 50,
  'nextStep': 'Send the article she mentioned',
  'promptVersion': 1,
  'modelName': 'gemini-2.5-flash-lite',
};

void main() {
  group('LlmAiUpdateResponse.fromJson — happy path', () {
    test('parses a fully populated payload', () {
      final r = LlmAiUpdateResponse.fromJson(_validBase());
      expect(r.interactionType, InteractionType.sharedActivity);
      expect(r.interactionTitle, 'Coffee at Brew & Co');
      expect(r.interactionDepth, 50);
      expect(r.nextStep, 'Send the article she mentioned');
      expect(r.promptVersion, 1);
      expect(r.modelName, 'gemini-2.5-flash-lite');
      expect(r.memoryUpdate.summary, isNull);
      expect(r.memoryUpdate.topicsToAdd, ['oat milk']);
      expect(r.memoryUpdate.upcomingToAdd, isEmpty);
      expect(r.memoryUpdate.topicSuggestions, isEmpty);
    });

    test('omits optional metadata when not provided', () {
      final json = _validBase()
        ..remove('promptVersion')
        ..remove('modelName')
        ..remove('nextStep');
      final r = LlmAiUpdateResponse.fromJson(json);
      expect(r.promptVersion, isNull);
      expect(r.modelName, isNull);
      expect(r.nextStep, isNull);
    });

    test('round-trips via toJson/fromJson', () {
      final original = LlmAiUpdateResponse.fromJson(_validBase());
      final round = LlmAiUpdateResponse.fromJson(original.toJson());
      expect(round.interactionType, original.interactionType);
      expect(round.interactionTitle, original.interactionTitle);
      expect(round.interactionNote, original.interactionNote);
      expect(round.interactionDepth, original.interactionDepth);
      expect(round.nextStep, original.nextStep);
      expect(
        round.memoryUpdate.newHistoryBullet,
        original.memoryUpdate.newHistoryBullet,
      );
    });
  });

  group('interactionDepth clamp', () {
    test('clamps below zero up to zero', () {
      final json = _validBase()..['interactionDepth'] = -3;
      expect(LlmAiUpdateResponse.fromJson(json).interactionDepth, 0);
    });

    test('clamps above one hundred down to one hundred', () {
      final json = _validBase()..['interactionDepth'] = 250;
      expect(LlmAiUpdateResponse.fromJson(json).interactionDepth, 100);
    });

    test('preserves in-range values across the 0..100 spectrum', () {
      for (final v in const [0, 25, 50, 75, 100]) {
        final json = _validBase()..['interactionDepth'] = v;
        expect(LlmAiUpdateResponse.fromJson(json).interactionDepth, v);
      }
    });

    test('accepts num that is integral (some SDKs return doubles)', () {
      final json = _validBase()..['interactionDepth'] = 75.0;
      expect(LlmAiUpdateResponse.fromJson(json).interactionDepth, 75);
    });
  });

  group('schema validation — interactionType', () {
    test('rejects unknown interactionType', () {
      final json = _validBase()..['interactionType'] = 'gossip';
      expect(
        () => LlmAiUpdateResponse.fromJson(json),
        throwsA(isA<LlmResponseParseException>()),
      );
    });

    test('rejects non-string interactionType', () {
      final json = _validBase()..['interactionType'] = 42;
      expect(
        () => LlmAiUpdateResponse.fromJson(json),
        throwsA(isA<LlmResponseParseException>()),
      );
    });

    test('accepts every valid InteractionType enum name', () {
      for (final t in InteractionType.values) {
        final json = _validBase()..['interactionType'] = t.name;
        expect(LlmAiUpdateResponse.fromJson(json).interactionType, t);
      }
    });
  });

  group('schema validation — interactionTitle', () {
    test('rejects empty interactionTitle', () {
      final json = _validBase()..['interactionTitle'] = '';
      expect(
        () => LlmAiUpdateResponse.fromJson(json),
        throwsA(isA<LlmResponseParseException>()),
      );
    });

    test('rejects interactionTitle longer than 60 chars', () {
      final json = _validBase()..['interactionTitle'] = 'a' * 61;
      expect(
        () => LlmAiUpdateResponse.fromJson(json),
        throwsA(isA<LlmResponseParseException>()),
      );
    });

    test('accepts interactionTitle of exactly 60 chars', () {
      final json = _validBase()..['interactionTitle'] = 'a' * 60;
      expect(LlmAiUpdateResponse.fromJson(json).interactionTitle.length, 60);
    });
  });

  group('schema validation — nextStep', () {
    test('rejects nextStep longer than 80 chars', () {
      final json = _validBase()..['nextStep'] = 'a' * 81;
      expect(
        () => LlmAiUpdateResponse.fromJson(json),
        throwsA(isA<LlmResponseParseException>()),
      );
    });

    test('accepts nextStep at exactly 80 chars', () {
      final json = _validBase()..['nextStep'] = 'a' * 80;
      expect(LlmAiUpdateResponse.fromJson(json).nextStep!.length, 80);
    });

    test('accepts null nextStep', () {
      final json = _validBase()..['nextStep'] = null;
      expect(LlmAiUpdateResponse.fromJson(json).nextStep, isNull);
    });
  });

  group('memoryUpdate — newHistoryBullet format', () {
    test('rejects bullet without ISO date prefix', () {
      final json = _validBase();
      (json['memoryUpdate'] as Map<String, dynamic>)['newHistoryBullet'] =
          'just some text';
      expect(
        () => LlmAiUpdateResponse.fromJson(json),
        throwsA(isA<LlmResponseParseException>()),
      );
    });

    test('rejects bullet without em-dash separator', () {
      final json = _validBase();
      (json['memoryUpdate'] as Map<String, dynamic>)['newHistoryBullet'] =
          '- 2026-05-27 - missing em dash';
      expect(
        () => LlmAiUpdateResponse.fromJson(json),
        throwsA(isA<LlmResponseParseException>()),
      );
    });

    test('rejects bullet with empty body', () {
      final json = _validBase();
      (json['memoryUpdate'] as Map<String, dynamic>)['newHistoryBullet'] =
          '- 2026-05-27 \u2014 ';
      expect(
        () => LlmAiUpdateResponse.fromJson(json),
        throwsA(isA<LlmResponseParseException>()),
      );
    });

    test('accepts a well-formed bullet', () {
      final json = _validBase();
      (json['memoryUpdate'] as Map<String, dynamic>)['newHistoryBullet'] =
          '- 2026-05-27 \u2014 Sarah\'s daughter starts kindergarten in '
          'September.';
      expect(
        LlmAiUpdateResponse.fromJson(json).memoryUpdate.newHistoryBullet,
        startsWith('- 2026-05-27 \u2014 '),
      );
    });
  });

  group('memoryUpdate — list fields', () {
    test('treats missing list fields as empty', () {
      final json = _validBase();
      final mu = json['memoryUpdate'] as Map<String, dynamic>
        ..remove('topicsToAdd')
        ..remove('preferencesToAdd')
        ..remove('upcomingToAdd');
      json['memoryUpdate'] = mu;
      final r = LlmAiUpdateResponse.fromJson(json);
      expect(r.memoryUpdate.topicsToAdd, isEmpty);
      expect(r.memoryUpdate.preferencesToAdd, isEmpty);
      expect(r.memoryUpdate.upcomingToAdd, isEmpty);
    });

    test('rejects topicsToAdd that is not a list', () {
      final json = _validBase();
      (json['memoryUpdate'] as Map<String, dynamic>)['topicsToAdd'] =
          'kindergarten';
      expect(
        () => LlmAiUpdateResponse.fromJson(json),
        throwsA(isA<LlmResponseParseException>()),
      );
    });

    test('drops non-string entries in string-typed lists', () {
      // Defensive: schema-constrained output should never produce
      // mixed-type arrays, but if it does, we silently drop the
      // non-strings rather than throw.
      final json = _validBase();
      (json['memoryUpdate'] as Map<String, dynamic>)['topicsToAdd'] = [
        'valid',
        42,
        null,
        'also-valid',
      ];
      final r = LlmAiUpdateResponse.fromJson(json);
      expect(r.memoryUpdate.topicsToAdd, ['valid', 'also-valid']);
    });
  });

  group('topicSuggestions validation', () {
    test('parses topic suggestion groups with metadata', () {
      final json = _validBase();
      (json['memoryUpdate'] as Map<String, dynamic>)['topicSuggestions'] = [
        {
          'topic': 'paris trip',
          'lastMentionedAt': '2026-06-04',
          'mentionCount': 2,
          'expiresAt': '2026-07-01',
          'suggestions': [
            {
              'kind': 'ask',
              'text': 'Ask how the Paris plans are coming together.',
            },
            {'kind': 'share', 'text': 'Send a café rec if you spot one.'},
          ],
        },
      ];

      final r = LlmAiUpdateResponse.fromJson(json);
      final group = r.memoryUpdate.topicSuggestions.single;
      expect(group.topic, 'paris trip');
      expect(group.lastMentionedAt, '2026-06-04');
      expect(group.mentionCount, 2);
      expect(group.expiresAt, '2026-07-01');
      expect(group.suggestions, hasLength(2));
      expect(group.suggestions.first.kind, LlmTopicSuggestionKind.ask);
      expect(
        group.suggestions.first.text,
        'Ask how the Paris plans are coming together.',
      );
    });

    test('rejects unknown topic suggestion kind', () {
      final json = _validBase();
      (json['memoryUpdate'] as Map<String, dynamic>)['topicSuggestions'] = [
        {
          'topic': 'paris trip',
          'suggestions': [
            {'kind': 'nag', 'text': 'Ask about Paris.'},
          ],
        },
      ];

      expect(
        () => LlmAiUpdateResponse.fromJson(json),
        throwsA(isA<LlmResponseParseException>()),
      );
    });

    test('rejects non-string topic suggestion dates without TypeError', () {
      final json = _validBase();
      (json['memoryUpdate'] as Map<String, dynamic>)['topicSuggestions'] = [
        {
          'topic': 'paris trip',
          'lastMentionedAt': 20260604,
          'expiresAt': {'date': '2026-07-01'},
          'suggestions': [
            {
              'kind': 'ask',
              'text': 'Ask how the Paris plans are coming together.',
            },
          ],
        },
      ];

      expect(
        () => LlmAiUpdateResponse.fromJson(json),
        throwsA(isA<LlmResponseParseException>()),
      );
    });

    test('rejects topic suggestion text with numeric day-count shame', () {
      final json = _validBase();
      (json['memoryUpdate'] as Map<String, dynamic>)['topicSuggestions'] = [
        {
          'topic': 'paris trip',
          'suggestions': [
            {
              'kind': 'ask',
              'text': "You haven't asked about Paris in 47 days.",
            },
          ],
        },
      ];

      expect(
        () => LlmAiUpdateResponse.fromJson(json),
        throwsA(isA<LlmResponseParseException>()),
      );
    });

    test('rejects topic suggestion text with non-numeric guilt phrasing', () {
      final json = _validBase();
      (json['memoryUpdate'] as Map<String, dynamic>)['topicSuggestions'] = [
        {
          'topic': 'paris trip',
          'suggestions': [
            {'kind': 'ask', 'text': 'You are neglecting Sarah.'},
          ],
        },
      ];

      expect(
        () => LlmAiUpdateResponse.fromJson(json),
        throwsA(isA<LlmResponseParseException>()),
      );
    });
  });

  group('upcomingToAdd validation', () {
    Map<String, dynamic> baseWithUpcoming(List<Map<String, dynamic>> entries) {
      final json = _validBase();
      (json['memoryUpdate'] as Map<String, dynamic>)['upcomingToAdd'] = entries;
      return json;
    }

    test('parses a dated milestone entry', () {
      final json = baseWithUpcoming([
        {
          'label': 'Kindergarten starts',
          'kind': 'milestone',
          'dateIso': '2026-09-01',
        },
      ]);
      final r = LlmAiUpdateResponse.fromJson(json);
      expect(r.memoryUpdate.upcomingToAdd, hasLength(1));
      final entry = r.memoryUpdate.upcomingToAdd.single;
      expect(entry.label, 'Kindergarten starts');
      expect(entry.kind, LlmUpcomingKind.milestone);
      expect(entry.dateIso, '2026-09-01');
      expect(entry.relativeWhen, isNull);
    });

    test('parses a relative-when entry without date', () {
      final json = baseWithUpcoming([
        {
          'label': 'Trip planning',
          'kind': 'trip',
          'relativeWhen': 'next month',
        },
      ]);
      final entry = LlmAiUpdateResponse.fromJson(
        json,
      ).memoryUpdate.upcomingToAdd.single;
      expect(entry.dateIso, isNull);
      expect(entry.relativeWhen, 'next month');
    });

    test('rejects entry without dateIso or relativeWhen', () {
      final json = baseWithUpcoming([
        {'label': 'Something', 'kind': 'other'},
      ]);
      expect(
        () => LlmAiUpdateResponse.fromJson(json),
        throwsA(isA<LlmResponseParseException>()),
      );
    });

    test('rejects unknown kind', () {
      final json = baseWithUpcoming([
        {'label': 'Bash', 'kind': 'party', 'dateIso': '2026-12-31'},
      ]);
      expect(
        () => LlmAiUpdateResponse.fromJson(json),
        throwsA(isA<LlmResponseParseException>()),
      );
    });

    test('accepts every valid LlmUpcomingKind name', () {
      for (final k in LlmUpcomingKind.values) {
        final json = baseWithUpcoming([
          {'label': 'X', 'kind': k.name, 'dateIso': '2026-01-01'},
        ]);
        expect(
          LlmAiUpdateResponse.fromJson(
            json,
          ).memoryUpdate.upcomingToAdd.single.kind,
          k,
        );
      }
    });

    test('drops malformed inner objects from upcomingToAdd list', () {
      // The list itself is iterated with whereType so non-Map
      // entries are silently dropped before fromJson runs.
      final json = _validBase();
      (json['memoryUpdate'] as Map<String, dynamic>)['upcomingToAdd'] = [
        'not a map',
        {'label': 'OK', 'kind': 'milestone', 'dateIso': '2026-01-01'},
      ];
      final r = LlmAiUpdateResponse.fromJson(json);
      expect(r.memoryUpdate.upcomingToAdd, hasLength(1));
    });
  });

  group('top-level parse failures', () {
    test('rejects missing memoryUpdate', () {
      final json = _validBase()..remove('memoryUpdate');
      expect(
        () => LlmAiUpdateResponse.fromJson(json),
        throwsA(isA<LlmResponseParseException>()),
      );
    });

    test('rejects present-but-null memoryUpdate', () {
      final json = _validBase()..['memoryUpdate'] = null;
      expect(
        () => LlmAiUpdateResponse.fromJson(json),
        throwsA(isA<LlmResponseParseException>()),
      );
    });

    test('rejects non-int interactionDepth', () {
      final json = _validBase()..['interactionDepth'] = 'deep';
      expect(
        () => LlmAiUpdateResponse.fromJson(json),
        throwsA(isA<LlmResponseParseException>()),
      );
    });

    test('rejects en-dash bullet (must be em-dash)', () {
      final json = _validBase();
      (json['memoryUpdate'] as Map<String, dynamic>)['newHistoryBullet'] =
          '- 2026-05-27 – en dash, not em';
      expect(
        () => LlmAiUpdateResponse.fromJson(json),
        throwsA(isA<LlmResponseParseException>()),
      );
    });
  });
}
