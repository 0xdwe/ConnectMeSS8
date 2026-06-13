import 'package:app_settings/app_settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_gateway.dart';
import 'notification_schedule.dart';

class FlutterNotificationGateway implements NotificationGateway {
  FlutterNotificationGateway({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'connect_me_reminders',
    'Connect Me reminders',
    description: 'Planner, birthday, and gentle check-in reminders.',
    importance: Importance.high,
  );
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'connect_me_reminders',
      'Connect Me reminders',
      channelDescription: 'Planner, birthday, and gentle check-in reminders.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  bool _initialized = false;
  String _timeZone = 'Etc/UTC';

  @override
  Future<String> initialize() async {
    if (_initialized) return _timeZone;

    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      _timeZone = info.identifier;
      tz.setLocalLocation(tz.getLocation(_timeZone));
    } catch (_) {
      _timeZone = 'Etc/UTC';
      tz.setLocalLocation(tz.UTC);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const apple = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: apple,
        macOS: apple,
      ),
    );
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
    }
    _initialized = true;
    return _timeZone;
  }

  @override
  Future<NotificationPermissionState> permissionStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return _mapAuthorizationStatus(settings.authorizationStatus);
  }

  @override
  Future<NotificationPermissionState> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return _mapAuthorizationStatus(settings.authorizationStatus);
  }

  @override
  Future<void> openSystemSettings() => AppSettings.openAppSettings();

  @override
  Future<void> replaceSchedules(List<NotificationSchedule> schedules) async {
    await initialize();
    await _localNotifications.cancelAllPendingNotifications();
    for (final schedule in schedules) {
      final localDate = tz.TZDateTime(
        tz.local,
        schedule.scheduledAt.year,
        schedule.scheduledAt.month,
        schedule.scheduledAt.day,
        schedule.scheduledAt.hour,
        schedule.scheduledAt.minute,
      );
      await _localNotifications.zonedSchedule(
        id: schedule.id,
        title: schedule.title,
        body: schedule.body,
        scheduledDate: localDate,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: schedule.eventId,
      );
    }
  }

  @override
  Future<void> cancelSchedules() =>
      _localNotifications.cancelAllPendingNotifications();

  @override
  Future<String?> pushToken() => _messaging.getToken();

  @override
  Stream<String> pushTokenRefreshes() => _messaging.onTokenRefresh;

  @override
  Stream<ForegroundNotification> foregroundNotifications() {
    return FirebaseMessaging.onMessage
        .where((message) => message.notification != null)
        .map(
          (message) => ForegroundNotification(
            title: message.notification?.title ?? 'Connect Me',
            body: message.notification?.body ?? '',
          ),
        );
  }

  @override
  Future<void> showForeground(ForegroundNotification notification) async {
    await initialize();
    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
      title: notification.title,
      body: notification.body,
      notificationDetails: _details,
    );
  }

  NotificationPermissionState _mapAuthorizationStatus(
    AuthorizationStatus status,
  ) {
    return switch (status) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => NotificationPermissionState.granted,
      AuthorizationStatus.denied => NotificationPermissionState.denied,
      AuthorizationStatus.notDetermined => NotificationPermissionState.unknown,
    };
  }
}
