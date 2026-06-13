import 'package:connect_me/src/theme/app_spacing.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:connect_me/src/theme/app_typography.dart';
import 'package:connect_me/src/widgets/crm_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Maximum acceptable title height: 2 lines of h1 plus a 1pt rendering fudge.
/// Bound to AppTypography so this stays correct if typography is retuned.
double _maxTitleHeightTwoLines() {
  final style = AppTypography.h1();
  final lineHeight = (style.height ?? 1.2) * (style.fontSize ?? 26);
  return lineHeight * 2 + 1.0;
}

/// Tests `SectionTitle` responsive layout across phone and tablet widths.
///
/// Regression: on iPhone 16 (390pt) the long title "Today's Recommendation"
/// laid out next to a "View All ->" action used to wrap mid-character
/// because Flutter's text wrapping inside an `Expanded` `Row` breaks at
/// the nearest position when no word break is available — and there is
/// no internal space inside "Recommendation" to break on cleanly given
/// the tight remaining width.
///
/// The fix is responsive: on narrow surfaces (phones), the action stacks
/// below the title; on wide surfaces (tablets), the original Row layout
/// is preserved.
void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.data(false),
      home: Scaffold(
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.space6),
          child: child,
        ),
      ),
    );
  }

  Future<void> setSurface(WidgetTester tester, double widthLogical) async {
    const double dpr = 3.0;
    tester.view.physicalSize = Size(widthLogical * dpr, 844 * dpr);
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('SectionTitle responsive layout', () {
    testWidgets('wraps cleanly on iPhone 16 width (390pt) without overflow', (
      tester,
    ) async {
      await setSurface(tester, 390);

      await tester.pumpWidget(
        wrap(
          SectionTitle(
            "Today's Recommendation",
            action: TextButton(onPressed: () {}, child: const Text('View All')),
          ),
        ),
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'no overflow / layout exceptions on 390pt',
      );
      expect(find.text("Today's Recommendation"), findsOneWidget);

      // Title height should be at most 2 lines of h1. If it's larger, the
      // title was forced to wrap mid-character into 3+ lines, which is the
      // bug. Bound is read from AppTypography so retunes don't silently
      // weaken this assertion.
      final renderedText = tester.renderObject<RenderBox>(
        find.text("Today's Recommendation"),
      );
      expect(
        renderedText.size.height,
        lessThanOrEqualTo(_maxTitleHeightTwoLines()),
        reason: 'title fits in two lines or fewer',
      );
    });

    testWidgets('does not overflow on iPhone SE width (320pt)', (tester) async {
      await setSurface(tester, 320);

      await tester.pumpWidget(
        wrap(
          SectionTitle(
            "Today's Recommendation",
            action: TextButton(onPressed: () {}, child: const Text('View All')),
          ),
        ),
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'no overflow / layout exceptions on 320pt',
      );
      expect(find.text("Today's Recommendation"), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);

      // The original mid-character wrap bug renders silently without
      // raising — `takeException()` would have passed against the buggy
      // code. Assert the title fits in two lines or fewer so this test
      // actually proves the responsive layout choice.
      final renderedText = tester.renderObject<RenderBox>(
        find.text("Today's Recommendation"),
      );
      expect(
        renderedText.size.height,
        lessThanOrEqualTo(_maxTitleHeightTwoLines()),
        reason: 'title fits in two lines or fewer at 320pt',
      );
    });

    testWidgets('uses Row layout on tablet width (768pt iPad Mini)', (
      tester,
    ) async {
      await setSurface(tester, 768);

      await tester.pumpWidget(
        wrap(
          SectionTitle(
            "Today's Recommendation",
            action: TextButton(onPressed: () {}, child: const Text('View All')),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text("Today's Recommendation"), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);

      // On tablet width the title and action sit on the same row.
      // We verify by checking the title's vertical center is close to
      // the action's vertical center.
      final titleBox = tester.renderObject<RenderBox>(
        find.text("Today's Recommendation"),
      );
      final actionBox = tester.renderObject<RenderBox>(find.text('View All'));
      final titleCenterY =
          titleBox.localToGlobal(Offset.zero).dy + titleBox.size.height / 2;
      final actionCenterY =
          actionBox.localToGlobal(Offset.zero).dy + actionBox.size.height / 2;
      expect(
        (titleCenterY - actionCenterY).abs(),
        lessThan(20),
        reason: 'on tablet width title and action are on the same row',
      );
    });

    testWidgets('short titles use Row layout even on narrow widths', (
      tester,
    ) async {
      await setSurface(tester, 390);

      await tester.pumpWidget(
        wrap(
          SectionTitle(
            'History',
            action: TextButton(onPressed: () {}, child: const Text('Edit')),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      // Short title 'History' (7 chars) easily fits next to 'Edit' on
      // 390pt, so they should sit on the same row.
      final titleBox = tester.renderObject<RenderBox>(find.text('History'));
      final actionBox = tester.renderObject<RenderBox>(find.text('Edit'));
      final titleCenterY =
          titleBox.localToGlobal(Offset.zero).dy + titleBox.size.height / 2;
      final actionCenterY =
          actionBox.localToGlobal(Offset.zero).dy + actionBox.size.height / 2;
      expect(
        (titleCenterY - actionCenterY).abs(),
        lessThan(20),
        reason: 'short titles stay in Row layout',
      );
    });

    testWidgets('renders without action across all widths', (tester) async {
      for (final width in [320.0, 390.0, 768.0]) {
        await setSurface(tester, width);
        await tester.pumpWidget(
          wrap(const SectionTitle("Today's Recommendation")),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'no overflow at $width with no action',
        );
        expect(find.text("Today's Recommendation"), findsOneWidget);
      }
    });
  });
}
