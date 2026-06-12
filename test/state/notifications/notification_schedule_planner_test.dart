import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/notifications/notification_preferences.dart';
import 'package:connect_me/src/state/notifications/notification_schedule.dart';
import 'package:connect_me/src/state/notifications/notification_schedule_planner.dart';
import 'package:flutter_test/flutter_test.dart';

PlannerEvent event({
  required String id,
  required DateTime date,
  String eventType = 'Plan',
  bool isAllDay = false,
  int? startTimeMinutes = 10 * 60,
  bool isRecurring = false,
  RecurrencePattern? recurrencePattern,
}) {
  return PlannerEvent(
    id: id,
    title: 'Event $id',
    category: 'Friends',
    date: date,
    note: '',
    eventType: eventType,
    isAllDay: isAllDay,
    startTimeMinutes: isAllDay ? null : startTimeMinutes,
    isRecurring: isRecurring,
    recurrencePattern: recurrencePattern,
  );
}

void main() {
  const planner = NotificationSchedulePlanner();
  const enabled = NotificationPreferences(
    enabled: true,
    suggestedCheckIns: true,
    plannerReminders: true,
    birthdayReminders: true,
    defaultReminderMinutes: 60,
    quietHoursEnabled: false,
    quietStartMinutes: 22 * 60,
    quietEndMinutes: 8 * 60,
    timeZone: 'Asia/Taipei',
  );
  final now = DateTime(2026, 6, 12, 8);

  test('master switch off produces no local schedules', () {
    final schedules = planner.build(
      events: [event(id: 'meeting', date: DateTime(2026, 6, 13))],
      preferences: enabled.copyWith(enabled: false),
      now: now,
    );

    expect(schedules, isEmpty);
  });

  test('timed planner event uses the configured lead time', () {
    final schedules = planner.build(
      events: [event(id: 'meeting', date: DateTime(2026, 6, 13))],
      preferences: enabled,
      now: now,
    );

    expect(schedules.single.kind, NotificationScheduleKind.planner);
    expect(schedules.single.scheduledAt, DateTime(2026, 6, 13, 9));
  });

  test('birthday is scheduled for 9 AM on the event date', () {
    final schedules = planner.build(
      events: [
        event(
          id: 'birthday',
          date: DateTime(2026, 6, 14),
          eventType: 'Birthday',
          isAllDay: true,
        ),
      ],
      preferences: enabled,
      now: now,
    );

    expect(schedules.single.kind, NotificationScheduleKind.birthday);
    expect(schedules.single.scheduledAt, DateTime(2026, 6, 14, 9));
  });

  test('channel switches independently suppress planner and birthdays', () {
    final events = [
      event(id: 'meeting', date: DateTime(2026, 6, 13)),
      event(
        id: 'birthday',
        date: DateTime(2026, 6, 14),
        eventType: 'Birthday',
        isAllDay: true,
      ),
    ];

    expect(
      planner
          .build(
            events: events,
            preferences: enabled.copyWith(plannerReminders: false),
            now: now,
          )
          .map((item) => item.kind),
      [NotificationScheduleKind.birthday],
    );
    expect(
      planner
          .build(
            events: events,
            preferences: enabled.copyWith(birthdayReminders: false),
            now: now,
          )
          .map((item) => item.kind),
      [NotificationScheduleKind.planner],
    );
  });

  test('quiet hours defer a reminder unless that would make it stale', () {
    final quiet = enabled.copyWith(
      quietHoursEnabled: true,
      quietStartMinutes: 22 * 60,
      quietEndMinutes: 8 * 60,
    );
    final deferred = planner.build(
      events: [
        event(
          id: 'late',
          date: DateTime(2026, 6, 13),
          startTimeMinutes: 23 * 60,
        ),
      ],
      preferences: quiet.copyWith(defaultReminderMinutes: 1440),
      now: now,
    );
    final stale = planner.build(
      events: [
        event(
          id: 'early',
          date: DateTime(2026, 6, 13),
          startTimeMinutes: 7 * 60 + 30,
        ),
      ],
      preferences: quiet.copyWith(defaultReminderMinutes: 60),
      now: now,
    );

    expect(deferred.single.scheduledAt, DateTime(2026, 6, 13, 8));
    expect(stale, isEmpty);
  });

  test('past recurring event schedules only its next occurrence', () {
    final schedules = planner.build(
      events: [
        event(
          id: 'weekly',
          date: DateTime(2026, 6, 1),
          isRecurring: true,
          recurrencePattern: RecurrencePattern.weekly,
        ),
      ],
      preferences: enabled,
      now: now,
    );

    expect(schedules.single.scheduledAt, DateTime(2026, 6, 15, 9));
  });

  test('stable IDs do not depend on event ordering', () {
    final a = event(id: 'a', date: DateTime(2026, 6, 13));
    final b = event(id: 'b', date: DateTime(2026, 6, 14));

    final first = planner.build(events: [a, b], preferences: enabled, now: now);
    final second = planner.build(
      events: [b, a],
      preferences: enabled,
      now: now,
    );

    expect(
      {for (final item in first) item.eventId: item.id},
      {for (final item in second) item.eventId: item.id},
    );
  });

  test('keeps only the earliest 50 future schedules', () {
    final events = List<PlannerEvent>.generate(
      55,
      (index) => event(
        id: 'event-$index',
        date: now.add(Duration(days: index + 1)),
      ),
    );

    final schedules = planner.build(
      events: events.reversed,
      preferences: enabled,
      now: now,
    );

    expect(schedules, hasLength(50));
    expect(schedules.first.eventId, 'event-0');
    expect(schedules.last.eventId, 'event-49');
  });
}
