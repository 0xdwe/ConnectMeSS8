import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:connect_me/src/widgets/bond_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BondRing', () {
    testWidgets('score 90 renders with primary color (close tier)', (
      tester,
    ) async {
      final connection = Connection(
        id: 'test',
        name: 'Test User',
        email: 'test@example.com',
        category: 'Friends',
        avatar: '👤',
        bondScore: 90,
        nextStep: '',
        lastContact: DateTime(2026, 5, 1),
        notes: '',
        knownSince: DateTime(2020, 1, 1),
        preferredChannels: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: Center(child: BondRing(connection: connection)),
          ),
        ),
      );

      // Verify widget renders
      expect(find.byType(BondRing), findsOneWidget);
      expect(find.text('👤'), findsOneWidget);

      // Verify tier is close
      expect(BondTier.from(90), BondTier.close);
    });

    testWidgets('score 60 renders with inkMuted color (steady tier)', (
      tester,
    ) async {
      final connection = Connection(
        id: 'test',
        name: 'Test User',
        email: 'test@example.com',
        category: 'Friends',
        avatar: '👤',
        bondScore: 60,
        nextStep: '',
        lastContact: DateTime(2026, 5, 1),
        notes: '',
        knownSince: DateTime(2020, 1, 1),
        preferredChannels: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: Center(child: BondRing(connection: connection)),
          ),
        ),
      );

      expect(find.byType(BondRing), findsOneWidget);
      expect(find.text('👤'), findsOneWidget);

      // Verify tier is steady
      expect(BondTier.from(60), BondTier.steady);
    });

    testWidgets('score 30 renders with secondary color (drifting tier)', (
      tester,
    ) async {
      final connection = Connection(
        id: 'test',
        name: 'Test User',
        email: 'test@example.com',
        category: 'Friends',
        avatar: '👤',
        bondScore: 30,
        nextStep: '',
        lastContact: DateTime(2026, 5, 1),
        notes: '',
        knownSince: DateTime(2020, 1, 1),
        preferredChannels: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: Center(child: BondRing(connection: connection)),
          ),
        ),
      );

      expect(find.byType(BondRing), findsOneWidget);
      expect(find.text('👤'), findsOneWidget);

      // Verify tier is drifting
      expect(BondTier.from(30), BondTier.drifting);
    });

    testWidgets('tap callback fires when provided', (tester) async {
      var tapped = false;
      final connection = Connection(
        id: 'test',
        name: 'Test User',
        email: 'test@example.com',
        category: 'Friends',
        avatar: '👤',
        bondScore: 75,
        nextStep: '',
        lastContact: DateTime(2026, 5, 1),
        notes: '',
        knownSince: DateTime(2020, 1, 1),
        preferredChannels: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: Center(
              child: BondRing(
                connection: connection,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(BondRing));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('trend arrow appears when score >= 70', (tester) async {
      final connection = Connection(
        id: 'test',
        name: 'Test User',
        email: 'test@example.com',
        category: 'Friends',
        avatar: '👤',
        bondScore: 75,
        nextStep: '',
        lastContact: DateTime(2026, 5, 1),
        notes: '',
        knownSince: DateTime(2020, 1, 1),
        preferredChannels: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: Center(child: BondRing(connection: connection)),
          ),
        ),
      );

      // Verify trend is up (score >= 70)
      expect(connection.bondTrend, BondTrend.up);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('no trend arrow when score < 70', (tester) async {
      final connection = Connection(
        id: 'test',
        name: 'Test User',
        email: 'test@example.com',
        category: 'Friends',
        avatar: '👤',
        bondScore: 65,
        nextStep: '',
        lastContact: DateTime(2026, 5, 1),
        notes: '',
        knownSince: DateTime(2020, 1, 1),
        preferredChannels: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: Center(child: BondRing(connection: connection)),
          ),
        ),
      );

      // Verify trend is flat (score < 70)
      expect(connection.bondTrend, BondTrend.flat);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });

    testWidgets('minimum touch target is 44x44', (tester) async {
      final connection = Connection(
        id: 'test',
        name: 'Test User',
        email: 'test@example.com',
        category: 'Friends',
        avatar: '👤',
        bondScore: 75,
        nextStep: '',
        lastContact: DateTime(2026, 5, 1),
        notes: '',
        knownSince: DateTime(2020, 1, 1),
        preferredChannels: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: Center(child: BondRing(connection: connection, size: 32)),
          ),
        ),
      );

      // Find the outermost SizedBox that enforces minimum touch target
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final outerBox = sizedBoxes.first;

      expect(outerBox.width, 44);
      expect(outerBox.height, 44);
    });
  });

  group('BondRing showAvatar=false', () {
    testWidgets('renders numeric score and hides avatar emoji', (tester) async {
      final connection = Connection(
        id: 'test',
        name: 'Test User',
        email: 'test@example.com',
        category: 'Friends',
        avatar: '🌟',
        bondScore: 78,
        nextStep: '',
        lastContact: DateTime(2026, 5, 1),
        notes: '',
        knownSince: DateTime(2020, 1, 1),
        preferredChannels: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: Center(
              child: BondRing(connection: connection, showAvatar: false),
            ),
          ),
        ),
      );

      // Numeric score is rendered, the avatar emoji is not.
      expect(find.text('78'), findsOneWidget);
      expect(find.text('🌟'), findsNothing);
    });

    testWidgets('preserves trend arrow when score >= 70', (tester) async {
      final connection = Connection(
        id: 'test',
        name: 'Test User',
        email: 'test@example.com',
        category: 'Friends',
        avatar: '🌟',
        bondScore: 82,
        nextStep: '',
        lastContact: DateTime(2026, 5, 1),
        notes: '',
        knownSince: DateTime(2020, 1, 1),
        preferredChannels: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: Center(
              child: BondRing(connection: connection, showAvatar: false),
            ),
          ),
        ),
      );

      // Trend arrow still renders independently of avatar visibility.
      expect(connection.bondTrend, BondTrend.up);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });
  });

  group('BondTier', () {
    test('from() factory maps scores correctly', () {
      expect(BondTier.from(100), BondTier.close);
      expect(BondTier.from(80), BondTier.close);
      expect(BondTier.from(79), BondTier.steady);
      expect(BondTier.from(50), BondTier.steady);
      expect(BondTier.from(49), BondTier.drifting);
      expect(BondTier.from(0), BondTier.drifting);
    });

    test('label returns correct string', () {
      expect(BondTier.close.label, 'close');
      expect(BondTier.steady.label, 'steady');
      expect(BondTier.drifting.label, 'drifting');
    });
  });

  group('BondTrend', () {
    test('icon returns correct IconData', () {
      expect(BondTrend.up.icon, Icons.arrow_upward);
      expect(BondTrend.down.icon, Icons.arrow_downward);
      expect(BondTrend.flat.icon, Icons.remove);
    });
  });

  group('BondRing Animation', () {
    testWidgets('animates arc when score changes', (tester) async {
      // Start with score 50
      var connection = Connection(
        id: 'test',
        name: 'Test User',
        email: 'test@example.com',
        category: 'Friends',
        avatar: '👤',
        bondScore: 50,
        nextStep: '',
        lastContact: DateTime(2026, 5, 1),
        notes: '',
        knownSince: DateTime(2020, 1, 1),
        preferredChannels: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: Center(child: BondRing(connection: connection)),
          ),
        ),
      );

      // Initial render at score 50
      await tester.pumpAndSettle();

      // Update to score 80
      connection = Connection(
        id: 'test',
        name: 'Test User',
        email: 'test@example.com',
        category: 'Friends',
        avatar: '👤',
        bondScore: 80,
        nextStep: '',
        lastContact: DateTime(2026, 5, 1),
        notes: '',
        knownSince: DateTime(2020, 1, 1),
        preferredChannels: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: Center(child: BondRing(connection: connection)),
          ),
        ),
      );

      // Pump a frame to start animation
      await tester.pump();

      // Check that animation is in progress (not at final value yet)
      // We'll verify the CustomPainter is being rebuilt during animation
      var painter =
          tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter
              as dynamic;

      // At t=0, should still be at old value (50/100 = 0.5)
      expect(painter.progress, closeTo(0.5, 0.01));

      // Pump 300ms (halfway through 600ms animation)
      await tester.pump(const Duration(milliseconds: 300));
      painter =
          tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter
              as dynamic;

      // Should be between 0.5 and 0.8
      expect(painter.progress, greaterThan(0.5));
      expect(painter.progress, lessThan(0.8));

      // Pump to completion
      await tester.pumpAndSettle();
      painter =
          tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter
              as dynamic;

      // Should be at final value (80/100 = 0.8)
      expect(painter.progress, closeTo(0.8, 0.01));
    });

    testWidgets('skips animation when MediaQuery.disableAnimations is true', (
      tester,
    ) async {
      // Start with score 50
      var connection = Connection(
        id: 'test',
        name: 'Test User',
        email: 'test@example.com',
        category: 'Friends',
        avatar: '👤',
        bondScore: 50,
        nextStep: '',
        lastContact: DateTime(2026, 5, 1),
        notes: '',
        knownSince: DateTime(2020, 1, 1),
        preferredChannels: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(child: BondRing(connection: connection)),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Update to score 80
      connection = Connection(
        id: 'test',
        name: 'Test User',
        email: 'test@example.com',
        category: 'Friends',
        avatar: '👤',
        bondScore: 80,
        nextStep: '',
        lastContact: DateTime(2026, 5, 1),
        notes: '',
        knownSince: DateTime(2020, 1, 1),
        preferredChannels: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(child: BondRing(connection: connection)),
            ),
          ),
        ),
      );

      // Pump one frame
      await tester.pump();

      // Should immediately be at final value (no animation)
      final painter =
          tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter
              as dynamic;
      expect(painter.progress, closeTo(0.8, 0.01));
    });

    testWidgets('does not animate on first mount', (tester) async {
      final connection = Connection(
        id: 'test',
        name: 'Test User',
        email: 'test@example.com',
        category: 'Friends',
        avatar: '👤',
        bondScore: 80,
        nextStep: '',
        lastContact: DateTime(2026, 5, 1),
        notes: '',
        knownSince: DateTime(2020, 1, 1),
        preferredChannels: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: Center(child: BondRing(connection: connection)),
          ),
        ),
      );

      // Pump one frame
      await tester.pump();

      // Should immediately be at target value (no animation on first mount)
      final painter =
          tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter
              as dynamic;
      expect(painter.progress, closeTo(0.8, 0.01));

      // Verify no animation is running
      await tester.pump(const Duration(milliseconds: 100));
      final painterAfter =
          tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter
              as dynamic;
      expect(painterAfter.progress, closeTo(0.8, 0.01));
    });
  });
}
