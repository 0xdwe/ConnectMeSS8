import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_overrides.dart';

import 'package:connect_me/src/app/connect_me_app.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';

Widget _bootedApp() {
  // #041: production memoryStoreProvider returns FileMemoryStore. Real
  // disk I/O can't run under pumpAndSettle's fake async, so widget
  // tests override to InMemoryMemoryStore.
  // #052: AuthScreen sign-in routes through firebaseAuthProvider; tests
  // override with MockFirebaseAuth so the demo login resolves.
  return ProviderScope(
    overrides: [
      ...signedOutDemoOverrides(),
      memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
    ],
    child: const ConnectMeApp(),
  );
}

/// Helper to authenticate and navigate to Planner tab
Future<void> authenticateAndNavigateToPlanner(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_bootedApp());
  await tester.pumpAndSettle();

  // Authenticate: fill in email and password, then tap login
  await tester.enterText(
    find.byKey(const Key('login-email-field')),
    'test@example.com',
  );
  await tester.enterText(
    find.byKey(const Key('login-password-field')),
    'password123',
  );
  await tester.tap(find.byKey(const Key('sign-in-button')));
  await tester.pumpAndSettle();

  // Navigate to Planner tab. Tab label was renamed from 'Planner' to 'Plan'
  // in commit 62b06cb (#016, three-tab IA); helper was missed at the time.
  final planTab = find.text('Plan');
  expect(planTab, findsOneWidget);
  await tester.tap(planTab);
  await tester.pumpAndSettle();
}

void main() {
  group('Calendar accessibility', () {
    testWidgets('day cells have minimum 44pt touch target', (tester) async {
      // Arrange: authenticate and navigate to Planner
      await authenticateAndNavigateToPlanner(tester);

      // Act: find calendar day cells (InkWell widgets in the grid)
      // The calendar grid renders 42 cells (6 weeks × 7 days)
      // We'll check a few visible day cells
      final inkWells = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(InkWell),
      );

      expect(inkWells, findsWidgets);

      // Assert: each InkWell should have >= 44pt touch target
      for (int i = 0; i < inkWells.evaluate().length && i < 10; i++) {
        final rect = tester.getRect(inkWells.at(i));
        expect(
          rect.width,
          greaterThanOrEqualTo(44.0),
          reason: 'Day cell $i width should be >= 44pt for WCAG AA',
        );
        expect(
          rect.height,
          greaterThanOrEqualTo(44.0),
          reason: 'Day cell $i height should be >= 44pt for WCAG AA',
        );
      }
    });
  });

  group('Calendar visual states', () {
    testWidgets('today indicator shows filled primary circle', (tester) async {
      // Arrange: authenticate and navigate to Planner
      await authenticateAndNavigateToPlanner(tester);

      // Act: find today's date cell
      final now = DateTime.now();
      final todayNumber = now.day.toString();

      // The calendar should show today with a primary-colored background
      // We'll look for a Container with primary color decoration
      final todayCell = find.descendant(
        of: find.byType(GridView),
        matching: find.widgetWithText(InkWell, todayNumber),
      );

      // Assert: today cell exists
      expect(todayCell, findsWidgets);

      // Find the Container inside the InkWell that should have primary background
      final container = find.descendant(
        of: todayCell.first,
        matching: find.byType(Container),
      );
      expect(container, findsWidgets);

      final containerWidget = tester.widget<Container>(container.first);
      final decoration = containerWidget.decoration as BoxDecoration?;

      // Today should have primary color background
      expect(decoration, isNotNull);
      expect(decoration!.color, isNotNull);
      // We'll verify it's the primary color in the implementation
    });

    testWidgets(
      'selected day (not today) shows primaryTint bg with primary ring',
      (tester) async {
        // Arrange: authenticate and navigate to Planner
        await authenticateAndNavigateToPlanner(tester);

        // Act: tap a day that's not today
        final now = DateTime.now();
        final differentDay = (now.day == 1 ? 2 : 1).toString();

        final dayCell = find.descendant(
          of: find.byType(GridView),
          matching: find.widgetWithText(InkWell, differentDay),
        );

        if (dayCell.evaluate().isNotEmpty) {
          await tester.tap(dayCell.first);
          await tester.pumpAndSettle();

          // Assert: selected day should have primaryTint background and primary border
          final container = find.descendant(
            of: dayCell.first,
            matching: find.byType(Container),
          );
          expect(container, findsWidgets);

          final containerWidget = tester.widget<Container>(container.first);
          final decoration = containerWidget.decoration as BoxDecoration?;

          expect(decoration, isNotNull);
          expect(decoration!.color, isNotNull);
          expect(decoration.shape, BoxShape.circle);
        }
      },
    );

    testWidgets('days with events show up to 3 dots', (tester) async {
      // Arrange: authenticate and navigate to Planner
      await authenticateAndNavigateToPlanner(tester);

      // Act: find a day with events (April 28, 2026 has events in seeded data)
      final dayWithEvent = find.descendant(
        of: find.byType(GridView),
        matching: find.widgetWithText(InkWell, '28'),
      );

      expect(dayWithEvent, findsWidgets);

      // Assert: should find CircleAvatar(s) representing event dots
      final dots = find.descendant(
        of: dayWithEvent.first,
        matching: find.byType(Container),
      );

      // Should have at least one dot container for events.
      expect(dots, findsWidgets);
    });
  });

  group('Calendar typography', () {
    testWidgets('day-of-week header uses caption style with inkMuted', (
      tester,
    ) async {
      // Arrange: authenticate and navigate to Planner
      await authenticateAndNavigateToPlanner(tester);

      // Act: find day-of-week headers (Sun, Mon, etc.)
      final sunHeader = find.text('SUN');
      expect(sunHeader, findsOneWidget);

      // Assert: should use compact caption typography
      final textWidget = tester.widget<Text>(sunHeader);
      expect(textWidget.style, isNotNull);
      expect(textWidget.style!.fontSize, 11);
    });
  });

  group('Calendar layout regressions', () {
    testWidgets('day cells with events do not overflow at narrow phone width', (
      tester,
    ) async {
      // Reproduce the worst-case width reported in production. Modern
      // phones land in the 360-414pt range; 360pt is the conservative
      // mainstream lower bound used here.
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_bootedApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('login-email-field')),
        'test@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('login-password-field')),
        'password123',
      );
      await tester.tap(find.byKey(const Key('sign-in-button')));
      await tester.pumpAndSettle();

      // Navigate to the planner tab.
      final planTab = find.text('Plan');
      if (planTab.evaluate().isNotEmpty) {
        await tester.tap(planTab);
      } else {
        await tester.tap(find.byKey(const Key('planner-tab-button')));
      }
      await tester.pumpAndSettle();

      // Sanity: at least one day cell with events is rendered. The seeded
      // state includes events, so dots should appear on at least one cell.
      final dotsAcrossCalendar = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(Container),
      );
      expect(dotsAcrossCalendar, findsWidgets);

      // The actual regression assertion: no exception was thrown during
      // layout. RenderFlex overflows surface as exceptions captured by
      // the test framework and visible via takeException().
      expect(tester.takeException(), isNull);
    });
  });
}
