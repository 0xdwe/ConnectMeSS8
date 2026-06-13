import 'dart:async';

import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:connect_me/src/widgets/crm_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_topic_backfill_runner.dart';
import 'package:connect_me/src/state/query_providers.dart';
import 'package:connect_me/src/ai/memory_topic_enricher.dart';

// Builds a minimal MaterialApp wrapper with the project's theme so that
// `context.tokens` resolves and Material-required ancestors are present.
Widget _wrap(
  Widget child, {
  bool disableAnimations = false,
  List<dynamic> overrides = const [],
}) {
  return ProviderScope(
    overrides: [...overrides],
    child: MaterialApp(
      theme: AppTheme.data(false),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

Connection _connection({
  String id = 'test',
  String name = 'Test Person',
  String category = 'Friends',
  int bondScore = 75,
}) {
  return Connection(
    id: id,
    name: name,
    email: 'test@example.com',
    category: category,
    avatar: '🧑',
    bondScore: bondScore,
    nextStep: 'Send a casual hello',
    lastContact: DateTime(2026, 5, 1),
    notes: '',
    knownSince: DateTime(2020, 1, 1),
    preferredChannels: const ['Text'],
  );
}

ContactInsight _insight({String contactId = 'test'}) {
  return ContactInsight(
    contactId: contactId,
    relationshipLabel: 'Close friend',
    knownSinceYears: 6,
  );
}

void main() {
  group('AiInsightsCard', () {
    testWidgets('renders all three subsections expanded by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(AiInsightsCard(connection: _connection(), insight: _insight())),
      );
      await tester.pump();

      expect(find.text('AI Insights'), findsOneWidget);
      expect(find.text('Recommendation'), findsOneWidget);
      expect(find.text('Person Summary'), findsOneWidget);
      expect(find.text('Conversation Topics'), findsOneWidget);
      expect(
        find.text('Click any topic to see AI suggestions.'),
        findsOneWidget,
      );
    });

    testWidgets('recommendation copy maps from BondTier (close)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AiInsightsCard(
            connection: _connection(bondScore: 90),
            insight: _insight(),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text('Strong bond! Keep up the regular communication.'),
        findsOneWidget,
      );
    });

    testWidgets('recommendation copy maps from BondTier (steady)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AiInsightsCard(
            connection: _connection(bondScore: 60),
            insight: _insight(),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text('Steady ground — a quick check-in keeps it warm.'),
        findsOneWidget,
      );
    });

    testWidgets('recommendation copy maps from BondTier (drifting)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AiInsightsCard(
            connection: _connection(bondScore: 30),
            insight: _insight(),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text('It\'s been a while. A short hello goes a long way.'),
        findsOneWidget,
      );
    });

    testWidgets('renders Person Summary body from MemoryDocument.summary', (
      tester,
    ) async {
      // Pre-#050 this test fed the body via `ContactInsight.why`. After
      // #050 the body comes from `MemoryDocument.summary` threaded
      // through the `memorySummary` parameter on `AiInsightsCard`.
      await tester.pumpWidget(
        _wrap(
          AiInsightsCard(
            connection: _connection(),
            insight: _insight(),
            memorySummary: 'Bespoke summary string for this test.',
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text('Bespoke summary string for this test.'),
        findsOneWidget,
      );
    });

    testWidgets('renders four conversation topic pills for known category', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AiInsightsCard(
            connection: _connection(category: 'Family'),
            insight: _insight(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Family updates'), findsOneWidget);
      expect(find.text('Shared memories'), findsOneWidget);
      expect(find.text('Daily life'), findsOneWidget);
      expect(find.text('Future plans'), findsOneWidget);
    });

    testWidgets('initialSelectedTopic opens prepared Topic Suggestions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AiInsightsCard(
            connection: _connection(category: 'Friends'),
            insight: _insight(),
            initialSelectedTopic: 'Paris trip',
            memory: MemoryDocument(
              contactId: 'test',
              displayName: 'Test Person',
              lastUpdated: DateTime.utc(2026, 6, 4),
              topics: const ['Paris trip'],
              topicSuggestions: [
                TopicSuggestionGroup(
                  topic: 'Paris trip',
                  suggestions: const [
                    TopicSuggestion(
                      kind: TopicSuggestionKind.ask,
                      text: 'Ask how the Paris plans are coming together.',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Paris trip'), findsWidgets);
      expect(
        find.text('Ask how the Paris plans are coming together.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a topic pill shows prepared Topic Suggestions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AiInsightsCard(
            connection: _connection(category: 'Friends'),
            insight: _insight(),
            memory: MemoryDocument(
              contactId: 'test',
              displayName: 'Test Person',
              lastUpdated: DateTime.utc(2026, 6, 4),
              topics: const ['Paris trip'],
              topicSuggestions: [
                TopicSuggestionGroup(
                  topic: 'Paris trip',
                  suggestions: const [
                    TopicSuggestion(
                      kind: TopicSuggestionKind.ask,
                      text: 'Ask how the Paris plans are coming together.',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Paris trip'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ask how the Paris plans are coming together.'),
        findsOneWidget,
      );
      expect(find.text("How's the Paris trip going?"), findsNothing);
    });

    testWidgets('tapping a topic pill shows up to 2 prepared suggestions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AiInsightsCard(
            connection: _connection(category: 'Friends'),
            insight: _insight(),
            memory: MemoryDocument(
              contactId: 'test',
              displayName: 'Test Person',
              lastUpdated: DateTime.utc(2026, 6, 4),
              topics: const ['Paris trip'],
              topicSuggestions: [
                TopicSuggestionGroup(
                  topic: 'Paris trip',
                  suggestions: const [
                    TopicSuggestion(
                      kind: TopicSuggestionKind.ask,
                      text: 'Ask how the Paris plans are coming together.',
                    ),
                    TopicSuggestion(
                      kind: TopicSuggestionKind.share,
                      text: 'Share a café rec if you spot one.',
                    ),
                    TopicSuggestion(
                      kind: TopicSuggestionKind.plan,
                      text: 'Suggest a quick call before the trip.',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Paris trip'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ask how the Paris plans are coming together.'),
        findsOneWidget,
      );
      expect(find.text('Share a café rec if you spot one.'), findsOneWidget);
      expect(find.text('Suggest a quick call before the trip.'), findsNothing);
    });

    testWidgets('selected topic does not show another topic suggestion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AiInsightsCard(
            connection: _connection(category: 'Friends'),
            insight: _insight(),
            memory: MemoryDocument(
              contactId: 'test',
              displayName: 'Test Person',
              lastUpdated: DateTime.utc(2026, 6, 4),
              topics: const ['Paris trip', 'pottery'],
              topicSuggestions: [
                TopicSuggestionGroup(
                  topic: 'Paris trip',
                  suggestions: const [
                    TopicSuggestion(
                      kind: TopicSuggestionKind.ask,
                      text: 'Ask how the Paris plans are coming together.',
                    ),
                  ],
                ),
                TopicSuggestionGroup(
                  topic: 'pottery',
                  suggestions: const [
                    TopicSuggestion(
                      kind: TopicSuggestionKind.ask,
                      text: 'Ask about the latest pottery class.',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Paris trip'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ask how the Paris plans are coming together.'),
        findsOneWidget,
      );
      expect(find.text('Ask about the latest pottery class.'), findsNothing);
    });

    testWidgets('selected topic panel omits global and placeholder context', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AiInsightsCard(
            connection: _connection(category: 'Friends'),
            insight: _insight(),
            memory: MemoryDocument(
              contactId: 'test',
              displayName: 'Test Person',
              lastUpdated: DateTime.utc(2026, 6, 4),
              summary: 'They are focused on pottery right now.',
              history: '- 2026-06-04 — Talked about pottery kiln plans.',
              topics: const ['Paris trip'],
              topicSuggestions: [
                TopicSuggestionGroup(
                  topic: 'Paris trip',
                  suggestions: const [
                    TopicSuggestion(
                      kind: TopicSuggestionKind.ask,
                      text: 'Ask how the Paris plans are coming together.',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Paris trip'));
      await tester.pumpAndSettle();

      expect(find.text('Conversation Starter :'), findsWidgets);
      expect(find.text('Past Conversations:'), findsNothing);
      expect(find.text('Current Context:'), findsNothing);
      expect(find.text('Related News:'), findsNothing);
      expect(find.text('Mother\'s Day coming up May 11th'), findsNothing);
      expect(find.text('They are focused on pottery right now.'), findsNothing);
      expect(
        find.text('- 2026-06-04 — Talked about pottery kiln plans.'),
        findsNothing,
      );
    });

    testWidgets(
      'tapping a topic pill renders conversation starter and context when context is present',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            AiInsightsCard(
              connection: _connection(category: 'Friends'),
              insight: _insight(),
              memory: MemoryDocument(
                contactId: 'test',
                displayName: 'Test Person',
                lastUpdated: DateTime.utc(2026, 6, 4),
                topics: const ['Paris trip'],
                topicSuggestions: [
                  TopicSuggestionGroup(
                    topic: 'Paris trip',
                    suggestions: const [
                      TopicSuggestion(
                        kind: TopicSuggestionKind.ask,
                        text: 'Ask how the Paris plans are coming together.',
                        context:
                            'he talked about his plan to Paris last time and he was very excited about it',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Paris trip'));
        await tester.pumpAndSettle();

        expect(find.text('Conversation Starter :'), findsWidgets);
        expect(find.text('Context :'), findsWidgets);
        expect(
          find.text('Ask how the Paris plans are coming together.'),
          findsOneWidget,
        );
        expect(
          find.text(
            'he talked about his plan to Paris last time and he was very excited about it',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping a topic pill falls back when prepared suggestions are missing',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            AiInsightsCard(
              connection: _connection(category: 'Friends'),
              insight: _insight(),
              memory: MemoryDocument(
                contactId: 'test',
                displayName: 'Test Person',
                lastUpdated: DateTime.utc(2026, 6, 4),
                topics: const ['Paris trip'],
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Paris trip'));
        await tester.pumpAndSettle();

        expect(find.text("How's the Paris trip going?"), findsOneWidget);
        expect(find.text('Context :'), findsNothing);
      },
    );

    testWidgets(
      'tapping a topic pill falls back when prepared suggestions are expired',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            AiInsightsCard(
              connection: _connection(category: 'Friends'),
              insight: _insight(),
              memory: MemoryDocument(
                contactId: 'test',
                displayName: 'Test Person',
                lastUpdated: DateTime.utc(2026, 6, 4),
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
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Paris trip'));
        await tester.pumpAndSettle();

        expect(find.text("How's the Paris trip going?"), findsOneWidget);
        expect(
          find.text('Ask how the Paris plans are coming together.'),
          findsNothing,
        );
        expect(find.text('Context :'), findsNothing);
      },
    );

    testWidgets('tapping a topic pill shows suggestions inline', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AiInsightsCard(
            connection: _connection(category: 'Family'),
            insight: _insight(),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Family updates'));
      await tester.pumpAndSettle();
      // Sheet shows at least one suggestion from suggestionsForTopic('Family', 'Family updates').
      expect(find.text('Ask how the family is doing'), findsOneWidget);
    });

    testWidgets('tapping the header collapses and reveals the body again', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(AiInsightsCard(connection: _connection(), insight: _insight())),
      );
      await tester.pump();
      // Expanded by default — chevron is "less" (up arrow).
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.text('Recommendation'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ai-insights-header')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      // Body is gone after collapse.
      expect(find.text('Recommendation'), findsNothing);

      await tester.tap(find.byKey(const Key('ai-insights-header')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.text('Recommendation'), findsOneWidget);
    });

    testWidgets('long topic labels truncate without overflowing', (
      tester,
    ) async {
      // Use the generic-defaults path with a category that doesn't exist;
      // we don't have a way to inject a 32-char topic externally, so this
      // test mainly asserts no overflow exception fires when the existing
      // topics render at narrow phone widths.
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(
          AiInsightsCard(
            connection: _connection(category: 'High School'),
            insight: _insight(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('disableAnimations skips the collapse animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AiInsightsCard(connection: _connection(), insight: _insight()),
          disableAnimations: true,
        ),
      );
      await tester.pump();
      expect(find.text('Recommendation'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ai-insights-header')));
      // Under disableAnimations the AnimatedSize duration is zero;
      // pumpAndSettle should resolve immediately without spinning.
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(find.text('Recommendation'), findsNothing);
    });

    testWidgets('refresh button is present in card header', (tester) async {
      await tester.pumpWidget(
        _wrap(AiInsightsCard(connection: _connection(), insight: _insight())),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('ai-insights-refresh-button')),
        findsOneWidget,
      );
    });

    testWidgets(
      'tapping refresh button does not toggle expand/collapse state',
      (tester) async {
        final mockEnricher = FakeMemoryTopicEnricher(
          topicsToReturn: const ['pottery'],
          suggestionsToReturn: const [],
        );
        final mockStore = InMemoryMemoryStore();

        await tester.pumpWidget(
          _wrap(
            AiInsightsCard(connection: _connection(), insight: _insight()),
            overrides: [
              memoryTopicEnricherProvider.overrideWithValue(mockEnricher),
              memoryStoreProvider.overrideWithValue(mockStore),
            ],
          ),
        );
        await tester.pump();

        // Expanded by default
        expect(find.text('Recommendation'), findsOneWidget);

        // Tap refresh
        await tester.tap(find.byKey(const Key('ai-insights-refresh-button')));
        await tester.pumpAndSettle();

        // Still expanded!
        expect(find.text('Recommendation'), findsOneWidget);
      },
    );

    testWidgets(
      'refresh success path updates memory document and shows SnackBar',
      (tester) async {
        final completer = Completer<MemoryDocument>();
        final mockEnricher = DelayingMemoryTopicEnricher(completer.future);
        final mockStore = InMemoryMemoryStore();
        final clockTime = DateTime.utc(2026, 6, 13, 21, 0, 0);

        await tester.pumpWidget(
          _wrap(
            AiInsightsCard(connection: _connection(), insight: _insight()),
            overrides: [
              memoryTopicEnricherProvider.overrideWithValue(mockEnricher),
              memoryStoreProvider.overrideWithValue(mockStore),
              clockProvider.overrideWithValue(() => clockTime),
              interactionsByContactProvider('test').overrideWithValue(const []),
            ],
          ),
        );
        await tester.pump();

        // Tap refresh
        await tester.tap(find.byKey(const Key('ai-insights-refresh-button')));

        // Pump to trigger async start (shows loading spinner)
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          find.byKey(const Key('ai-insights-refresh-button')),
          findsNothing,
        );

        // Complete the future
        completer.complete(
          MemoryDocument(
            contactId: 'test',
            displayName: 'Test Person',
            lastUpdated: clockTime,
            topics: const ['hiking'],
            topicSuggestions: const [
              TopicSuggestionGroup(
                topic: 'hiking',
                suggestions: [
                  TopicSuggestion(
                    kind: TopicSuggestionKind.ask,
                    text: 'Ask about their hiking trip.',
                  ),
                ],
              ),
            ],
          ),
        );

        // Finish async work
        await tester.pumpAndSettle();

        // SnackBar shows success
        expect(find.text('AI Insights refreshed.'), findsOneWidget);
        expect(
          find.byKey(const Key('ai-insights-refresh-button')),
          findsOneWidget,
        );

        // Check saved document in mock store
        final savedDoc = await mockStore.load('test');
        expect(savedDoc, isNotNull);
        expect(savedDoc!.topics, contains('hiking'));
        expect(savedDoc.lastUpdated, clockTime);
      },
    );

    testWidgets(
      'refresh failure path shows SnackBar with error and restores button',
      (tester) async {
        final mockEnricher = FakeMemoryTopicEnricher(
          topicsToReturn: const [],
          suggestionsToReturn: const [],
          failOnNetwork: true,
        );
        final mockStore = InMemoryMemoryStore();

        await tester.pumpWidget(
          _wrap(
            AiInsightsCard(connection: _connection(), insight: _insight()),
            overrides: [
              memoryTopicEnricherProvider.overrideWithValue(mockEnricher),
              memoryStoreProvider.overrideWithValue(mockStore),
              interactionsByContactProvider('test').overrideWithValue(const []),
            ],
          ),
        );
        await tester.pump();

        // Tap refresh
        await tester.tap(find.byKey(const Key('ai-insights-refresh-button')));
        await tester.pump(); // Start async work
        await tester.pumpAndSettle(); // Finish async work

        // SnackBar shows failure
        expect(
          find.text(
            'Failed to refresh AI Insights: MemoryTopicEnricherFailure: Injected network failure',
          ),
          findsOneWidget,
        );
        // Button is restored
        expect(
          find.byKey(const Key('ai-insights-refresh-button')),
          findsOneWidget,
        );
      },
    );
  });
}

class DelayingMemoryTopicEnricher implements MemoryTopicEnricher {
  DelayingMemoryTopicEnricher(this.future);
  final Future<MemoryDocument> future;

  @override
  Future<MemoryDocument> enrich({
    required Connection contact,
    required MemoryDocument currentMemory,
    required List<CrmInteraction> recentInteractions,
  }) {
    return future;
  }
}
