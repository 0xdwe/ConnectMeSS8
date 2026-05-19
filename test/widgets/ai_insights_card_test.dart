import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:connect_me/src/widgets/crm_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Builds a minimal MaterialApp wrapper with the project's theme so that
// `context.tokens` resolves and Material-required ancestors are present.
Widget _wrap(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    theme: AppTheme.data(false),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: SingleChildScrollView(child: child)),
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

ContactInsight _insight({
  String contactId = 'test',
}) {
  return ContactInsight(
    contactId: contactId,
    relationshipLabel: 'Close friend',
    knownSinceYears: 6,
  );
}

void main() {
  group('AiInsightsCard', () {
    testWidgets('renders all three subsections expanded by default',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          AiInsightsCard(connection: _connection(), insight: _insight()),
        ),
      );
      await tester.pump();

      expect(find.text('AI Insights'), findsOneWidget);
      expect(find.text('Recommendation'), findsOneWidget);
      expect(find.text('Person Summary'), findsOneWidget);
      expect(find.text('Conversation Topics'), findsOneWidget);
      expect(find.text('Click any topic to see AI suggestions.'),
          findsOneWidget);
    });

    testWidgets('recommendation copy maps from BondTier (close)',
        (tester) async {
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

    testWidgets('recommendation copy maps from BondTier (steady)',
        (tester) async {
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

    testWidgets('recommendation copy maps from BondTier (drifting)',
        (tester) async {
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

    testWidgets('renders Person Summary body from MemoryDocument.summary',
        (tester) async {
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
      expect(find.text('Bespoke summary string for this test.'),
          findsOneWidget);
    });

    testWidgets('renders four conversation topic pills for known category',
        (tester) async {
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

    testWidgets('tapping a topic pill opens the suggestions bottom sheet',
        (tester) async {
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

    testWidgets('tapping the header collapses and reveals the body again',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          AiInsightsCard(connection: _connection(), insight: _insight()),
        ),
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

    testWidgets('long topic labels truncate without overflowing',
        (tester) async {
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

    testWidgets('disableAnimations skips the collapse animation',
        (tester) async {
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
  });
}
