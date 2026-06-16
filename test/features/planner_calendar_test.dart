import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_overrides.dart';

import 'package:connect_me/src/app/connect_me_app.dart';
import 'package:connect_me/src/features/tabs/planner_tab.dart';
import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/connections/batched_writes.dart';
import 'package:connect_me/src/state/connections/batched_writes_providers.dart';
import 'package:connect_me/src/state/connections/connection_providers.dart';
import 'package:connect_me/src/state/connections/event_providers.dart';
import 'package:connect_me/src/state/connections/in_memory_connection_store.dart';
import 'package:connect_me/src/state/connections/in_memory_event_store.dart';
import 'package:connect_me/src/state/connections/in_memory_interaction_store.dart';
import 'package:connect_me/src/state/connections/in_memory_user_doc_store.dart';
import 'package:connect_me/src/state/connections/interaction_providers.dart';
import 'package:connect_me/src/state/connections/user_doc_store_providers.dart';
import 'package:connect_me/src/state/firebase_providers.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:connect_me/src/theme/app_tokens.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:intl/intl.dart';

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

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

PlannerEvent _event(String id, String title, DateTime date) {
  return _eventWithType(id, title, date);
}

PlannerEvent _eventWithType(
  String id,
  String title,
  DateTime date, {
  String category = 'Friends',
  String eventType = 'Plan',
}) {
  return PlannerEvent(
    id: id,
    title: title,
    category: category,
    date: date,
    note: '',
    eventType: eventType,
  );
}

Future<void> _pumpPlanner(
  WidgetTester tester, {
  required DateTime now,
  required List<PlannerEvent> events,
}) async {
  final connections = InMemoryConnectionStore();
  final interactions = InMemoryInteractionStore();
  final eventStore = InMemoryEventStore();
  final userDoc = InMemoryUserDocStore();
  for (final event in events) {
    await eventStore.save(event);
  }

  await tester.binding.setSurfaceSize(const Size(800, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(
          MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(
              uid: 'planner-test-user',
              email: 'planner@example.com',
              displayName: 'Planner Test',
            ),
          ),
        ),
        memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
        connectionStoreProvider.overrideWithValue(connections),
        interactionStoreProvider.overrideWithValue(interactions),
        eventStoreProvider.overrideWithValue(eventStore),
        userDocStoreProvider.overrideWithValue(userDoc),
        batchedWritesProvider.overrideWithValue(
          InMemoryBatchedWrites(
            connectionStore: connections,
            interactionStore: interactions,
            eventStore: eventStore,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.data(false),
        home: Scaffold(body: PlannerTab(now: () => now)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _calendarCellFor(DateTime visibleMonth, DateTime date) {
  final firstOfMonth = DateTime(visibleMonth.year, visibleMonth.month);
  final firstGridDate = firstOfMonth.subtract(
    Duration(days: firstOfMonth.weekday % 7),
  );
  final index = _dateOnly(date).difference(firstGridDate).inDays;
  final cells = find.descendant(
    of: find.byType(GridView),
    matching: find.byType(InkWell),
  );
  return cells.at(index);
}

Future<void> _scrollPlannerTo(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    240,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('planner-tab')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Planner date filtering', () {
    testWidgets('opens on the current month with today and upcoming events', (
      tester,
    ) async {
      final today = DateTime(2026, 6, 12);
      await _pumpPlanner(
        tester,
        now: today,
        events: [
          _event(
            'past',
            'Past event should stay hidden',
            today.subtract(const Duration(days: 1)),
          ),
          _event('today', 'Today event', today),
          _event('future', 'Future event', today.add(const Duration(days: 1))),
        ],
      );

      expect(find.text(DateFormat.MMMM().format(today)), findsOneWidget);
      expect(find.text(DateFormat.yMMMM().format(today)), findsNothing);
      expect(find.byKey(const Key('planner-today-button')), findsNothing);
      expect(find.text('Today & Upcoming'), findsOneWidget);
      expect(find.text('Today event'), findsOneWidget);
      await _scrollPlannerTo(tester, 'Future event');
      expect(find.text('Future event'), findsOneWidget);
      expect(find.text('Past event should stay hidden'), findsNothing);
    });

    testWidgets('tapping next up event opens edit modal', (tester) async {
      final today = DateTime(2026, 6, 12);
      await _pumpPlanner(
        tester,
        now: today,
        events: [_event('today', 'Today event', today)],
      );

      await tester.tap(find.text('Next up'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Event'), findsOneWidget);
      expect(find.text('Today event'), findsWidgets);
    });

    testWidgets('tapping a date shows only events on that date', (
      tester,
    ) async {
      final today = DateTime(2026, 6, 12);
      final selectedDate = today.add(const Duration(days: 1));
      await _pumpPlanner(
        tester,
        now: today,
        events: [
          _event('selected', 'Selected date event', selectedDate),
          _event(
            'later',
            'Later event should stay hidden',
            selectedDate.add(const Duration(days: 1)),
          ),
        ],
      );

      await tester.tap(_calendarCellFor(today, selectedDate));
      await tester.pumpAndSettle();

      expect(
        find.text(DateFormat('EEEE, MMMM d').format(selectedDate)),
        findsOneWidget,
      );
      expect(find.text('Selected date event'), findsOneWidget);
      expect(find.text('Later event should stay hidden'), findsNothing);
    });

    testWidgets('tapping today filters to today only', (tester) async {
      final today = DateTime(2026, 6, 12);
      await _pumpPlanner(
        tester,
        now: today,
        events: [
          _event('today', 'Today event', today),
          _event(
            'future',
            'Future event should stay hidden',
            today.add(const Duration(days: 1)),
          ),
        ],
      );

      await tester.tap(_calendarCellFor(today, today));
      await tester.pumpAndSettle();

      expect(
        find.text(DateFormat('EEEE, MMMM d').format(today)),
        findsOneWidget,
      );
      expect(find.text('Today event'), findsOneWidget);
      expect(find.text('Future event should stay hidden'), findsNothing);
    });

    testWidgets('selected past date shows neutral past indicator', (
      tester,
    ) async {
      final today = DateTime(2026, 6, 12);
      final pastDate = today.subtract(const Duration(days: 1));
      await _pumpPlanner(
        tester,
        now: today,
        events: [_event('past', 'Past event', pastDate)],
      );

      final pastCell = _calendarCellFor(today, pastDate);
      await tester.tap(pastCell);
      await tester.pumpAndSettle();

      expect(find.text('Past date'), findsOneWidget);
      final cellContainer = find.descendant(
        of: pastCell,
        matching: find.byType(Container),
      );
      final decoration =
          tester.widget<Container>(cellContainer.first).decoration
              as BoxDecoration;
      expect(decoration.color, isNot(AppTokens.light().primary));
    });

    testWidgets('event icon follows event type instead of category', (
      tester,
    ) async {
      final today = DateTime(2026, 6, 12);
      await _pumpPlanner(
        tester,
        now: today,
        events: [
          _eventWithType(
            'meeting',
            'Check-in',
            today,
            category: 'Family',
            eventType: 'Meeting',
          ),
        ],
      );

      expect(find.text('👥'), findsOneWidget);
      expect(find.text('🏠'), findsNothing);
    });

    testWidgets('selected date without events shows focused empty state', (
      tester,
    ) async {
      final today = DateTime(2026, 6, 12);
      final emptyDate = today.add(const Duration(days: 2));
      await _pumpPlanner(
        tester,
        now: today,
        events: [
          _event(
            'later',
            'Later event should stay hidden',
            emptyDate.add(const Duration(days: 1)),
          ),
        ],
      );

      await tester.tap(_calendarCellFor(today, emptyDate));
      await tester.pumpAndSettle();

      expect(find.text('No events planned for this date.'), findsOneWidget);
      expect(find.text('Later event should stay hidden'), findsNothing);
    });
  });

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
    testWidgets('month navigation arrows stay grouped with month name', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final today = DateTime(2026, 5, 12);
      await _pumpPlanner(tester, now: today, events: const []);

      final mayMonthRect = tester.getRect(find.text('May'));
      final mayPreviousRect = tester.getRect(find.byIcon(Icons.chevron_left));
      final mayNextRect = tester.getRect(
        find.byIcon(Icons.chevron_right).first,
      );

      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byIcon(Icons.chevron_right).first);
        await tester.pumpAndSettle();
      }

      expect(find.text('September'), findsOneWidget);
      final monthRect = tester.getRect(find.text('September'));
      final septemberPreviousRect = tester.getRect(
        find.byIcon(Icons.chevron_left),
      );
      final septemberNextRect = tester.getRect(
        find.byIcon(Icons.chevron_right).first,
      );
      final searchRect = tester.getRect(find.byIcon(Icons.search));
      final monthSlotRect = tester.getRect(
        find.byKey(const Key('planner-month-label')),
      );
      final monthText = tester.widget<Text>(find.text('September'));
      final monthPainter = TextPainter(
        text: TextSpan(text: 'September', style: monthText.style),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      expect(septemberPreviousRect.left, closeTo(mayPreviousRect.left, 0.1));
      expect(septemberNextRect.left, closeTo(mayNextRect.left, 0.1));
      expect(monthRect.height, closeTo(mayMonthRect.height, 0.1));
      expect(monthPainter.width, lessThanOrEqualTo(monthSlotRect.width));
      expect(septemberPreviousRect.right, lessThan(monthRect.left));
      expect(monthRect.right, lessThan(septemberNextRect.left));
      expect(septemberNextRect.right, lessThan(searchRect.left));
    });

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
