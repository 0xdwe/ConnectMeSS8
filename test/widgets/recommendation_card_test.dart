import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:connect_me/src/widgets/bond_ring.dart';
import 'package:connect_me/src/widgets/crm_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecommendationCard', () {
    final testConnection = Connection(
      id: 'test-1',
      name: 'Mike Chen',
      email: 'mike@test.com',
      category: 'Friends',
      avatar: '👨',
      bondScore: 68,
      nextStep: 'Follow up',
      lastContact: DateTime(2026, 4, 1),
      notes: 'Test notes',
      knownSince: DateTime(2020, 1, 1),
      preferredChannels: const ['Text'],
    );

    final testRecommendation = Recommendation(
      contactId: 'test-1',
      reason: "Mike's been quiet for a while.",
      insight: "It's been about 5 weeks since you talked.",
      priority: 'high priority',
    );

    Widget buildTestCard({
      Connection? connection,
      Recommendation? recommendation,
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        theme: AppTheme.data(false),
        home: Scaffold(
          body: RecommendationCard(
            connection: connection ?? testConnection,
            recommendation: recommendation ?? testRecommendation,
            onTap: onTap,
          ),
        ),
      );
    }

    testWidgets('renders contact name with h2 typography', (tester) async {
      await tester.pumpWidget(buildTestCard());

      final nameFinder = find.text('Mike Chen');
      expect(nameFinder, findsOneWidget);

      // Verify it's using h2 style (21pt, weight 600)
      final nameWidget = tester.widget<Text>(nameFinder);
      expect(nameWidget.style?.fontSize, 21);
      expect(nameWidget.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('renders BondRing with 56pt size', (tester) async {
      await tester.pumpWidget(buildTestCard());

      final bondRingFinder = find.byType(BondRing);
      expect(bondRingFinder, findsOneWidget);

      // Verify size is 56
      final bondRing = tester.widget<BondRing>(bondRingFinder);
      expect(bondRing.size, 56);
      expect(bondRing.connection?.id, 'test-1');
    });

    testWidgets('renders conversational headline with bodyLg typography',
        (tester) async {
      await tester.pumpWidget(buildTestCard());

      final headlineFinder = find.text("Mike's been quiet for a while.");
      expect(headlineFinder, findsOneWidget);

      // Verify it's using bodyLg style (17pt, weight 500)
      final headlineWidget = tester.widget<Text>(headlineFinder);
      expect(headlineWidget.style?.fontSize, 17);
      expect(headlineWidget.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('renders insight text with body typography and inkMuted color',
        (tester) async {
      await tester.pumpWidget(buildTestCard());

      final insightFinder =
          find.text("It's been about 5 weeks since you talked.");
      expect(insightFinder, findsOneWidget);

      // Verify it's using body style (15pt, weight 400)
      final insightWidget = tester.widget<Text>(insightFinder);
      expect(insightWidget.style?.fontSize, 15);
      expect(insightWidget.style?.fontWeight, FontWeight.w400);
    });

    testWidgets('does NOT render Update Connection button', (tester) async {
      await tester.pumpWidget(buildTestCard());

      // Action buttons removed in #029. Whole card is the tap target.
      expect(find.widgetWithText(FilledButton, 'Update Connection'),
          findsNothing);
    });

    testWidgets('does NOT render Open profile button', (tester) async {
      await tester.pumpWidget(buildTestCard());

      expect(find.widgetWithText(TextButton, 'Open profile'), findsNothing);
    });

    testWidgets('does NOT render priority text', (tester) async {
      await tester.pumpWidget(buildTestCard());

      expect(find.text('high priority'), findsNothing);
      expect(find.text('medium priority'), findsNothing);
      expect(find.text('low priority'), findsNothing);
    });

    testWidgets('does NOT render warning icon', (tester) async {
      await tester.pumpWidget(buildTestCard());

      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('does NOT render quote bubble emoji', (tester) async {
      await tester.pumpWidget(buildTestCard());

      // The old card had '💬  "' prefix
      expect(find.textContaining('💬'), findsNothing);
    });

    testWidgets('does NOT render trailing chevron', (tester) async {
      await tester.pumpWidget(buildTestCard());

      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('does NOT render highlight border', (tester) async {
      await tester.pumpWidget(buildTestCard());

      // Find the CardBox container
      final cardBoxFinder = find.byType(CardBox);
      expect(cardBoxFinder, findsOneWidget);

      final cardBox = tester.widget<CardBox>(cardBoxFinder);
      expect(cardBox.border, isNull);
    });

    testWidgets('renders category dot with correct color', (tester) async {
      await tester.pumpWidget(buildTestCard());

      // Should find a small circle with category color
      final categoryDotFinder = find.byWidgetPredicate(
        (widget) =>
            widget is CircleAvatar &&
            widget.radius == 4, // 8pt diameter = 4pt radius
      );
      expect(categoryDotFinder, findsOneWidget);
    });

    testWidgets('calls onTap when card is tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildTestCard(onTap: () => tapped = true));

      await tester.tap(find.byType(RecommendationCard));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('action buttons removed; whole card is tappable', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildTestCard(onTap: () => tapped = true));

      // Action buttons removed in #029.
      expect(find.widgetWithText(FilledButton, 'Update Connection'),
          findsNothing);
      expect(find.widgetWithText(TextButton, 'Open profile'), findsNothing);

      // Tapping anywhere on the card still navigates via onTap.
      await tester.tap(find.byType(RecommendationCard));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });
  });
}
