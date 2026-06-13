import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/planner_event_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PlannerEvent event({
    bool isAllDay = false,
    int? startTimeMinutes = 9 * 60,
    int? endTimeMinutes = 10 * 60,
    bool isRecurring = true,
    RecurrencePattern? recurrencePattern = RecurrencePattern.weekly,
  }) {
    return PlannerEvent(
      id: 'event-1',
      title: 'Coffee',
      contactId: 'contact-1',
      category: 'Friends',
      date: DateTime(2026, 6, 2),
      note: 'Catch up',
      eventType: 'Coffee',
      isAllDay: isAllDay,
      startTimeMinutes: startTimeMinutes,
      endTimeMinutes: endTimeMinutes,
      isRecurring: isRecurring,
      recurrencePattern: recurrencePattern,
    );
  }

  group('normalizePlannerEvent', () {
    test('clears stored times when an event is all-day', () {
      final normalized = normalizePlannerEvent(event(isAllDay: true));

      expect(normalized.isAllDay, isTrue);
      expect(normalized.startTimeMinutes, isNull);
      expect(normalized.endTimeMinutes, isNull);
    });

    test('clears recurrence pattern when an event is not recurring', () {
      final normalized = normalizePlannerEvent(event(isRecurring: false));

      expect(normalized.isRecurring, isFalse);
      expect(normalized.recurrencePattern, isNull);
    });

    test(
      'preserves timed recurring fields when they are valid for the event flags',
      () {
        final original = event();
        final normalized = normalizePlannerEvent(original);

        expect(normalized.startTimeMinutes, 9 * 60);
        expect(normalized.endTimeMinutes, 10 * 60);
        expect(normalized.recurrencePattern, RecurrencePattern.weekly);
      },
    );
  });
}
