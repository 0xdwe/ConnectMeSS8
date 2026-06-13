import '../../models/social_models.dart';
import 'notification_gateway.dart';
import 'notification_preferences.dart';
import 'notification_schedule_planner.dart';
import 'notification_token_store.dart';

class NotificationSyncResult {
  const NotificationSyncResult({required this.timeZone});

  final String timeZone;
}

class NotificationCoordinator {
  NotificationCoordinator({
    required NotificationGateway gateway,
    required NotificationTokenStore tokenStore,
    required String platform,
    DateTime Function()? clock,
    NotificationSchedulePlanner planner = const NotificationSchedulePlanner(),
  }) : _gateway = gateway,
       _tokenStore = tokenStore,
       _platform = platform,
       _clock = clock ?? DateTime.now,
       _planner = planner;

  final NotificationGateway _gateway;
  final NotificationTokenStore _tokenStore;
  final String _platform;
  final DateTime Function() _clock;
  final NotificationSchedulePlanner _planner;

  Future<NotificationSyncResult> sync({
    required NotificationPreferences preferences,
    required Iterable<PlannerEvent> events,
    required NotificationPermissionState permission,
  }) async {
    if (permission == NotificationPermissionState.unknown) {
      return NotificationSyncResult(timeZone: preferences.timeZone);
    }

    final timeZone = await _gateway.initialize();
    final canNotify =
        preferences.enabled &&
        permission == NotificationPermissionState.granted;

    if (!canNotify) {
      await _gateway.cancelSchedules();
      await _removeCurrentToken();
      return NotificationSyncResult(timeZone: timeZone);
    }

    final schedules = _planner.build(
      events: events,
      preferences: preferences,
      now: _clock(),
    );
    await _gateway.replaceSchedules(schedules);

    if (preferences.suggestedCheckIns) {
      final token = await _gateway.pushToken();
      if (token != null && token.isNotEmpty) {
        await _tokenStore.register(
          token: token,
          platform: _platform,
          timeZone: timeZone,
        );
      }
    } else {
      await _removeCurrentToken();
    }

    return NotificationSyncResult(timeZone: timeZone);
  }

  Future<void> registerRefreshedToken({
    required String token,
    required NotificationPreferences preferences,
    required NotificationPermissionState permission,
    required String timeZone,
  }) async {
    if (!preferences.enabled ||
        !preferences.suggestedCheckIns ||
        permission != NotificationPermissionState.granted) {
      return;
    }
    await _tokenStore.register(
      token: token,
      platform: _platform,
      timeZone: timeZone,
    );
  }

  Future<void> _removeCurrentToken() async {
    final String? token;
    try {
      token = await _gateway.pushToken();
    } catch (_) {
      return;
    }
    if (token != null && token.isNotEmpty) {
      await _tokenStore.remove(token);
    }
  }
}
