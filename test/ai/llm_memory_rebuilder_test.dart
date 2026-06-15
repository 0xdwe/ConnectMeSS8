import 'dart:async';

import 'package:connect_me/src/ai/llm_memory_rebuilder.dart';
import 'package:connect_me/src/ai/memory_rebuilder.dart';
import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for [LlmMemoryRebuilder] using the function-injection seam.
///
/// These are pure Dart tests — no Firebase AI SDK required. The
/// [geminiRebuildContentFn] seam injects canned JSON responses so
/// all test scenarios are deterministic and headless.
void main() {
  group('LlmMemoryRebuilder — successful rebuild', () {
    test('rebuild returns a MemoryRebuildResult with updated summary and history',
        () async {
      final rebuilder = LlmMemoryRebuilder(
        firebaseAi: null,
        geminiRebuildContentFn: ({
          required dynamic modelName,
          required dynamic systemPrompt,
          required dynamic responseSchema,
          required dynamic contents,
          required dynamic timeout,
        }) async {
          return '''
{
  "summary": "Alice is a close friend. They catch up regularly over coffee.",
  "history": "Alice and the user have been friends since college. They recently met for coffee and discussed travel plans.",
  "preferences": "Prefers coffee over tea. Enjoys travel.",
  "topics": ["coffee", "travel", "college"],
  "topicSuggestions": [
    {
      "topic": "coffee",
      "suggestions": [
        {
          "kind": "ask",
          "text": "Ask Alice about her favorite new coffee spot",
          "context": "Alice mentioned exploring new cafes recently"
        }
      ]
    }
  ],
  "upcoming": [],
  "nextStep": "Suggest a weekend coffee date with Alice"
}
''';
        },
      );

      final result = await rebuilder.rebuild(
        contact: Connection(
          id: 'alice',
          name: 'Alice',
          email: 'alice@example.com',
          category: 'Friends',
          avatar: '👩',
          bondScore: 70,
          nextStep: '',
          lastContact: DateTime(2026, 5, 1),
          notes: '',
          knownSince: DateTime(2018),
          preferredChannels: const ['Text'],
        ),
        currentMemory: MemoryDocument(
          contactId: 'alice',
          displayName: 'Alice',
          lastUpdated: DateTime(2026, 6, 1),
          summary: 'Original summary containing deleted activity',
          history: 'Original history with reference to deleted coffee chat',
        ),
        remainingInteractions: [
          CrmInteraction(
            id: 'int-1',
            contactId: 'alice',
            type: InteractionType.interaction,
            title: 'Weekend hike',
            note: 'Great weather',
            date: DateTime(2026, 5, 15),
          ),
        ],
        deletedInteraction: CrmInteraction(
          id: 'del-1',
          contactId: 'alice',
          type: InteractionType.interaction,
          title: 'Deleted coffee chat',
          note: 'Discussed work',
          date: DateTime(2026, 4, 1),
        ),
      );

      expect(result, isA<MemoryRebuildResult>());
      expect(
        result.memoryDocument.summary,
        contains('Alice'),
      );
      expect(
        result.memoryDocument.summary,
        contains('close friend'),
      );
      expect(
        result.memoryDocument.history,
        contains('friends since college'),
      );
      expect(
        result.memoryDocument.preferences,
        contains('coffee'),
      );
    });

    test('rebuild returns a nextStep suggestion', () async {
      final rebuilder = LlmMemoryRebuilder(
        firebaseAi: null,
        geminiRebuildContentFn: ({
          required dynamic modelName,
          required dynamic systemPrompt,
          required dynamic responseSchema,
          required dynamic contents,
          required dynamic timeout,
        }) async {
          return '{"nextStep": "Check in with Bob about his new job"}';
        },
      );

      final result = await rebuilder.rebuild(
        contact: Connection(
          id: 'bob',
          name: 'Bob',
          email: 'bob@example.com',
          category: 'Friends',
          avatar: '👨',
          bondScore: 50,
          nextStep: '',
          lastContact: DateTime(2026, 4, 1),
          notes: '',
          knownSince: DateTime(2020),
          preferredChannels: const ['Text'],
        ),
        currentMemory: MemoryDocument(
          contactId: 'bob',
          displayName: 'Bob',
          lastUpdated: DateTime(2026, 6, 1),
        ),
        remainingInteractions: const [],
        deletedInteraction: CrmInteraction(
          id: 'del-bob',
          contactId: 'bob',
          type: InteractionType.interaction,
          title: 'Deleted catch-up',
          note: '',
          date: DateTime(2026, 3, 1),
        ),
      );

      expect(result.nextStep, 'Check in with Bob about his new job');
    });

    test('rebuild preserves information from remaining interactions',
        () async {
      var callCount = 0;
      String? capturedPrompt;
      final rebuilder = LlmMemoryRebuilder(
        firebaseAi: null,
        clock: () => DateTime(2026, 6, 15),
        geminiRebuildContentFn: ({
          required dynamic modelName,
          required dynamic systemPrompt,
          required dynamic responseSchema,
          required dynamic contents,
          required dynamic timeout,
        }) async {
          callCount++;
          // Extract text from the Content.parts
          if (contents is List && contents.isNotEmpty) {
            final content = contents[0];
            if (content is dynamic &&
                content.parts is List &&
                content.parts.isNotEmpty) {
              final part = content.parts[0];
              if (part is dynamic && part.text is String) {
                capturedPrompt = part.text as String;
              }
            }
          }
          return '{"summary": "Updated summary preserving remaining interactions.", "nextStep": "Plan next hike"}';
        },
      );

      final result = await rebuilder.rebuild(
        contact: Connection(
          id: 'alice',
          name: 'Alice',
          email: 'alice@example.com',
          category: 'Friends',
          avatar: '👩',
          bondScore: 70,
          nextStep: '',
          lastContact: DateTime(2026, 4, 1),
          notes: '',
          knownSince: DateTime(2018),
          preferredChannels: const ['Text'],
        ),
        currentMemory: MemoryDocument(
          contactId: 'alice',
          displayName: 'Alice',
          lastUpdated: DateTime(2026, 6, 1),
        ),
        remainingInteractions: [
          CrmInteraction(
            id: 'int-1',
            contactId: 'alice',
            type: InteractionType.interaction,
            title: 'Weekend hike',
            note: 'Great weather',
            date: DateTime(2026, 5, 15),
          ),
        ],
        deletedInteraction: CrmInteraction(
          id: 'del-1',
          contactId: 'alice',
          type: InteractionType.interaction,
          title: 'Deleted coffee chat',
          note: '',
          date: DateTime(2026, 4, 1),
        ),
      );

      expect(callCount, 1);
      expect(capturedPrompt, contains('Weekend hike'));
      expect(capturedPrompt, contains('Deleted coffee chat'));
      expect(result.memoryDocument.summary, contains('remaining interactions'));
      expect(result.memoryDocument.summary, contains('Updated'));
      expect(result.nextStep, 'Plan next hike');
    });

    test('rebuild with all-optional response retains existing memory fields',
        () async {
      final rebuilder = LlmMemoryRebuilder(
        firebaseAi: null,
        geminiRebuildContentFn: ({
          required dynamic modelName,
          required dynamic systemPrompt,
          required dynamic responseSchema,
          required dynamic contents,
          required dynamic timeout,
        }) async {
          return '{"summary": "Only summary was updated."}';
        },
      );

      final result = await rebuilder.rebuild(
        contact: Connection(
          id: 'carol',
          name: 'Carol',
          email: 'carol@example.com',
          category: 'Family',
          avatar: '👩',
          bondScore: 60,
          nextStep: '',
          lastContact: DateTime(2026, 5, 1),
          notes: '',
          knownSince: DateTime(2015),
          preferredChannels: const ['Phone'],
        ),
        currentMemory: MemoryDocument(
          contactId: 'carol',
          displayName: 'Carol',
          lastUpdated: DateTime(2026, 6, 1),
          summary: 'Original summary',
          history: 'Original history preserved',
          preferences: 'Original preferences preserved',
          topics: const ['family', 'cooking'],
        ),
        remainingInteractions: const [],
        deletedInteraction: CrmInteraction(
          id: 'del-carol',
          contactId: 'carol',
          type: InteractionType.interaction,
          title: 'Deleted call',
          note: '',
          date: DateTime(2026, 3, 1),
        ),
      );

      // Summary was replaced
      expect(result.memoryDocument.summary, 'Only summary was updated.');
      // Other fields retained from current
      expect(result.memoryDocument.history, 'Original history preserved');
      expect(result.memoryDocument.preferences, 'Original preferences preserved');
      expect(result.memoryDocument.topics, contains('family'));
      expect(result.memoryDocument.topics, contains('cooking'));
      // nextStep is null when not provided
      expect(result.nextStep, isNull);
    });
  });

  group('LlmMemoryRebuilder — error paths', () {
    test('failOnNetwork throws MemoryRebuildFailure', () async {
      final rebuilder = LlmMemoryRebuilder(
        firebaseAi: null,
        failOnNetwork: true,
      );

      await expectLater(
        rebuilder.rebuild(
          contact: Connection(
            id: 'x',
            name: 'X',
            email: 'x@example.com',
            category: 'Friends',
            avatar: '😊',
            bondScore: 50,
            nextStep: '',
            lastContact: DateTime(2026, 1, 1),
            notes: '',
            knownSince: DateTime(2020),
            preferredChannels: const ['Text'],
          ),
          currentMemory: MemoryDocument(
            contactId: 'x',
            displayName: 'X',
            lastUpdated: DateTime(2026, 5, 1),
          ),
          remainingInteractions: const [],
          deletedInteraction: CrmInteraction(
            id: 'del-x',
            contactId: 'x',
            type: InteractionType.interaction,
            title: 'Deleted',
            note: '',
            date: DateTime(2026, 3, 1),
          ),
        ),
        throwsA(
          isA<MemoryRebuildFailure>().having(
            (e) => e.message,
            'message',
            'Injected network failure',
          ),
        ),
      );
    });

    test('invalid JSON response throws MemoryRebuildFailure', () async {
      final rebuilder = LlmMemoryRebuilder(
        firebaseAi: null,
        geminiRebuildContentFn: ({
          required dynamic modelName,
          required dynamic systemPrompt,
          required dynamic responseSchema,
          required dynamic contents,
          required dynamic timeout,
        }) async {
          return 'not-json-at-all';
        },
      );

      await expectLater(
        rebuilder.rebuild(
          contact: Connection(
            id: 'x',
            name: 'X',
            email: 'x@example.com',
            category: 'Friends',
            avatar: '😊',
            bondScore: 50,
            nextStep: '',
            lastContact: DateTime(2026, 1, 1),
            notes: '',
            knownSince: DateTime(2020),
            preferredChannels: const ['Text'],
          ),
          currentMemory: MemoryDocument(
            contactId: 'x',
            displayName: 'X',
            lastUpdated: DateTime(2026, 5, 1),
          ),
          remainingInteractions: const [],
          deletedInteraction: CrmInteraction(
            id: 'del-x',
            contactId: 'x',
            type: InteractionType.interaction,
            title: 'Deleted',
            note: '',
            date: DateTime(2026, 3, 1),
          ),
        ),
        throwsA(isA<MemoryRebuildFailure>()),
      );
    });

    test('empty response throws MemoryRebuildFailure', () async {
      final rebuilder = LlmMemoryRebuilder(
        firebaseAi: null,
        geminiRebuildContentFn: ({
          required dynamic modelName,
          required dynamic systemPrompt,
          required dynamic responseSchema,
          required dynamic contents,
          required dynamic timeout,
        }) async {
          return '';
        },
      );

      await expectLater(
        rebuilder.rebuild(
          contact: Connection(
            id: 'x',
            name: 'X',
            email: 'x@example.com',
            category: 'Friends',
            avatar: '😊',
            bondScore: 50,
            nextStep: '',
            lastContact: DateTime(2026, 1, 1),
            notes: '',
            knownSince: DateTime(2020),
            preferredChannels: const ['Text'],
          ),
          currentMemory: MemoryDocument(
            contactId: 'x',
            displayName: 'X',
            lastUpdated: DateTime(2026, 5, 1),
          ),
          remainingInteractions: const [],
          deletedInteraction: CrmInteraction(
            id: 'del-x',
            contactId: 'x',
            type: InteractionType.interaction,
            title: 'Deleted',
            note: '',
            date: DateTime(2026, 3, 1),
          ),
        ),
        throwsA(isA<MemoryRebuildFailure>()),
      );
    });

    test('retries once on transient error (FormatException), then succeeds',
        () async {
      var callCount = 0;
      final rebuilder = LlmMemoryRebuilder(
        firebaseAi: null,
        geminiRebuildContentFn: ({
          required dynamic modelName,
          required dynamic systemPrompt,
          required dynamic responseSchema,
          required dynamic contents,
          required dynamic timeout,
        }) async {
          callCount++;
          if (callCount == 1) {
            // Throw FormatException to trigger retry
            throw const FormatException('Transient network glitch');
          }
          return '{"summary": "Retry produced a valid response."}';
        },
      );

      final result = await rebuilder.rebuild(
        contact: Connection(
          id: 'retry',
          name: 'Retry',
          email: 'retry@example.com',
          category: 'Friends',
          avatar: '😊',
          bondScore: 50,
          nextStep: '',
          lastContact: DateTime(2026, 1, 1),
          notes: '',
          knownSince: DateTime(2020),
          preferredChannels: const ['Text'],
        ),
        currentMemory: MemoryDocument(
          contactId: 'retry',
          displayName: 'Retry',
          lastUpdated: DateTime(2026, 5, 1),
          summary: 'Old summary',
        ),
        remainingInteractions: const [],
        deletedInteraction: CrmInteraction(
          id: 'del-retry',
          contactId: 'retry',
          type: InteractionType.interaction,
          title: 'Deleted retry event',
          note: '',
          date: DateTime(2026, 3, 1),
        ),
      );

      expect(callCount, 2);
      expect(result.memoryDocument.summary, 'Retry produced a valid response.');
    });

    test('exhausts retries on persistent error, then throws', () async {
      var callCount = 0;
      final rebuilder = LlmMemoryRebuilder(
        firebaseAi: null,
        geminiRebuildContentFn: ({
          required dynamic modelName,
          required dynamic systemPrompt,
          required dynamic responseSchema,
          required dynamic contents,
          required dynamic timeout,
        }) async {
          callCount++;
          throw TimeoutException('Always times out');
        },
      );

      await expectLater(
        rebuilder.rebuild(
          contact: Connection(
            id: 'fail',
            name: 'Fail',
            email: 'fail@example.com',
            category: 'Friends',
            avatar: '😊',
            bondScore: 50,
            nextStep: '',
            lastContact: DateTime(2026, 1, 1),
            notes: '',
            knownSince: DateTime(2020),
            preferredChannels: const ['Text'],
          ),
          currentMemory: MemoryDocument(
            contactId: 'fail',
            displayName: 'Fail',
            lastUpdated: DateTime(2026, 5, 1),
          ),
          remainingInteractions: const [],
          deletedInteraction: CrmInteraction(
            id: 'del-fail',
            contactId: 'fail',
            type: InteractionType.interaction,
            title: 'Deleted fail',
            note: '',
            date: DateTime(2026, 3, 1),
          ),
        ),
        throwsA(isA<MemoryRebuildFailure>()),
      );

      // Retried exactly once = 2 total calls
      expect(callCount, 2);
    });

    test('markdown-fenced responses are parsed correctly', () async {
      final rebuilder = LlmMemoryRebuilder(
        firebaseAi: null,
        geminiRebuildContentFn: ({
          required dynamic modelName,
          required dynamic systemPrompt,
          required dynamic responseSchema,
          required dynamic contents,
          required dynamic timeout,
        }) async {
          return '```json\n{"summary": "Fenced summary", "nextStep": "Fenced step"}\n```';
        },
      );

      final result = await rebuilder.rebuild(
        contact: Connection(
          id: 'fence',
          name: 'Fence',
          email: 'fence@example.com',
          category: 'Friends',
          avatar: '😊',
          bondScore: 50,
          nextStep: '',
          lastContact: DateTime(2026, 1, 1),
          notes: '',
          knownSince: DateTime(2020),
          preferredChannels: const ['Text'],
        ),
        currentMemory: MemoryDocument(
          contactId: 'fence',
          displayName: 'Fence',
          lastUpdated: DateTime(2026, 5, 1),
        ),
        remainingInteractions: const [],
        deletedInteraction: CrmInteraction(
          id: 'del-fence',
          contactId: 'fence',
          type: InteractionType.interaction,
          title: 'Deleted fence',
          note: '',
          date: DateTime(2026, 3, 1),
        ),
      );

      expect(result.memoryDocument.summary, 'Fenced summary');
      expect(result.nextStep, 'Fenced step');
    });
  });
}
