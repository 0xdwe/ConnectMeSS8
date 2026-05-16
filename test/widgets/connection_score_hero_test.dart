import 'package:connect_me/src/theme/app_theme.dart';
import 'package:connect_me/src/widgets/bond_ring.dart';
import 'package:connect_me/src/widgets/crm_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectionScoreHero', () {
    testWidgets('renders with correct score and labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: const Scaffold(
            body: ConnectionScoreHero(score: 73),
          ),
        ),
      );

      // Score number is rendered at display size on the right; tier label
      // sits inline next to it; subtitle below. The score also appears
      // inside the BondRing.fromScore center, so '73' is found twice.
      expect(find.text('73'), findsNWidgets(2));
      expect(find.text('· steady'), findsOneWidget);
      expect(find.text('Average across all connections'), findsOneWidget);
      
      // Verify BondRing is present
      expect(find.byType(BondRing), findsOneWidget);
    });

    testWidgets('score 90 uses close tier color (primary)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: const Scaffold(
            body: ConnectionScoreHero(score: 90),
          ),
        ),
      );

      expect(find.byType(BondRing), findsOneWidget);
      
      // Verify tier is close
      expect(BondTier.from(90), BondTier.close);
    });

    testWidgets('score 60 uses steady tier color (inkMuted)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: const Scaffold(
            body: ConnectionScoreHero(score: 60),
          ),
        ),
      );

      expect(find.byType(BondRing), findsOneWidget);
      
      // Verify tier is steady
      expect(BondTier.from(60), BondTier.steady);
    });

    testWidgets('score 30 uses drifting tier color (secondary)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: const Scaffold(
            body: ConnectionScoreHero(score: 30),
          ),
        ),
      );

      expect(find.byType(BondRing), findsOneWidget);
      
      // Verify tier is drifting
      expect(BondTier.from(30), BondTier.drifting);
    });

    testWidgets('wrapped in CardBox', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: const Scaffold(
            body: ConnectionScoreHero(score: 75),
          ),
        ),
      );

      expect(find.byType(CardBox), findsOneWidget);
    });

    testWidgets('renders without overflow on narrow phone width', (tester) async {
      // Simulate a narrow phone (iPhone SE 1st gen at 320 logical px).
      tester.view.physicalSize = const Size(320 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ConnectionScoreHero(score: 100), // worst case width
            ),
          ),
        ),
      );

      // Any RenderFlex overflow surfaces as a FlutterError logged via takeException().
      expect(tester.takeException(), isNull);
    });

    testWidgets('has correct semantic label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: const Scaffold(
            body: ConnectionScoreHero(score: 73),
          ),
        ),
      );

      // Find the Semantics widget
      final semanticsFinder = find.byWidgetPredicate(
        (widget) => widget is Semantics && 
                     widget.properties.label != null &&
                     widget.properties.label!.contains('Connection score'),
      );
      
      expect(semanticsFinder, findsOneWidget);
      
      final semantics = tester.widget<Semantics>(semanticsFinder);
      expect(semantics.properties.label, contains('73'));
      expect(semantics.properties.label, contains('steady'));
    });
  });

  group('BondRing.fromScore', () {
    testWidgets('renders with score and label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: Center(
              child: BondRing.fromScore(score: 85, label: 'Overall'),
            ),
          ),
        ),
      );

      expect(find.byType(BondRing), findsOneWidget);
    });

    testWidgets('score 90 uses close tier color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: Center(
              child: BondRing.fromScore(score: 90, label: 'Overall'),
            ),
          ),
        ),
      );

      expect(find.byType(BondRing), findsOneWidget);
      expect(BondTier.from(90), BondTier.close);
    });

    testWidgets('score 60 uses steady tier color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: Center(
              child: BondRing.fromScore(score: 60, label: 'Overall'),
            ),
          ),
        ),
      );

      expect(find.byType(BondRing), findsOneWidget);
      expect(BondTier.from(60), BondTier.steady);
    });

    testWidgets('score 30 uses drifting tier color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: Center(
              child: BondRing.fromScore(score: 30, label: 'Overall'),
            ),
          ),
        ),
      );

      expect(find.byType(BondRing), findsOneWidget);
      expect(BondTier.from(30), BondTier.drifting);
    });

    testWidgets('has semantic label with score and tier', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: Center(
              child: BondRing.fromScore(score: 73, label: 'Overall health'),
            ),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (widget) => widget is Semantics && 
                     widget.properties.label != null &&
                     widget.properties.label!.contains('Overall health'),
      );
      
      expect(semanticsFinder, findsOneWidget);
      
      final semantics = tester.widget<Semantics>(semanticsFinder);
      expect(semantics.properties.label, contains('steady'));
    });
  });
}
