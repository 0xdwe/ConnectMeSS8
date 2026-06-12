import 'dart:async';

import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/notifications/notification_coordinator.dart';
import 'package:connect_me/src/state/notifications/notification_gateway.dart';
import 'package:connect_me/src/state/notifications/notification_preferences.dart';
import 'package:connect_me/src/state/notifications/notification_schedule.dart';
import 'package:connect_me/src/state/notifications/notification_token_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gateway implements NotificationGateway {
  NotificationPermissionState permission = NotificationPermissionState.granted;
  String timeZone = 'Asia/Taipei';
  String? token = 'token-a';
  Object? pushTokenError;
  List<NotificationSchedule> schedules = <NotificationSchedule>[];
  int initializeCalls = 0;
  int cancelCalls = 0;

  @override
  Future<void> cancelSchedules() async {
    cancelCalls++;
    schedules = <NotificationSchedule>[];
  }

  @override
  Stream<ForegroundNotification> foregroundNotifications() =>
      const Stream<ForegroundNotification>.empty();

  @override
  Future<String> initialize() async {
    initializeCalls++;
    return timeZone;
  }

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<NotificationPermissionState> permissionStatus() async => permission;

  @override
  Future<String?> pushToken() async {
    if (pushTokenError case final error?) throw error;
    return token;
  }

  @override
  Stream<String> pushTokenRefreshes() => const Stream<String>.empty();

  @override
  Future<void> replaceSchedules(List<NotificationSchedule> value) async {
    schedules = value;
  }

  @override
  Future<NotificationPermissionState> requestPermission() async => permission;

  @override
  Future<void> showForeground(ForegroundNotification notification) async {}
}

PlannerEvent _event() => PlannerEvent(
  id: 'event-1',
  title: 'Coffee with Sarah',
  category: 'Friends',
  date: DateTime(2026, 6, 13),
  note: '',
  eventType: 'Plan',
  isAllDay: false,
  startTimeMinutes: 10 * 60,
);

const _enabled = NotificationPreferences(
  enabled: true,
  suggestedCheckIns: true,
  plannerReminders: true,
  birthdayReminders: true,
  defaultReminderMinutes: 60,
  quietHoursEnabled: false,
  quietStartMinutes: 22 * 60,
  quietEndMinutes: 8 * 60,
  timeZone: 'Etc/UTC',
);

void main() {
  test(
    'enabled permissions schedule events and register the FCM token',
    () async {
      final gateway = _Gateway();
      final tokens = InMemoryNotificationTokenStore();
      final coordinator = NotificationCoordinator(
        gateway: gateway,
        tokenStore: tokens,
        platform: 'android',
        clock: () => DateTime(2026, 6, 12, 8),
      );

      final result = await coordinator.sync(
        preferences: _enabled,
        events: [_event()],
        permission: NotificationPermissionState.granted,
      );

      expect(gateway.schedules, hasLength(1));
      expect(tokens.registrations.keys, ['token-a']);
      expect(result.timeZone, 'Asia/Taipei');
    },
  );

  test(
    'disabled notifications cancel schedules and remove the token',
    () async {
      final gateway = _Gateway();
      final tokens = InMemoryNotificationTokenStore();
      await tokens.register(
        token: 'token-a',
        platform: 'android',
        timeZone: 'Asia/Taipei',
      );
      final coordinator = NotificationCoordinator(
        gateway: gateway,
        tokenStore: tokens,
        platform: 'android',
        clock: () => DateTime(2026, 6, 12, 8),
      );

      await coordinator.sync(
        preferences: _enabled.copyWith(enabled: false),
        events: [_event()],
        permission: NotificationPermissionState.granted,
      );

      expect(gateway.cancelCalls, 1);
      expect(tokens.registrations, isEmpty);
    },
  );

  test('denied permission never schedules or registers', () async {
    final gateway = _Gateway();
    final tokens = InMemoryNotificationTokenStore();
    final coordinator = NotificationCoordinator(
      gateway: gateway,
      tokenStore: tokens,
      platform: 'android',
      clock: () => DateTime(2026, 6, 12, 8),
    );

    await coordinator.sync(
      preferences: _enabled,
      events: [_event()],
      permission: NotificationPermissionState.denied,
    );

    expect(gateway.cancelCalls, 1);
    expect(tokens.registrations, isEmpty);
  });

  test(
    'unknown permission defers synchronization without touching gateway',
    () async {
      final gateway = _Gateway();
      final coordinator = NotificationCoordinator(
        gateway: gateway,
        tokenStore: InMemoryNotificationTokenStore(),
        platform: 'ios',
      );

      final result = await coordinator.sync(
        preferences: _enabled,
        events: [_event()],
        permission: NotificationPermissionState.unknown,
      );

      expect(result.timeZone, _enabled.timeZone);
      expect(gateway.initializeCalls, 0);
      expect(gateway.cancelCalls, 0);
    },
  );

  test(
    'token lookup failure does not block denied-permission cleanup',
    () async {
      final gateway = _Gateway()
        ..pushTokenError = StateError('APNS token is not ready');
      final coordinator = NotificationCoordinator(
        gateway: gateway,
        tokenStore: InMemoryNotificationTokenStore(),
        platform: 'ios',
      );

      await expectLater(
        coordinator.sync(
          preferences: _enabled,
          events: [_event()],
          permission: NotificationPermissionState.denied,
        ),
        completes,
      );

      expect(gateway.cancelCalls, 1);
    },
  );
}
