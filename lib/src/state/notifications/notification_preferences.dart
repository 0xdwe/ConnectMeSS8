class NotificationPreferences {
  const NotificationPreferences({
    required this.enabled,
    required this.suggestedCheckIns,
    required this.plannerReminders,
    required this.birthdayReminders,
    required this.defaultReminderMinutes,
    required this.quietHoursEnabled,
    required this.quietStartMinutes,
    required this.quietEndMinutes,
    required this.timeZone,
  });

  const NotificationPreferences.defaults({
    this.enabled = false,
    this.suggestedCheckIns = true,
    this.plannerReminders = true,
    this.birthdayReminders = true,
    this.defaultReminderMinutes = 60,
    this.quietHoursEnabled = false,
    this.quietStartMinutes = 22 * 60,
    this.quietEndMinutes = 8 * 60,
    this.timeZone = 'Etc/UTC',
  });

  static const int schemaVersion = 1;
  static const Set<int> supportedReminderMinutes = <int>{15, 60, 1440, 2880};

  final bool enabled;
  final bool suggestedCheckIns;
  final bool plannerReminders;
  final bool birthdayReminders;
  final int defaultReminderMinutes;
  final bool quietHoursEnabled;
  final int quietStartMinutes;
  final int quietEndMinutes;
  final String timeZone;

  NotificationPreferences copyWith({
    bool? enabled,
    bool? suggestedCheckIns,
    bool? plannerReminders,
    bool? birthdayReminders,
    int? defaultReminderMinutes,
    bool? quietHoursEnabled,
    int? quietStartMinutes,
    int? quietEndMinutes,
    String? timeZone,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      suggestedCheckIns: suggestedCheckIns ?? this.suggestedCheckIns,
      plannerReminders: plannerReminders ?? this.plannerReminders,
      birthdayReminders: birthdayReminders ?? this.birthdayReminders,
      defaultReminderMinutes:
          defaultReminderMinutes ?? this.defaultReminderMinutes,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
      quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
      timeZone: timeZone ?? this.timeZone,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'enabled': enabled,
    'suggestedCheckIns': suggestedCheckIns,
    'plannerReminders': plannerReminders,
    'birthdayReminders': birthdayReminders,
    'defaultReminderMinutes': defaultReminderMinutes,
    'quietHoursEnabled': quietHoursEnabled,
    'quietStartMinutes': quietStartMinutes,
    'quietEndMinutes': quietEndMinutes,
    'timeZone': timeZone,
    'schemaVersion': schemaVersion,
  };

  factory NotificationPreferences.fromMap(Object? raw) {
    if (raw is! Map) return const NotificationPreferences.defaults();

    final enabled = raw['enabled'];
    final suggestedCheckIns = raw['suggestedCheckIns'];
    final plannerReminders = raw['plannerReminders'];
    final birthdayReminders = raw['birthdayReminders'];
    final defaultReminderMinutes = raw['defaultReminderMinutes'];
    final quietHoursEnabled = raw['quietHoursEnabled'];
    final quietStartMinutes = raw['quietStartMinutes'];
    final quietEndMinutes = raw['quietEndMinutes'];
    final timeZone = raw['timeZone'];
    final version = raw['schemaVersion'];

    final valid =
        enabled is bool &&
        suggestedCheckIns is bool &&
        plannerReminders is bool &&
        birthdayReminders is bool &&
        defaultReminderMinutes is int &&
        supportedReminderMinutes.contains(defaultReminderMinutes) &&
        quietHoursEnabled is bool &&
        quietStartMinutes is int &&
        quietStartMinutes >= 0 &&
        quietStartMinutes < 24 * 60 &&
        quietEndMinutes is int &&
        quietEndMinutes >= 0 &&
        quietEndMinutes < 24 * 60 &&
        timeZone is String &&
        timeZone.trim().isNotEmpty &&
        version == schemaVersion;
    if (!valid) return const NotificationPreferences.defaults();

    return NotificationPreferences(
      enabled: enabled,
      suggestedCheckIns: suggestedCheckIns,
      plannerReminders: plannerReminders,
      birthdayReminders: birthdayReminders,
      defaultReminderMinutes: defaultReminderMinutes,
      quietHoursEnabled: quietHoursEnabled,
      quietStartMinutes: quietStartMinutes,
      quietEndMinutes: quietEndMinutes,
      timeZone: timeZone,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NotificationPreferences &&
        other.enabled == enabled &&
        other.suggestedCheckIns == suggestedCheckIns &&
        other.plannerReminders == plannerReminders &&
        other.birthdayReminders == birthdayReminders &&
        other.defaultReminderMinutes == defaultReminderMinutes &&
        other.quietHoursEnabled == quietHoursEnabled &&
        other.quietStartMinutes == quietStartMinutes &&
        other.quietEndMinutes == quietEndMinutes &&
        other.timeZone == timeZone;
  }

  @override
  int get hashCode => Object.hash(
    enabled,
    suggestedCheckIns,
    plannerReminders,
    birthdayReminders,
    defaultReminderMinutes,
    quietHoursEnabled,
    quietStartMinutes,
    quietEndMinutes,
    timeZone,
  );
}
