import 'dart:async';

import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:connect_me/src/widgets/crm_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_me/src/state/firebase_providers.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_topic_backfill_runner.dart';
import 'package:connect_me/src/state/query_providers.dart';
import 'package:connect_me/src/ai/memory_topic_enricher.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

// Builds a minimal MaterialApp wrapper with the project's theme so that
// `context.tokens` resolves and Material-required ancestors are present.
// Returns both the widget and the [ProviderContainer] so tests can mutate
// providers directly.
//
// [contactId] is used to override [interactionsByContactProvider] for the
// card's contact so Firebase-backed providers are not initialized.
({Widget widget, ProviderContainer container}) _wrapWithContainer(
  Widget child, {
  bool disableAnimations = false,
  String contactId = 'rebuild-spinner',
  List<dynamic> overrides = const [],
}) {
  final mockAuth = MockFirebaseAuth(signedIn: false);
  final container = ProviderContainer(
    overrides: [
      firebaseAuthProvider.overrideWithValue(mockAuth),
      // _InlineTopicDetails watches this provider; give tests a default
      // empty interaction list so they don't need Firebase AppController.
      interactionsByContactProvider('test').overrideWithValue(const []),
      interactionsByContactProvider(contactId).overrideWithValue(const []),
      ...overrides,
    ],
  );
  return (
    widget: UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.data(false),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    ),
    container: container,
  );
}

Widget _wrap(
  Widget child, {
  bool disableAnimations = false,
  List<dynamic> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      interactionsByContactProvider('test').overrideWithValue(const []),
      ...overrides,
    ],
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
        _wrap(
          AiInsightsCard(connection: _connection(), insight: _insight()),
          overrides: [
            recommendationsProvider.overrideWith((ref) async => const []),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('AI Insights'), findsOneWidget);
      // No recommendation for this contact → no banner (#118).
      expect(find.text('Person Summary'), findsOneWidget);
      expect(find.text('Conversation Topics'), findsOneWidget);
      expect(
        find.text('Click any topic to see AI suggestions.'),
        findsOneWidget,
      );
    });

    testWidgets('active recommendation banner renders reason + insight + action', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AiInsightsCard(
            connection: _connection(id: 'test'),
            insight: _insight(contactId: 'test'),
          ),
          overrides: [
            recommendationsProvider.overrideWith(
              (ref) async => [
                Recommendation(
                  contactId: 'test',
                  reason: 'Wondering how Test Person has been?',
                  insight: 'Last chat was a few weeks ago.',
                  priority: 'medium priority',
                  action: 'Send a quick hello.',
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recommendation'), findsOneWidget);
      expect(
        find.text('Wondering how Test Person has been?'),
        findsOneWidget,
      );
      expect(
        find.text('Last chat was a few weeks ago.'),
        findsOneWidget,
      );
      expect(find.text('Send a quick hello.'), findsOneWidget);
    });

    testWidgets('completed recommendation banner renders checkmark + reached out text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AiInsightsCard(
            connection: _connection(id: 'test'),
            insight: _insight(contactId: 'test'),
          ),
          overrides: [
            recommendationsProvider.overrideWith(
              (ref) async => [
                Recommendation(
                  contactId: 'test',
                  reason: '✓ Reached out to Test Person',
                  insight: 'Just updated with AI',
                  priority: 'completed',
                  isCompleted: true,
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Completed'), findsOneWidget);
      expect(
        find.text('✓ Reached out to Test Person'),
        findsOneWidget,
      );
      expect(find.text('Just updated with AI'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('no banner when recommendation list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AiInsightsCard(connection: _connection(), insight: _insight()),
          overrides: [
            recommendationsProvider.overrideWith((ref) async => const []),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Recommendation'), findsNothing);
      expect(find.text('Completed'), findsNothing);
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
          overrides: [
            recommendationsProvider.overrideWith((ref) async => const []),
          ],
        ),
      );
      await tester.pump();
      // The summary now appears both in the Relationship Health card
      // snippet and in the Person Summary body.
      expect(
        find.text('Bespoke summary string for this test.'),
        findsWidgets,
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
          overrides: [
            recommendationsProvider.overrideWith((ref) async => const []),
          ],
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
          overrides: [
            recommendationsProvider.overrideWith((ref) async => const []),
          ],
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
          overrides: [
            recommendationsProvider.overrideWith((ref) async => const []),
          ],
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
          overrides: [
            recommendationsProvider.overrideWith((ref) async => const []),
          ],
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
          overrides: [
            recommendationsProvider.overrideWith((ref) async => const []),
          ],
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
          overrides: [
            recommendationsProvider.overrideWith((ref) async => const []),
          ],
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
            overrides: [
              recommendationsProvider.overrideWith((ref) async => const []),
            ],
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
            overrides: [
              recommendationsProvider.overrideWith((ref) async => const []),
            ],
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
            overrides: [
              recommendationsProvider.overrideWith((ref) async => const []),
            ],
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
          overrides: [
            recommendationsProvider.overrideWith((ref) async => const []),
          ],
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
        _wrap(
          AiInsightsCard(connection: _connection(), insight: _insight()),
          overrides: [
            recommendationsProvider.overrideWith((ref) async => const []),
          ],
        ),
      );
      await tester.pump();
      // Expanded by default — chevron is "less" (up arrow).
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      // No recommendation for this contact → no banner, but Person Summary
      // is always visible when expanded (#118).
      expect(find.text('Person Summary'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ai-insights-header')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      // Body is gone after collapse.
      expect(find.text('Person Summary'), findsNothing);

      await tester.tap(find.byKey(const Key('ai-insights-header')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.text('Person Summary'), findsOneWidget);
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
          overrides: [
            recommendationsProvider.overrideWith((ref) async => const []),
          ],
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
          overrides: [
            recommendationsProvider.overrideWith((ref) async => const []),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Person Summary'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ai-insights-header')));
      // Under disableAnimations the AnimatedSize duration is zero;
      // pumpAndSettle should resolve immediately without spinning.
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(find.text('Person Summary'), findsNothing);
    });

    testWidgets('refresh button is present in card header', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AiInsightsCard(connection: _connection(), insight: _insight()),
          overrides: [
            recommendationsProvider.overrideWith((ref) async => const []),
          ],
        ),
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
              recommendationsProvider.overrideWith((ref) async => const []),
              memoryTopicEnricherProvider.overrideWithValue(mockEnricher),
              memoryStoreProvider.overrideWithValue(mockStore),
            ],
          ),
        );
        await tester.pump();

        // Expanded by default — Person Summary always visible when expanded (#118).
        expect(find.text('Person Summary'), findsOneWidget);

        // Tap refresh
        await tester.tap(find.byKey(const Key('ai-insights-refresh-button')));
        await tester.pumpAndSettle();

        // Still expanded!
        expect(find.text('Person Summary'), findsOneWidget);
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
              recommendationsProvider.overrideWith((ref) async => const []),
              memoryTopicEnricherProvider.overrideWithValue(mockEnricher),
              memoryStoreProvider.overrideWithValue(mockStore),
            clockProvider.overrideWithValue(() => clockTime),
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
              recommendationsProvider.overrideWith((ref) async => const []),
              memoryTopicEnricherProvider.overrideWithValue(mockEnricher),
              memoryStoreProvider.overrideWithValue(mockStore),
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

    testWidgets(
      'renders Latest News block when latestNews is present in topic suggestions',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            AiInsightsCard(
              connection: _connection(category: 'Friends'),
              insight: _insight(),
              initialSelectedTopic: 'Lombok',
              memory: MemoryDocument(
                contactId: 'test',
                displayName: 'Test Person',
                lastUpdated: DateTime.utc(2026, 6, 4),
                topics: const ['Lombok'],
                topicSuggestions: [
                  TopicSuggestionGroup(
                    topic: 'Lombok',
                    suggestions: const [
                      TopicSuggestion(
                        kind: TopicSuggestionKind.ask,
                        text: 'Ask how Lombok is.',
                        context: 'Planning a trip to Lombok',
                        latestNews: 'Earthquake reported near Lombok with no damage.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            overrides: [
              recommendationsProvider.overrideWith((ref) async => const []),
            ],
          ),
        );
        await tester.pump();

        expect(find.text('Latest News :'), findsOneWidget);
        expect(
          find.text('Earthquake reported near Lombok with no damage.'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.newspaper), findsOneWidget);
      },
    );

    group('Relationship Health card', () {
      final now = DateTime.utc(2026, 6, 15, 12, 0, 0);

      List<dynamic> healthOverrides({
        String contactId = 'health',
        List<CrmInteraction> interactions = const [],
        List<Recommendation> recommendations = const [],
      }) {
        return [
          clockProvider.overrideWithValue(() => now),
          interactionsByContactProvider(contactId).overrideWithValue(
            interactions,
          ),
          recommendationsProvider.overrideWith((ref) async => recommendations),
        ];
      }

      testWidgets(
        'shows health card when no recommendation exists and memorySummary is non-empty',
        (tester) async {
          await tester.pumpWidget(
            _wrap(
              AiInsightsCard(
                connection: _connection(id: 'health'),
                insight: _insight(contactId: 'health'),
                memorySummary: 'Memory summary for a healthy relationship.',
              ),
              overrides: healthOverrides(
                interactions: [
                  CrmInteraction(
                    id: 'i1',
                    contactId: 'health',
                    type: InteractionType.interaction,
                    title: 'Catch-up',
                    note: 'Talked about life.',
                    date: now.subtract(const Duration(days: 2)),
                  ),
                ],
              ),
            ),
          );
          await tester.pump();

          expect(find.text('Relationship healthy'), findsOneWidget);
          expect(
            find.text('You two connected very recently.'),
            findsOneWidget,
          );
          // The snippet is rendered in the Relationship Health card (and
          // also appears verbatim in the Person Summary body).
          expect(
            find.text('Memory summary for a healthy relationship.'),
            findsWidgets,
          );
          expect(find.byIcon(Icons.favorite_outline), findsOneWidget);
        },
      );

      testWidgets(
        'hides health card when no recommendation exists and memorySummary is null',
        (tester) async {
          await tester.pumpWidget(
            _wrap(
              AiInsightsCard(
                connection: _connection(id: 'health'),
                insight: _insight(contactId: 'health'),
              ),
              overrides: healthOverrides(),
            ),
          );
          await tester.pump();

          expect(find.text('Relationship healthy'), findsNothing);
          expect(find.text('You two connected very recently.'), findsNothing);
          expect(find.text('You\'ve been in touch recently.'), findsNothing);
          expect(find.text('You\'ve kept in touch regularly.'), findsNothing);
        },
      );

      testWidgets(
        'hides health card when no recommendation exists and memorySummary is empty',
        (tester) async {
          await tester.pumpWidget(
            _wrap(
              AiInsightsCard(
                connection: _connection(id: 'health'),
                insight: _insight(contactId: 'health'),
                memorySummary: '   ',
              ),
              overrides: healthOverrides(),
            ),
          );
          await tester.pump();

          expect(find.text('Relationship healthy'), findsNothing);
        },
      );

      testWidgets(
        'hides health card when an active recommendation exists',
        (tester) async {
          await tester.pumpWidget(
            _wrap(
              AiInsightsCard(
                connection: _connection(id: 'health'),
                insight: _insight(contactId: 'health'),
                memorySummary: 'Healthy but has an active rec.',
              ),
              overrides: healthOverrides(
                recommendations: [
                  Recommendation(
                    contactId: 'health',
                    reason: 'Time to reconnect.',
                    insight: 'It has been a while.',
                    priority: 'medium priority',
                    action: 'Send a message.',
                  ),
                ],
              ),
            ),
          );
          await tester.pump();

          expect(find.text('Recommendation'), findsOneWidget);
          expect(find.text('Relationship healthy'), findsNothing);
          expect(find.byIcon(Icons.favorite_outline), findsNothing);
        },
      );

      testWidgets(
        'hides health card when a completed recommendation exists',
        (tester) async {
          await tester.pumpWidget(
            _wrap(
              AiInsightsCard(
                connection: _connection(id: 'health'),
                insight: _insight(contactId: 'health'),
                memorySummary: 'Healthy but just completed.',
              ),
              overrides: healthOverrides(
                recommendations: [
                  Recommendation(
                    contactId: 'health',
                    reason: '✓ Reached out',
                    insight: 'Just updated with AI',
                    priority: 'completed',
                    isCompleted: true,
                  ),
                ],
              ),
            ),
          );
          await tester.pump();

          expect(find.text('Completed'), findsOneWidget);
          expect(find.text('Relationship healthy'), findsNothing);
          expect(find.byIcon(Icons.favorite_outline), findsNothing);
        },
      );

      testWidgets('qualitative recency string respects the 3-day bucket', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            AiInsightsCard(
              connection: _connection(id: 'health'),
              insight: _insight(contactId: 'health'),
              memorySummary: 'Memory.',
            ),
            overrides: healthOverrides(
              interactions: [
                CrmInteraction(
                  id: 'i1',
                  contactId: 'health',
                  type: InteractionType.interaction,
                  title: 'Catch-up',
                  note: 'Talked about life.',
                  date: now.subtract(const Duration(days: 3)),
                ),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(find.text('You two connected very recently.'), findsOneWidget);
      });

      testWidgets('qualitative recency string respects the 14-day bucket', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            AiInsightsCard(
              connection: _connection(id: 'health'),
              insight: _insight(contactId: 'health'),
              memorySummary: 'Memory.',
            ),
            overrides: healthOverrides(
              interactions: [
                CrmInteraction(
                  id: 'i1',
                  contactId: 'health',
                  type: InteractionType.interaction,
                  title: 'Catch-up',
                  note: 'Talked about life.',
                  date: now.subtract(const Duration(days: 14)),
                ),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(find.text('You\'ve been in touch recently.'), findsOneWidget);
      });

      testWidgets('qualitative recency string uses the regular bucket beyond 14 days', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            AiInsightsCard(
              connection: _connection(id: 'health'),
              insight: _insight(contactId: 'health'),
              memorySummary: 'Memory.',
            ),
            overrides: healthOverrides(
              interactions: [
                CrmInteraction(
                  id: 'i1',
                  contactId: 'health',
                  type: InteractionType.interaction,
                  title: 'Catch-up',
                  note: 'Talked about life.',
                  date: now.subtract(const Duration(days: 15)),
                ),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(find.text('You\'ve kept in touch regularly.'), findsOneWidget);
      });

      testWidgets('memory summary snippet is truncated to 120 chars with ellipsis', (
        tester,
      ) async {
        final longSummary = 'A' * 150;
        final truncated = '${'A' * 120}...';

        await tester.pumpWidget(
          _wrap(
            AiInsightsCard(
              connection: _connection(id: 'health'),
              insight: _insight(contactId: 'health'),
              memorySummary: longSummary,
            ),
            overrides: healthOverrides(),
          ),
        );
        await tester.pump();

        expect(find.text(truncated), findsOneWidget);
      });

    });

    group('pendingMemoryRebuildProvider spinner', () {
      testWidgets('shows spinner when provider matches connection id', (
        tester,
      ) async {
        final wrapped = _wrapWithContainer(
          AiInsightsCard(
            connection: _connection(id: 'rebuild-spinner'),
            insight: _insight(contactId: 'rebuild-spinner'),
          ),
          overrides: [
            recommendationsProvider.overrideWith((ref) async => const []),
          ],
        );
        addTearDown(wrapped.container.dispose);
        await tester.pumpWidget(wrapped.widget);
        await tester.pump();

        // Initially no spinner — refresh button is visible
        expect(find.byIcon(Icons.refresh), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Set the provider to trigger the spinner
        wrapped.container
            .read(pendingMemoryRebuildProvider.notifier)
            .setContactId('rebuild-spinner');
        await tester.pump();

        // Spinner should be visible, refresh button gone
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsNothing);
      });

      testWidgets('spinner clears when provider is set to null', (tester) async {
        final wrapped = _wrapWithContainer(
          AiInsightsCard(
            connection: _connection(id: 'rebuild-spinner'),
            insight: _insight(contactId: 'rebuild-spinner'),
          ),
          overrides: [
            recommendationsProvider.overrideWith((ref) async => const []),
          ],
        );
        addTearDown(wrapped.container.dispose);
        await tester.pumpWidget(wrapped.widget);
        await tester.pump();

        // Set provider to show spinner
        wrapped.container
            .read(pendingMemoryRebuildProvider.notifier)
            .setContactId('rebuild-spinner');
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Clear provider — spinner should disappear
        wrapped.container
            .read(pendingMemoryRebuildProvider.notifier)
            .setContactId(null);
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byIcon(Icons.refresh), findsOneWidget);
      });

      testWidgets('different contact ID does not trigger spinner', (
        tester,
      ) async {
        final wrapped = _wrapWithContainer(
          AiInsightsCard(
            connection: _connection(id: 'rebuild-spinner'),
            insight: _insight(contactId: 'rebuild-spinner'),
          ),
          overrides: [
            recommendationsProvider.overrideWith((ref) async => const []),
          ],
        );
        addTearDown(wrapped.container.dispose);
        await tester.pumpWidget(wrapped.widget);
        await tester.pump();

        // Set provider for a different contact
        wrapped.container
            .read(pendingMemoryRebuildProvider.notifier)
            .setContactId('other-contact');
        await tester.pump();

        // Spinner should NOT appear for this card
        expect(find.byIcon(Icons.refresh), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('manual refresh still works independently', (tester) async {
        final mockEnricher = FakeMemoryTopicEnricher(
          topicsToReturn: const ['pottery'],
          suggestionsToReturn: const [],
        );
        final mockStore = InMemoryMemoryStore();

        final wrapped = _wrapWithContainer(
          AiInsightsCard(
            connection: _connection(id: 'rebuild-spinner'),
            insight: _insight(contactId: 'rebuild-spinner'),
          ),
          overrides: [
            recommendationsProvider.overrideWith((ref) async => const []),
            memoryTopicEnricherProvider.overrideWithValue(mockEnricher),
            memoryStoreProvider.overrideWithValue(mockStore),
          ],
        );
        addTearDown(wrapped.container.dispose);
        await tester.pumpWidget(wrapped.widget);
        await tester.pump();

        // Set provider for a different contact (should NOT affect this card)
        wrapped.container
            .read(pendingMemoryRebuildProvider.notifier)
            .setContactId('other-contact');
        await tester.pump();

        // Manual refresh button should still be functional
        expect(find.byIcon(Icons.refresh), findsOneWidget);

        // Tap the refresh button
        await tester.tap(find.byIcon(Icons.refresh));
        await tester.pumpAndSettle();

        // Manual refresh completes normally
        expect(find.text('AI Insights refreshed.'), findsOneWidget);
      });
    });
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
