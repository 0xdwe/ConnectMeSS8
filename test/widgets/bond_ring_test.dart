import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:connect_me/src/widgets/bond_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BondRing', () {
    testWidgets('score 90 renders with primary color (close tier)', (tester) async {
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
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: BondRing(connection: connection),
            ),
          ),
        ),
      );

      // Verify widget renders
      expect(find.byType(BondRing), findsOneWidget);
      expect(find.text('👤'), findsOneWidget);
      
      // Verify tier is close
      expect(BondTier.from(90), BondTier.close);
    });

    testWidgets('score 60 renders with inkMuted color (steady tier)', (tester) async {
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
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: BondRing(connection: connection),
            ),
          ),
        ),
      );

      expect(find.byType(BondRing), findsOneWidget);
      expect(find.text('👤'), findsOneWidget);
      
      // Verify tier is steady
      expect(BondTier.from(60), BondTier.steady);
    });

    testWidgets('score 30 renders with secondary color (drifting tier)', (tester) async {
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
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: BondRing(connection: connection),
            ),
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
          theme: AppTheme.light(),
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
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: BondRing(connection: connection),
            ),
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
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: BondRing(connection: connection),
            ),
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
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: BondRing(connection: connection, size: 32),
            ),
          ),
        ),
      );

      // Find the SizedBox that enforces minimum touch target
      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(Stack),
          matching: find.byType(SizedBox),
        ).first,
      );

      expect(sizedBox.width, 44);
      expect(sizedBox.height, 44);
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
}
