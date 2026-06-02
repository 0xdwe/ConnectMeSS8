import '../models/social_models.dart';

/// Normalizes [PlannerEvent] optional fields so stale UI state cannot be
/// persisted through AppController write paths.
PlannerEvent normalizePlannerEvent(PlannerEvent event) {
  return event.copyWith(
    startTimeMinutes: event.isAllDay ? null : event.startTimeMinutes,
    endTimeMinutes: event.isAllDay ? null : event.endTimeMinutes,
    recurrencePattern: event.isRecurring ? event.recurrencePattern : null,
  );
}
