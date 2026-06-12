import 'package:connect_me/src/state/notifications/notification_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationPreferences', () {
    test('defaults keep the master off with channels ready to enable', () {
      const preferences = NotificationPreferences.defaults();

      expect(preferences.enabled, isFalse);
      expect(preferences.suggestedCheckIns, isTrue);
      expect(preferences.plannerReminders, isTrue);
      expect(preferences.birthdayReminders, isTrue);
      expect(preferences.defaultReminderMinutes, 60);
      expect(preferences.quietHoursEnabled, isFalse);
      expect(preferences.quietStartMinutes, 22 * 60);
      expect(preferences.quietEndMinutes, 8 * 60);
      expect(preferences.timeZone, 'Etc/UTC');
    });

    test('round-trips through the Firestore map', () {
      const original = NotificationPreferences(
        enabled: true,
        suggestedCheckIns: false,
        plannerReminders: true,
        birthdayReminders: false,
        defaultReminderMinutes: 1440,
        quietHoursEnabled: true,
        quietStartMinutes: 21 * 60 + 30,
        quietEndMinutes: 7 * 60 + 15,
        timeZone: 'Asia/Taipei',
      );

      expect(NotificationPreferences.fromMap(original.toMap()), original);
    });

    test('malformed maps fall back to safe defaults', () {
      final preferences = NotificationPreferences.fromMap(<String, dynamic>{
        'enabled': 'yes',
        'defaultReminderMinutes': -10,
        'quietStartMinutes': 2000,
        'timeZone': '',
        'schemaVersion': 'one',
      });

      expect(preferences, const NotificationPreferences.defaults());
    });

    test('copyWith changes one preference without disturbing the rest', () {
      const original = NotificationPreferences.defaults();

      final changed = original.copyWith(
        enabled: true,
        timeZone: 'America/New_York',
      );

      expect(changed.enabled, isTrue);
      expect(changed.timeZone, 'America/New_York');
      expect(changed.defaultReminderMinutes, original.defaultReminderMinutes);
      expect(changed.quietStartMinutes, original.quietStartMinutes);
    });
  });
}
