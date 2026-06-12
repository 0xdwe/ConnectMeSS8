import 'package:connect_me/src/state/connections/in_memory_user_doc_store.dart';
import 'package:connect_me/src/state/notifications/notification_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('in-memory user doc exposes default notification preferences', () {
    final store = InMemoryUserDocStore();
    addTearDown(store.dispose);

    expect(
      store.snapshotSync()!.notificationPreferences,
      const NotificationPreferences.defaults(),
    );
  });

  test(
    'saving notification preferences updates and broadcasts the snapshot',
    () async {
      final store = InMemoryUserDocStore();
      addTearDown(store.dispose);
      const preferences = NotificationPreferences(
        enabled: true,
        suggestedCheckIns: true,
        plannerReminders: false,
        birthdayReminders: true,
        defaultReminderMinutes: 1440,
        quietHoursEnabled: true,
        quietStartMinutes: 23 * 60,
        quietEndMinutes: 7 * 60,
        timeZone: 'Asia/Taipei',
      );

      final nextSnapshot = store.snapshot().firstWhere(
        (snapshot) => snapshot.notificationPreferences == preferences,
      );
      await store.saveNotificationPreferences(preferences);

      expect((await nextSnapshot).notificationPreferences, preferences);
      expect(store.snapshotSync()!.notificationPreferences, preferences);
    },
  );
}
