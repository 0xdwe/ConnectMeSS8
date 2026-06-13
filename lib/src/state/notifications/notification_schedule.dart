enum NotificationScheduleKind { planner, birthday }

class NotificationSchedule {
  const NotificationSchedule({
    required this.id,
    required this.eventId,
    required this.kind,
    required this.title,
    required this.body,
    required this.scheduledAt,
  });

  final int id;
  final String eventId;
  final NotificationScheduleKind kind;
  final String title;
  final String body;
  final DateTime scheduledAt;
}
