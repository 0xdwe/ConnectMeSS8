import 'package:connect_me/src/state/connections/in_memory_user_doc_store.dart';
import 'package:connect_me/src/state/connections/user_doc_store_providers.dart';
import 'package:connect_me/src/state/notifications/notification_preferences.dart';
import 'package:connect_me/src/state/notifications/notification_preferences_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingUserDocStore extends InMemoryUserDocStore {
  @override
  Future<void> saveNotificationPreferences(
    NotificationPreferences preferences,
  ) {
    return Future<void>.error(StateError('write failed'));
  }
}

void main() {
  test('hydrates from the active user-doc snapshot', () {
    const stored = NotificationPreferences(
      enabled: true,
      suggestedCheckIns: false,
      plannerReminders: true,
      birthdayReminders: true,
      defaultReminderMinutes: 15,
      quietHoursEnabled: false,
      quietStartMinutes: 22 * 60,
      quietEndMinutes: 8 * 60,
      timeZone: 'Asia/Taipei',
    );
    final store = InMemoryUserDocStore(notificationPreferences: stored);
    final container = ProviderContainer(
      overrides: [userDocStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    addTearDown(store.dispose);

    expect(container.read(notificationPreferencesProvider), stored);
  });

  test('persists updates before publishing controller state', () async {
    final store = InMemoryUserDocStore();
    final container = ProviderContainer(
      overrides: [userDocStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    addTearDown(store.dispose);

    await container
        .read(notificationPreferencesProvider.notifier)
        .setPlannerReminders(false);

    expect(
      container.read(notificationPreferencesProvider).plannerReminders,
      isFalse,
    );
    expect(
      store.snapshotSync()!.notificationPreferences.plannerReminders,
      isFalse,
    );
  });

  test('persists custom planner and birthday lead times', () async {
    final store = InMemoryUserDocStore();
    final container = ProviderContainer(
      overrides: [userDocStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    addTearDown(store.dispose);
    final controller = container.read(notificationPreferencesProvider.notifier);

    await controller.setDefaultReminderMinutes(95);
    await controller.setBirthdayReminderMinutes(7 * 24 * 60);

    final preferences = container.read(notificationPreferencesProvider);
    expect(preferences.defaultReminderMinutes, 95);
    expect(preferences.birthdayReminderMinutes, 7 * 24 * 60);
  });

  test('keeps the previous state when persistence fails', () async {
    final store = _FailingUserDocStore();
    final container = ProviderContainer(
      overrides: [userDocStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    addTearDown(store.dispose);
    final before = container.read(notificationPreferencesProvider);

    await expectLater(
      container.read(notificationPreferencesProvider.notifier).setEnabled(true),
      throwsA(isA<StateError>()),
    );

    expect(container.read(notificationPreferencesProvider), before);
  });
}
