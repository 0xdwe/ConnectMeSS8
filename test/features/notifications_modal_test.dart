import 'package:connect_me/src/features/tabs/settings_tab.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:connect_me/src/state/notifications/notification_gateway.dart';
import 'package:connect_me/src/state/notifications/notification_preferences_controller.dart';
import 'package:connect_me/src/state/notifications/notification_providers.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_overrides.dart';

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    NotificationPermissionState permission =
        NotificationPermissionState.granted,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = InMemoryNotificationGateway(permission: permission);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...signedInDemoOverrides(notificationGateway: gateway),
          memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
        ],
        child: MaterialApp(
          theme: AppTheme.data(false),
          home: const Scaffold(body: SettingsTab()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Notifications'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return ProviderScope.containerOf(
      tester.element(find.byKey(const Key('notifications-modal'))),
    );
  }

  testWidgets('shows grouped notification controls without overflow', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Allow notifications'), findsOneWidget);
    expect(find.text('Suggested check-ins'), findsOneWidget);
    expect(find.text('Planner reminders'), findsOneWidget);
    expect(find.text('Birthday reminders'), findsOneWidget);
    expect(find.text('Remind me'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Quiet hours'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Quiet hours'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('birthday and planner timing menus include custom', (
    tester,
  ) async {
    final container = await pump(tester);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('birthday-reminder-menu')));
    await tester.pumpAndSettle();
    expect(find.text('On the birthday'), findsWidgets);
    expect(find.text('1 day before'), findsOneWidget);
    expect(find.text('1 week before'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
    await tester.tap(find.text('1 week before'));
    await tester.pumpAndSettle();
    expect(
      container.read(notificationPreferencesProvider).birthdayReminderMinutes,
      7 * 24 * 60,
    );

    await tester.drag(find.byType(ListView).last, const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('default-reminder-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Custom'), findsOneWidget);
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('custom-reminder-dialog')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('custom-reminder-amount')),
      '95',
    );
    await tester.tap(find.byKey(const Key('custom-reminder-unit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minutes').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      container.read(notificationPreferencesProvider).defaultReminderMinutes,
      95,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('master switch requests permission and persists enabled state', (
    tester,
  ) async {
    final container = await pump(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(container.read(notificationPreferencesProvider).enabled, isTrue);
    expect(
      container.read(notificationPermissionProvider),
      NotificationPermissionState.granted,
    );
  });

  testWidgets('denied permission shows an operating-system settings action', (
    tester,
  ) async {
    await pump(tester, permission: NotificationPermissionState.denied);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text('Notifications are blocked on this device'),
      findsOneWidget,
    );
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('quiet hours edits start and end in one dialog', (tester) async {
    final container = await pump(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Quiet hours'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('quiet-hours-switch')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quiet-hours-editor-row')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quiet-hours-dialog')), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('End'), findsOneWidget);
    expect(find.byType(TimePickerDialog), findsNothing);

    await tester.tap(find.byKey(const Key('quiet-hours-start-hour')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9').last);
    await tester.pumpAndSettle();
    final minuteDropdown = tester.widget<DropdownButton<int>>(
      find.byKey(const Key('quiet-hours-start-minute')),
    );
    minuteDropdown.onChanged?.call(5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final preferences = container.read(notificationPreferencesProvider);
    expect(preferences.quietStartMinutes, 21 * 60 + 5);
    expect(preferences.quietEndMinutes, 8 * 60);
    expect(tester.takeException(), isNull);
  });
}
