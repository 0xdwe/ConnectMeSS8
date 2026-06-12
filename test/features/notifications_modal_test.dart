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
    await tester.scrollUntilVisible(
      find.text('Quiet hours'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Quiet hours'), findsOneWidget);
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
}
