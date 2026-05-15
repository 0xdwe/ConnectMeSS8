import 'package:connect_me/src/app/connect_me_app.dart';
import 'package:connect_me/src/features/contact_profile_screen.dart';
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
      
      // Yellow InsightCard should NOT be present (no "AI Insight" expandable card)
      expect(find.text('AI Insight'), findsNothing);
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

    testWidgets('profile shows RelationshipFactsCard', (tester) async {
      await pumpProfileScreen(tester, 'jessica');

      // Relationship facts should be visible
      expect(find.text('Relationship'), findsOneWidget);
      expect(find.text('Known Since'), findsOneWidget);
      expect(find.textContaining('Last contact:'), findsOneWidget);
    });

    testWidgets('profile shows History section with interactions', (tester) async {
      await pumpProfileScreen(tester, 'mike');

      // History section should be present (Mike has interactions in seed data)
      expect(find.text('History'), findsOneWidget);
      
      // Should show interaction items
      expect(find.textContaining('Job'), findsAtLeastNWidgets(1));
    });

    testWidgets('profile shows warm empty copy when no history', (tester) async {
      await pumpProfileScreen(tester, 'jessica');

      // Jessica has no interactions, should show warm empty state
      // History section should not appear when empty
      expect(find.text('History'), findsNothing);
      
      // Should show warm empty copy ("Jessica's new")
      expect(find.textContaining('new'), findsOneWidget);
    });

    testWidgets('profile shows Update with AI button', (tester) async {
      await pumpProfileScreen(tester, 'jessica');

      // Update with AI button should be present
      expect(find.byKey(const Key('update-with-ai-button')), findsOneWidget);
      expect(find.text('Update with AI'), findsOneWidget);
    });

    testWidgets('profile shows Edit action in AppBar', (tester) async {
      await pumpProfileScreen(tester, 'jessica');

      // Edit button should be in AppBar
      expect(find.widgetWithIcon(IconButton, Icons.edit), findsOneWidget);
    });
  });
}
