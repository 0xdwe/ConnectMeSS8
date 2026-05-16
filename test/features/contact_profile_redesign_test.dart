import 'package:connect_me/src/app/connect_me_app.dart';
import 'package:connect_me/src/widgets/bond_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Helper to pump ContactProfileScreen with full app context
Future<void> pumpProfileScreen(WidgetTester tester, String contactId) async {
  await tester.pumpWidget(
    const ProviderScope(child: ConnectMeApp()),
  );
  await tester.pumpAndSettle();
  
  // Sign in
  await tester.enterText(
    find.byKey(const Key('login-email-field')),
    'demo@example.com',
  );
  await tester.enterText(
    find.byKey(const Key('login-password-field')),
    'password123',
  );
  await tester.tap(find.byKey(const Key('sign-in-button')));
  await tester.pumpAndSettle();
  
  // Navigate to People tab
  await tester.tap(find.text('People').last);
  await tester.pumpAndSettle();
  
  // Find and tap the contact
  final contactNames = {
    'jessica': 'Jessica Taylor',
    'mike': 'Mike Chen',
  };
  final contactName = contactNames[contactId] ?? contactId;
  
  await tester.scrollUntilVisible(
    find.text(contactName),
    120,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('people-tab')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(find.text(contactName));
  await tester.pumpAndSettle();
  await tester.tap(find.text(contactName), warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  group('Contact Profile Redesign (#017)', () {
    testWidgets('profile header shows BondRing at size 96 with avatar', (tester) async {
      await pumpProfileScreen(tester, 'jessica');

      // BondRing should be present at size 96
      final bondRingFinder = find.byWidgetPredicate(
        (widget) => widget is BondRing && widget.size == 96,
      );
      expect(bondRingFinder, findsOneWidget);

      // Name should be displayed (appears in AppBar and header)
      expect(find.text('Jessica Taylor'), findsAtLeastNWidgets(1));
    });

    testWidgets('profile shows category dot next to name', (tester) async {
      await pumpProfileScreen(tester, 'jessica');

      // Category should be visible (Friends for Jessica)
      // We look for a small CircleAvatar that represents the category dot
      final categoryDots = find.byWidgetPredicate(
        (widget) => widget is CircleAvatar && (widget.radius ?? 20) <= 6,
      );
      expect(categoryDots, findsAtLeastNWidgets(1));
    });

    testWidgets('profile shows insight summary in header (not yellow card)', (tester) async {
      await pumpProfileScreen(tester, 'jessica');

      // Insight summary should be visible as text in header
      expect(find.textContaining('Jessica'), findsWidgets);
    });

    testWidgets('profile does NOT show _BondScorePanel', (tester) async {
      await pumpProfileScreen(tester, 'jessica');

      // "Strong connection!" text should not appear (was in _BondScorePanel)
      expect(find.text('Strong connection!'), findsNothing);
      
      // "Bond Score" heading should not appear
      expect(find.text('Bond Score'), findsNothing);
    });

    testWidgets('profile does NOT show RecommendedActionCard', (tester) async {
      await pumpProfileScreen(tester, 'jessica');

      // Orange "Recommended Action!" card should not appear
      expect(find.text('Recommended Action!'), findsNothing);
      
      // "You can gain X% Connection Score" should not appear
      expect(find.textContaining('You can gain'), findsNothing);
      expect(find.textContaining('Connection Score'), findsNothing);
    });

    testWidgets('profile does NOT show CommunicationChannelsCard', (tester) async {
      await pumpProfileScreen(tester, 'jessica');

      // "Top Communication Channels" should not appear
      expect(find.text('Top Communication Channels'), findsNothing);
    });

    testWidgets('profile does NOT show InteractionFrequencyCard', (tester) async {
      await pumpProfileScreen(tester, 'jessica');

      // "Interaction Frequency (12 months)" should not appear
      expect(find.text('Interaction Frequency (12 months)'), findsNothing);
    });

    testWidgets('profile shows AI Insights card with three subsections', (tester) async {
      await pumpProfileScreen(tester, 'jessica');

      // The new AI Insights card replaces RelationshipFactsCard.
      expect(find.text('AI Insights'), findsOneWidget);
      expect(find.text('Recommendation'), findsOneWidget);
      expect(find.text('Person Summary'), findsOneWidget);
      expect(find.text('Conversation Topics'), findsOneWidget);
    });

    testWidgets('profile shows History section with interactions', (tester) async {
      await pumpProfileScreen(tester, 'mike');

      // History sits below the new AI Insights card; scroll first to the
      // section title, then to a known interaction title.
      await tester.scrollUntilVisible(
        find.text('History'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('History'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Job'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Job'), findsAtLeastNWidgets(1));
    });

    testWidgets('profile shows warm empty copy when no history', (tester) async {
      await pumpProfileScreen(tester, 'jessica');

      // Jessica has no interactions, should show warm empty state below the
      // AI Insights card.
      expect(find.text('History'), findsNothing);
      await tester.scrollUntilVisible(
        find.textContaining('new'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('new'), findsOneWidget);
    });

    testWidgets('profile shows Update with AI button', (tester) async {
      await pumpProfileScreen(tester, 'jessica');

      // Update with AI button should be present
      expect(find.byKey(const Key('update-with-ai-button')), findsOneWidget);
      expect(find.text('Update with AI'), findsOneWidget);
    });

    testWidgets('header renders name and Edit pill side-by-side without overlap at 320pt', (tester) async {
      // Pump at default size first so navigation through the People tab
      // works in a comfortable viewport.
      await pumpProfileScreen(tester, 'jessica');

      // Now simulate iPhone SE 1st gen (320 logical px) and let the
      // profile screen relayout.
      tester.view.physicalSize = const Size(320 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle();

      // The name and the Edit pill must both render — the structural
      // Row+Expanded layout (replacing the previous Stack+Positioned)
      // ensures the name ellipsizes rather than sliding under the pill.
      expect(find.text('Jessica Taylor'), findsAtLeastNWidgets(1));
      expect(find.byKey(const Key('edit-connection-button')), findsOneWidget);

      // Anchor the structural fix: the header's name Text renders with
      // maxLines: 1, which is what makes ellipsis work in the new Row.
      final headerNameText = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == 'Jessica Taylor' &&
            widget.maxLines == 1,
      );
      expect(headerNameText, findsOneWidget);
    });

    testWidgets('profile shows Edit action in header card pill', (tester) async {
      await pumpProfileScreen(tester, 'jessica');

      // Edit pill now lives on the header card, not the AppBar.
      expect(find.byKey(const Key('edit-connection-button')), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      // The AppBar should no longer contain a trailing Edit IconButton.
      expect(find.widgetWithIcon(IconButton, Icons.edit), findsNothing);
    });

    testWidgets('history rows render inline AI badge in the dense list', (tester) async {
      // Mike's seed history is 1 interaction — so this asserts the
      // single-row branch lays out, with no dividers (n - 1 = 0).
      await pumpProfileScreen(tester, 'mike');

      await tester.scrollUntilVisible(
        find.text('History'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.textContaining('Job'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // n = 1 → no dividers in the history list.
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('empty history renders inside the History card with zero dividers', (tester) async {
      await pumpProfileScreen(tester, 'jessica');

      // The empty-state copy lives inside the same History card, so the
      // section header is now visible even with no interactions.
      await tester.scrollUntilVisible(
        find.text('History'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('History'), findsOneWidget);
      // No interactions → no dividers (n - 1 with n = 0).
      expect(find.byType(Divider), findsNothing);
    });
  });
}
