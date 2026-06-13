import 'notification_schedule.dart';

enum NotificationPermissionState { unknown, granted, denied }

class ForegroundNotification {
  const ForegroundNotification({required this.title, required this.body});

  final String title;
  final String body;
}

abstract interface class NotificationGateway {
  Future<String> initialize();

  Future<NotificationPermissionState> permissionStatus();

  Future<NotificationPermissionState> requestPermission();

  Future<void> openSystemSettings();

  Future<void> replaceSchedules(List<NotificationSchedule> schedules);

  Future<void> cancelSchedules();

  Future<String?> pushToken();

  Stream<String> pushTokenRefreshes();

  Stream<ForegroundNotification> foregroundNotifications();

  Future<void> showForeground(ForegroundNotification notification);
}

class InMemoryNotificationGateway implements NotificationGateway {
  InMemoryNotificationGateway({
    this.permission = NotificationPermissionState.granted,
    this.timeZone = 'Etc/UTC',
    this.token = 'test-token',
  });

  NotificationPermissionState permission;
  String timeZone;
  String? token;
  List<NotificationSchedule> schedules = <NotificationSchedule>[];
  final List<ForegroundNotification> shown = <ForegroundNotification>[];

  @override
  Future<void> cancelSchedules() async {
    schedules = <NotificationSchedule>[];
  }

  @override
  Stream<ForegroundNotification> foregroundNotifications() =>
      const Stream<ForegroundNotification>.empty();

  @override
  Future<String> initialize() async => timeZone;

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<NotificationPermissionState> permissionStatus() async => permission;

  @override
  Future<String?> pushToken() async => token;

  @override
  Stream<String> pushTokenRefreshes() => const Stream<String>.empty();

  @override
  Future<void> replaceSchedules(List<NotificationSchedule> value) async {
    schedules = List<NotificationSchedule>.from(value);
  }

  @override
  Future<NotificationPermissionState> requestPermission() async => permission;

  @override
  Future<void> showForeground(ForegroundNotification notification) async {
    shown.add(notification);
  }
}
