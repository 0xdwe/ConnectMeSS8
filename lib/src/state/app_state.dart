import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../ai/ai_update_service.dart';
import '../models/social_models.dart';

final aiUpdateServiceProvider = Provider<AiUpdateService>(
  (ref) => const MockAiUpdateService(),
);
final appControllerProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);

/// Tri-state theme preference. Stored on [AppState.themeMode]; resolved
/// by [ConnectMeApp] into Flutter's [ThemeMode]. Default = [system].
enum AppThemeMode { system, light, dark }

class AppState {
  const AppState({
    required this.isAuthed,
    required this.themeMode,
    required this.selectedTab,
    required this.user,
    required this.connections,
    required this.interactions,
    required this.events,
    required this.categories,
    required this.eventTypes,
    required this.googleCalendarLinked,
    this.lastAiSummary,
  });

  final bool isAuthed;
  final AppThemeMode themeMode;
  final int selectedTab;
  final AppUser user;
  final List<Connection> connections;
  final List<CrmInteraction> interactions;
  final List<PlannerEvent> events;
  final List<String> categories;
  final List<String> eventTypes;
  final bool googleCalendarLinked;
  final String? lastAiSummary;

  int get averageConnectionScore => connections.isEmpty
      ? 0
      : (connections.map((c) => c.bondScore).reduce((a, b) => a + b) /
                connections.length)
            .round();

  List<Recommendation> get recommendations => [
    const Recommendation(
      contactId: 'mike',
      reason: "Mike's been quiet for a while.",
      insight: "It's been about 5 weeks since you talked.",
      priority: 'high priority',
    ),
    const Recommendation(
      contactId: 'jessica',
      reason: 'Jessica is starting to drift.',
      insight: 'She mentioned planning a trip to Europe.',
      priority: 'medium priority',
    ),
    const Recommendation(
      contactId: 'emily',
      reason: 'You and Emily have been close lately.',
      insight: 'This is her first week at the new role.',
      priority: 'low priority',
    ),
  ];

  factory AppState.seeded() {
    final now = DateTime.now();
    final people = [
      Connection(
        id: 'david',
        name: 'David Kim',
        email: 'david.k@email.com',
        category: 'Family',
        avatar: '👨‍👩‍👧',
        bondScore: 95,
        nextStep: 'Ask about family dinner plans',
        lastContact: now.subtract(const Duration(days: 4)),
        notes: 'Family anchor. Likes weekend updates.',
        knownSince: DateTime(1998, 5, 1),
        preferredChannels: const ['Text', 'Phone', 'FaceTime'],
      ),
      Connection(
        id: 'emily',
        name: 'Emily Rodriguez',
        email: 'emily.r@email.com',
        category: 'Work',
        avatar: '👩‍💼',
        bondScore: 85,
        nextStep: 'Ask about first week in new role',
        lastContact: now.subtract(const Duration(days: 5)),
        notes: 'First week at new role. Keep momentum going.',
        knownSince: DateTime(2023, 9, 1),
        preferredChannels: const ['Slack', 'Email', 'Text'],
      ),
      Connection(
        id: 'jessica',
        name: 'Jessica Taylor',
        email: 'jess.t@email.com',
        category: 'College',
        avatar: '👩‍🎓',
        bondScore: 73,
        nextStep: 'Ask about Europe trip planning',
        lastContact: now.subtract(const Duration(days: 22)),
        notes: 'Mentioned planning a Europe trip.',
        knownSince: DateTime(2012, 9, 1),
        preferredChannels: const ['Instagram', 'Text', 'FaceTime'],
      ),
      Connection(
        id: 'mike',
        name: 'Mike Chen',
        email: 'mike.chen@email.com',
        category: 'High School',
        avatar: '👨',
        bondScore: 68,
        nextStep: 'Follow up on job application',
        lastContact: now.subtract(const Duration(days: 39)),
        notes: 'Talked about his job application last time.',
        knownSince: DateTime(2010, 9, 1),
        preferredChannels: const ['Text', 'Instagram', 'Phone'],
      ),
      Connection(
        id: 'sarah',
        name: 'Sarah Johnson',
        email: 'sarah.j@email.com',
        category: 'Friends',
        avatar: '👱‍♀️',
        bondScore: 92,
        nextStep: 'Coffee catch-up',
        lastContact: now.subtract(const Duration(days: 7)),
        notes: 'Coffee with Sarah scheduled.',
        knownSince: DateTime(2020, 6, 1),
        preferredChannels: const ['Text', 'Instagram', 'Coffee'],
      ),
    ];
    return AppState(
      isAuthed: false,
      themeMode: AppThemeMode.system,
      selectedTab: 0,
      user: const AppUser(
        name: 'Alex Martinez',
        email: 'alex.martinez@email.com',
        avatar: '👤',
        avatarKind: AvatarKind.emoji,
      ),
      connections: people,
      categories: const ['Family', 'Friends', 'High School', 'College', 'Work'],
      eventTypes: AppController.defaultEventTypes,
      googleCalendarLinked: true,
      interactions: [
        CrmInteraction(
          id: 'i1',
          contactId: 'sarah',
          type: InteractionType.sharedActivity,
          title: 'Coffee plan',
          note: 'Coffee with Sarah on April 28.',
          date: DateTime(2026, 4, 20),
        ),
        CrmInteraction(
          id: 'i2',
          contactId: 'mike',
          type: InteractionType.reminder,
          title: 'Job application',
          note: 'Ask Mike about his application progress.',
          date: DateTime(2026, 3, 23),
        ),
        CrmInteraction(
          id: 'i3',
          contactId: 'emily',
          type: InteractionType.relationshipNote,
          title: 'New role',
          note: 'Emily started a new role this week.',
          date: DateTime(2026, 4, 18),
        ),
      ],
      events: [
        PlannerEvent(
          id: 'e1',
          title: 'Coffee with Sarah',
          contactId: 'sarah',
          category: 'Friends',
          date: DateTime(2026, 4, 28),
          note: 'Google Calendar mock sync',
          eventType: 'Coffee',
          isAllDay: false,
          startTimeMinutes: 10 * 60,
          endTimeMinutes: 11 * 60 + 30,
        ),
        PlannerEvent(
          id: 'e2',
          title: 'Team Meeting',
          contactId: 'emily',
          category: 'Work',
          date: DateTime(2026, 4, 30),
          note: 'Discuss launch',
          eventType: 'Meeting',
          isAllDay: false,
          startTimeMinutes: 14 * 60,
          endTimeMinutes: 15 * 60 + 30,
        ),
        PlannerEvent(
          id: 'e3',
          title: 'Call Mike (Reminder)',
          contactId: 'mike',
          category: 'High School',
          date: DateTime(2026, 5, 5),
          note: 'Ask about job application',
          eventType: 'Reminder',
        ),
        PlannerEvent(
          id: 'e4',
          title: "Emily's Birthday",
          contactId: 'emily',
          category: 'Work',
          date: DateTime(2026, 5, 12),
          note: 'Send message',
          eventType: 'Birthday',
        ),
        PlannerEvent(
          id: 'e5',
          title: 'Family Dinner',
          contactId: 'david',
          category: 'Family',
          date: DateTime(2026, 5, 15),
          note: 'Dinner',
          eventType: 'Dinner',
          isAllDay: false,
          startTimeMinutes: 18 * 60 + 30,
          endTimeMinutes: 21 * 60,
        ),
      ],
    );
  }

  AppState copyWith({
    bool? isAuthed,
    AppThemeMode? themeMode,
    int? selectedTab,
    AppUser? user,
    List<Connection>? connections,
    List<CrmInteraction>? interactions,
    List<PlannerEvent>? events,
    List<String>? categories,
    List<String>? eventTypes,
    bool? googleCalendarLinked,
    String? lastAiSummary,
  }) {
    return AppState(
      isAuthed: isAuthed ?? this.isAuthed,
      themeMode: themeMode ?? this.themeMode,
      selectedTab: selectedTab ?? this.selectedTab,
      user: user ?? this.user,
      connections: connections ?? this.connections,
      interactions: interactions ?? this.interactions,
      events: events ?? this.events,
      categories: categories ?? this.categories,
      eventTypes: eventTypes ?? this.eventTypes,
      googleCalendarLinked: googleCalendarLinked ?? this.googleCalendarLinked,
      lastAiSummary: lastAiSummary ?? this.lastAiSummary,
    );
  }

  ContactInsight contactInsightFor(String contactId) {
    final contact = connections.firstWhere(
      (connection) => connection.id == contactId,
    );
    final contactInteractions = interactions
        .where((interaction) => interaction.contactId == contactId)
        .toList();
    final now = DateTime.now();
    final daysSinceContact = now.difference(contact.lastContact).inDays;
    final knownSinceYears = (now.difference(contact.knownSince).inDays / 365)
        .floor()
        .clamp(1, 99);
    final frequency = _frequencyByMonth(contactInteractions, now);
    final channel = contact.preferredChannels.isEmpty
        ? 'Text'
        : contact.preferredChannels.first;
    final timing = daysSinceContact >= 21
        ? '$daysSinceContact days since your last contact'
        : 'recent momentum from contact $daysSinceContact days ago';
    final frequencyTotal = frequency.reduce((sum, count) => sum + count);

    return ContactInsight(
      contactId: contact.id,
      summary: '$timing. Reach out via $channel to keep ${contact.name} close.',
      why:
          'Last contact was $daysSinceContact days ago; ${contact.category} relationship, ${contact.bondScore} bond score, $frequencyTotal interactions in the last 12 months.',
      recommendedAction: contact.nextStep,
      potentialScoreGain: _potentialGain(contact.bondScore, daysSinceContact),
      relationshipLabel: contact.category,
      knownSinceYears: knownSinceYears,
      preferredChannels: contact.preferredChannels,
      frequencyByMonth: frequency,
      aiConfidence: 0.82,
    );
  }

  static int _potentialGain(int bondScore, int daysSinceContact) {
    if (daysSinceContact >= 30 && bondScore < 75) return 10;
    if (daysSinceContact >= 21) return 8;
    if (bondScore >= 85) return 4;
    return 6;
  }

  static List<int> _frequencyByMonth(
    List<CrmInteraction> contactInteractions,
    DateTime now,
  ) {
    final months = List<int>.filled(12, 0);
    final firstMonth = DateTime(now.year, now.month - 11);
    for (final interaction in contactInteractions) {
      final interactionMonth = DateTime(
        interaction.date.year,
        interaction.date.month,
      );
      final monthOffset =
          (interactionMonth.year - firstMonth.year) * 12 +
          interactionMonth.month -
          firstMonth.month;
      if (monthOffset >= 0 && monthOffset < months.length) {
        months[monthOffset] += 1;
      }
    }
    return months;
  }
}

class AppController extends Notifier<AppState> {
  static const _uuid = Uuid();
  static const defaultEventTypes = [
    'Plan',
    'Reminder',
    'Birthday',
    'Meeting',
    'Call',
    'Dinner',
    'Coffee',
  ];

  @override
  AppState build() => AppState.seeded();

  void signIn() => state = state.copyWith(isAuthed: true);
  void signUp({required String name, required String email}) {
    final cleanName = name.trim();
    final cleanEmail = email.trim();
    state = state.copyWith(
      isAuthed: true,
      user: state.user.copyWith(
        name: cleanName.isEmpty ? state.user.name : cleanName,
        email: cleanEmail.isEmpty ? state.user.email : cleanEmail,
      ),
    );
  }
  void signOut() => state = AppState.seeded();
  void setTab(int index) => state = state.copyWith(selectedTab: index);

  void setThemeMode(AppThemeMode mode) =>
      state = state.copyWith(themeMode: mode);

  /// Deprecated shim for the old binary toggle. Maps `true` → dark,
  /// `false` → light. Prefer [setThemeMode]; this exists so any callers
  /// that haven't migrated yet keep compiling. Remove when wave 1 is done.
  @Deprecated('Use setThemeMode(AppThemeMode) instead')
  void setDarkMode(bool value) =>
      setThemeMode(value ? AppThemeMode.dark : AppThemeMode.light);
  void toggleGoogleCalendar(bool value) =>
      state = state.copyWith(googleCalendarLinked: value);

  void updateUser({
    required String name,
    required String email,
    required String avatar,
    required AvatarKind avatarKind,
  }) {
    state = state.copyWith(
      user: state.user.copyWith(
        name: name.trim().isEmpty ? state.user.name : name.trim(),
        email: email.trim().isEmpty ? state.user.email : email.trim(),
        avatar: avatar.trim().isEmpty ? state.user.avatar : avatar.trim(),
        avatarKind: avatarKind,
      ),
    );
  }

  void addConnection({
    required String name,
    required String email,
    required String category,
    required String notes,
  }) {
    final connection = Connection(
      id: _uuid.v4(),
      name: name,
      email: email,
      category: category,
      avatar: '👤',
      bondScore: 50,
      nextStep: 'Start first real conversation',
      lastContact: DateTime.now(),
      notes: notes,
      knownSince: DateTime.now(),
      preferredChannels: const ['Text'],
    );
    state = state.copyWith(connections: [connection, ...state.connections]);
  }

  void updateConnection(Connection connection) {
    state = state.copyWith(
      connections: [
        for (final item in state.connections)
          if (item.id == connection.id) connection else item,
      ],
    );
  }

  void deleteConnection(String contactId) {
    state = state.copyWith(
      connections: [
        for (final connection in state.connections)
          if (connection.id != contactId) connection,
      ],
      events: [
        for (final event in state.events)
          if (event.contactId != contactId) event,
      ],
      interactions: [
        for (final interaction in state.interactions)
          if (interaction.contactId != contactId) interaction,
      ],
    );
  }

  void logInteraction(
    String contactId,
    InteractionType type,
    String title,
    String note,
  ) {
    final interaction = CrmInteraction(
      id: _uuid.v4(),
      contactId: contactId,
      type: type,
      title: title,
      note: note,
      date: DateTime.now(),
    );
    state = state.copyWith(interactions: [interaction, ...state.interactions]);
  }

  void addEvent(
    String title,
    String contactId,
    String category,
    DateTime date,
    String note,
  ) {
    saveEvent(
      PlannerEvent(
        id: _uuid.v4(),
        title: title,
        contactId: contactId,
        category: category,
        date: date,
        note: note,
      ),
    );
  }

  void saveEvent(PlannerEvent event) {
    final exists = state.events.any((item) => item.id == event.id);
    state = state.copyWith(
      events: exists
          ? [
              for (final item in state.events)
                if (item.id == event.id) event else item,
            ]
          : [...state.events, event],
    );
  }

  PlannerEvent? deleteEvent(String eventId) {
    PlannerEvent? deleted;
    final remaining = <PlannerEvent>[];
    for (final event in state.events) {
      if (event.id == eventId) {
        deleted = event;
      } else {
        remaining.add(event);
      }
    }
    state = state.copyWith(events: remaining);
    return deleted;
  }

  void restoreEvent(PlannerEvent event) {
    state = state.copyWith(
      events: [...state.events, event]
        ..sort((a, b) => a.date.compareTo(b.date)),
    );
  }

  void addCategory(String category) {
    if (category.trim().isEmpty || state.categories.contains(category.trim())) {
      return;
    }
    state = state.copyWith(categories: [...state.categories, category.trim()]);
  }

  void addEventType(String eventType) {
    final clean = eventType.trim();
    if (clean.isEmpty || state.eventTypes.contains(clean)) return;
    state = state.copyWith(eventTypes: [...state.eventTypes, clean]);
  }

  void renameEventType(String oldValue, String newValue) {
    final clean = newValue.trim();
    if (clean.isEmpty || state.eventTypes.contains(clean)) return;
    state = state.copyWith(
      eventTypes: [
        for (final item in state.eventTypes)
          if (item == oldValue) clean else item,
      ],
      events: [
        for (final event in state.events)
          if (event.eventType == oldValue)
            event.copyWith(eventType: clean)
          else
            event,
      ],
    );
  }

  void deleteEventType(String eventType) {
    if (defaultEventTypes.contains(eventType)) return;
    state = state.copyWith(
      eventTypes: [
        for (final item in state.eventTypes)
          if (item != eventType) item,
      ],
      events: [
        for (final event in state.events)
          if (event.eventType == eventType)
            event.copyWith(eventType: 'Plan')
          else
            event,
      ],
    );
  }

  Future<AiUpdateResult> previewAiUpdate(
    String contactId,
    String input,
    List<AttachmentRef> attachments,
  ) async {
    final result = await ref
        .read(aiUpdateServiceProvider)
        .categorizeAndUpdate(
          input: input,
          fallbackContactId: contactId,
          attachments: attachments,
        );
    // Mark all interactions as AI-suggested
    final aiMarkedInteractions = result.interactions
        .map((interaction) => CrmInteraction(
              id: interaction.id,
              contactId: interaction.contactId,
              type: interaction.type,
              title: interaction.title,
              note: interaction.note,
              date: interaction.date,
              attachments: interaction.attachments,
              source: InteractionSource.aiSuggested,
            ))
        .toList();
    return AiUpdateResult(
      summary: result.summary,
      contactId: result.contactId,
      interactions: aiMarkedInteractions,
      nextStep: result.nextStep,
    );
  }

  void commitAiUpdate(AiUpdateResult result) {
    final updatedConnections = state.connections.map((connection) {
      if (connection.id != result.contactId) return connection;
      final nextScore = (connection.bondScore + 3).clamp(0, 100);
      return connection.copyWith(
        nextStep: result.nextStep ?? connection.nextStep,
        lastContact: DateTime.now(),
        bondScore: nextScore,
      );
    }).toList();
    state = state.copyWith(
      interactions: [...result.interactions, ...state.interactions],
      connections: updatedConnections,
      lastAiSummary: result.summary,
    );
  }

  Future<void> runAiUpdate(
    String contactId,
    String input,
    List<AttachmentRef> attachments,
  ) async {
    final result = await previewAiUpdate(contactId, input, attachments);
    commitAiUpdate(result);
  }
}
