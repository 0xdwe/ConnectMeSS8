import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connections/user_doc_store.dart';
import '../connections/user_doc_store_providers.dart';
import 'notification_preferences.dart';

final notificationPreferencesProvider =
    NotifierProvider<
      NotificationPreferencesController,
      NotificationPreferences
    >(NotificationPreferencesController.new);

class NotificationPreferencesController
    extends Notifier<NotificationPreferences> {
  StreamSubscription<UserDocSnapshot>? _subscription;

  @override
  NotificationPreferences build() {
    final store = ref.watch(userDocStoreProvider);
    _subscription?.cancel();
    _subscription = store.snapshot().listen((snapshot) {
      state = snapshot.notificationPreferences;
    });
    ref.onDispose(() => _subscription?.cancel());
    return store.snapshotSync()?.notificationPreferences ??
        const NotificationPreferences.defaults();
  }

  Future<void> setEnabled(bool value) => _save(state.copyWith(enabled: value));

  Future<void> setSuggestedCheckIns(bool value) =>
      _save(state.copyWith(suggestedCheckIns: value));

  Future<void> setPlannerReminders(bool value) =>
      _save(state.copyWith(plannerReminders: value));

  Future<void> setBirthdayReminders(bool value) =>
      _save(state.copyWith(birthdayReminders: value));

  Future<void> setDefaultReminderMinutes(int value) {
    if (!NotificationPreferences.isValidReminderMinutes(value)) {
      return Future<void>.error(
        ArgumentError.value(value, 'value', 'Invalid reminder lead time'),
      );
    }
    return _save(state.copyWith(defaultReminderMinutes: value));
  }

  Future<void> setBirthdayReminderMinutes(int value) {
    if (!NotificationPreferences.isValidBirthdayReminderMinutes(value)) {
      return Future<void>.error(
        ArgumentError.value(value, 'value', 'Invalid birthday lead time'),
      );
    }
    return _save(state.copyWith(birthdayReminderMinutes: value));
  }

  Future<void> setQuietHoursEnabled(bool value) =>
      _save(state.copyWith(quietHoursEnabled: value));

  Future<void> setQuietHours({
    required int startMinutes,
    required int endMinutes,
  }) {
    if (!_isMinuteOfDay(startMinutes) || !_isMinuteOfDay(endMinutes)) {
      return Future<void>.error(
        ArgumentError('Quiet hours must be within one day'),
      );
    }
    return _save(
      state.copyWith(
        quietStartMinutes: startMinutes,
        quietEndMinutes: endMinutes,
      ),
    );
  }

  Future<void> setTimeZone(String value) {
    final clean = value.trim();
    if (clean.isEmpty) {
      return Future<void>.error(
        ArgumentError.value(value, 'value', 'Time zone cannot be empty'),
      );
    }
    return _save(state.copyWith(timeZone: clean));
  }

  Future<void> _save(NotificationPreferences next) async {
    await ref.read(userDocStoreProvider).saveNotificationPreferences(next);
    state = next;
  }

  bool _isMinuteOfDay(int value) => value >= 0 && value < 24 * 60;
}
