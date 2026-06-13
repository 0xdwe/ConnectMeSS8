import '../../models/social_models.dart';
import 'notification_preferences.dart';
import 'notification_schedule.dart';

class NotificationSchedulePlanner {
  const NotificationSchedulePlanner();

  static const int maximumPendingSchedules = 50;

  List<NotificationSchedule> build({
    required Iterable<PlannerEvent> events,
    required NotificationPreferences preferences,
    required DateTime now,
  }) {
    if (!preferences.enabled) return const <NotificationSchedule>[];

    final schedules = <NotificationSchedule>[];
    for (final event in events) {
      final isBirthday = event.eventType.toLowerCase() == 'birthday';
      if (isBirthday && !preferences.birthdayReminders) continue;
      if (!isBirthday && !preferences.plannerReminders) continue;

      final next = _nextSchedule(
        event: event,
        isBirthday: isBirthday,
        preferences: preferences,
        now: now,
      );
      if (next != null) schedules.add(next);
    }

    schedules.sort((a, b) {
      final byTime = a.scheduledAt.compareTo(b.scheduledAt);
      if (byTime != 0) return byTime;
      return a.eventId.compareTo(b.eventId);
    });
    if (schedules.length <= maximumPendingSchedules) {
      return List<NotificationSchedule>.unmodifiable(schedules);
    }
    return List<NotificationSchedule>.unmodifiable(
      schedules.take(maximumPendingSchedules),
    );
  }

  NotificationSchedule? _nextSchedule({
    required PlannerEvent event,
    required bool isBirthday,
    required NotificationPreferences preferences,
    required DateTime now,
  }) {
    var occurrenceDate = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
    );

    for (var attempts = 0; attempts < 500; attempts++) {
      final eventStart = _eventStart(event, occurrenceDate);
      var scheduledAt = isBirthday
          ? DateTime(
              occurrenceDate.year,
              occurrenceDate.month,
              occurrenceDate.day,
              9,
            ).subtract(Duration(minutes: preferences.birthdayReminderMinutes))
          : eventStart.subtract(
              Duration(minutes: preferences.defaultReminderMinutes),
            );

      if (preferences.quietHoursEnabled) {
        scheduledAt = _deferPastQuietHours(
          scheduledAt,
          startMinutes: preferences.quietStartMinutes,
          endMinutes: preferences.quietEndMinutes,
        );
      }

      final stalePlannerReminder =
          !isBirthday && !scheduledAt.isBefore(eventStart);
      if (scheduledAt.isAfter(now) && !stalePlannerReminder) {
        final kind = isBirthday
            ? NotificationScheduleKind.birthday
            : NotificationScheduleKind.planner;
        return NotificationSchedule(
          id: _stableId('${event.id}|${kind.name}'),
          eventId: event.id,
          kind: kind,
          title: isBirthday ? 'Birthday reminder' : 'Coming up',
          body: isBirthday
              ? preferences.birthdayReminderMinutes == 0
                    ? '${event.title} is today.'
                    : '${event.title} is coming up.'
              : event.title,
          scheduledAt: scheduledAt,
        );
      }

      if (!event.isRecurring || event.recurrencePattern == null) return null;
      occurrenceDate = _nextOccurrence(
        occurrenceDate,
        event.recurrencePattern!,
        anchorDay: event.date.day,
        anchorMonth: event.date.month,
      );
    }
    return null;
  }

  DateTime _eventStart(PlannerEvent event, DateTime occurrenceDate) {
    final minutes = event.isAllDay
        ? 9 * 60
        : (event.startTimeMinutes ?? 9 * 60);
    return DateTime(
      occurrenceDate.year,
      occurrenceDate.month,
      occurrenceDate.day,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  DateTime _deferPastQuietHours(
    DateTime dateTime, {
    required int startMinutes,
    required int endMinutes,
  }) {
    if (startMinutes == endMinutes) return dateTime;
    final minute = dateTime.hour * 60 + dateTime.minute;
    final spansMidnight = startMinutes > endMinutes;
    final isQuiet = spansMidnight
        ? minute >= startMinutes || minute < endMinutes
        : minute >= startMinutes && minute < endMinutes;
    if (!isQuiet) return dateTime;

    var target = DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      endMinutes ~/ 60,
      endMinutes % 60,
    );
    if (spansMidnight && minute >= startMinutes) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  DateTime _nextOccurrence(
    DateTime current,
    RecurrencePattern pattern, {
    required int anchorDay,
    required int anchorMonth,
  }) {
    return switch (pattern) {
      RecurrencePattern.daily => current.add(const Duration(days: 1)),
      RecurrencePattern.weekly => current.add(const Duration(days: 7)),
      RecurrencePattern.monthly => _dateClamped(
        current.year,
        current.month + 1,
        anchorDay,
      ),
      RecurrencePattern.yearly => _dateClamped(
        current.year + 1,
        anchorMonth,
        anchorDay,
      ),
    };
  }

  DateTime _dateClamped(int year, int month, int day) {
    final normalized = DateTime(year, month);
    final lastDay = DateTime(normalized.year, normalized.month + 1, 0).day;
    return DateTime(
      normalized.year,
      normalized.month,
      day > lastDay ? lastDay : day,
    );
  }

  int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}
