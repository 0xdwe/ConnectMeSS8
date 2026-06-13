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
      expect(preferences.birthdayReminderMinutes, 0);
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
        defaultReminderMinutes: 95,
        birthdayReminderMinutes: 7 * 24 * 60,
        quietHoursEnabled: true,
        quietStartMinutes: 21 * 60 + 30,
        quietEndMinutes: 7 * 60 + 15,
        timeZone: 'Asia/Taipei',
      );

      expect(NotificationPreferences.fromMap(original.toMap()), original);
    });

    test('old maps without birthday timing remain compatible', () {
      final oldMap = const NotificationPreferences.defaults().toMap()
        ..remove('birthdayReminderMinutes');

      final preferences = NotificationPreferences.fromMap(oldMap);

      expect(preferences.enabled, isFalse);
      expect(preferences.defaultReminderMinutes, 60);
      expect(preferences.birthdayReminderMinutes, 0);
    });

    test('malformed maps fall back to safe defaults', () {
      final preferences = NotificationPreferences.fromMap(<String, dynamic>{
        'enabled': 'yes',
        'defaultReminderMinutes': -10,
        'birthdayReminderMinutes': -1,
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
      expect(changed.birthdayReminderMinutes, original.birthdayReminderMinutes);
      expect(changed.quietStartMinutes, original.quietStartMinutes);
    });
  });
}
