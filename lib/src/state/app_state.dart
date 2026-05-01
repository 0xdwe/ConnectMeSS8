import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../ai/ai_update_service.dart';
import '../models/social_models.dart';

final aiUpdateServiceProvider = Provider<AiUpdateService>((ref) => const MockAiUpdateService());
final appControllerProvider = NotifierProvider<AppController, AppState>(AppController.new);

class AppState {
  const AppState({
    required this.isAuthed,
    required this.darkMode,
    required this.selectedTab,
    required this.connections,
    required this.interactions,
    required this.events,
    required this.categories,
    required this.googleCalendarLinked,
    this.lastAiSummary,
  });

  final bool isAuthed;
  final bool darkMode;
  final int selectedTab;
  final List<Connection> connections;
  final List<CrmInteraction> interactions;
  final List<PlannerEvent> events;
  final List<String> categories;
  final bool googleCalendarLinked;
  final String? lastAiSummary;

  int get averageConnectionScore => connections.isEmpty ? 0 : (connections.map((c) => c.bondScore).reduce((a, b) => a + b) / connections.length).round();

  List<Recommendation> get recommendations => [
        const Recommendation(contactId: 'mike', reason: 'Over 1 month since last contact', insight: 'You talked about his job application last time', priority: 'high priority'),
        const Recommendation(contactId: 'jessica', reason: '3 weeks without interaction', insight: 'She mentioned planning a trip to Europe', priority: 'medium priority'),
        const Recommendation(contactId: 'emily', reason: 'Great momentum - keep it going!', insight: 'This is her first week at the new role', priority: 'low priority'),
      ];

  factory AppState.seeded() {
    final now = DateTime.now();
    final people = [
      Connection(id: 'david', name: 'David Kim', email: 'david.k@email.com', category: 'Family', avatar: '👨‍👩‍👧', bondScore: 95, nextStep: 'Ask about family dinner plans', lastContact: now.subtract(const Duration(days: 4)), notes: 'Family anchor. Likes weekend updates.'),
      Connection(id: 'emily', name: 'Emily Rodriguez', email: 'emily.r@email.com', category: 'Work', avatar: '👩‍💼', bondScore: 85, nextStep: 'Ask about first week in new role', lastContact: now.subtract(const Duration(days: 5)), notes: 'First week at new role. Keep momentum going.'),
      Connection(id: 'jessica', name: 'Jessica Taylor', email: 'jess.t@email.com', category: 'College', avatar: '👩‍🎓', bondScore: 73, nextStep: 'Ask about Europe trip planning', lastContact: now.subtract(const Duration(days: 22)), notes: 'Mentioned planning a Europe trip.'),
      Connection(id: 'mike', name: 'Mike Chen', email: 'mike.chen@email.com', category: 'High School', avatar: '👨', bondScore: 68, nextStep: 'Follow up on job application', lastContact: now.subtract(const Duration(days: 39)), notes: 'Talked about his job application last time.'),
      Connection(id: 'sarah', name: 'Sarah Johnson', email: 'sarah.j@email.com', category: 'Friends', avatar: '👱‍♀️', bondScore: 92, nextStep: 'Coffee catch-up', lastContact: now.subtract(const Duration(days: 7)), notes: 'Coffee with Sarah scheduled.'),
    ];
    return AppState(
      isAuthed: false,
      darkMode: false,
      selectedTab: 0,
      connections: people,
      categories: const ['Family', 'Friends', 'High School', 'College', 'Work'],
      googleCalendarLinked: true,
      interactions: [
        CrmInteraction(id: 'i1', contactId: 'sarah', type: InteractionType.sharedActivity, title: 'Coffee plan', note: 'Coffee with Sarah on April 28.', date: DateTime(2026, 4, 20)),
        CrmInteraction(id: 'i2', contactId: 'mike', type: InteractionType.reminder, title: 'Job application', note: 'Ask Mike about his application progress.', date: DateTime(2026, 3, 23)),
        CrmInteraction(id: 'i3', contactId: 'emily', type: InteractionType.relationshipNote, title: 'New role', note: 'Emily started a new role this week.', date: DateTime(2026, 4, 18)),
      ],
      events: [
        PlannerEvent(id: 'e1', title: 'Coffee with Sarah', contactId: 'sarah', category: 'Friends', date: DateTime(2026, 4, 28), note: 'Google Calendar mock sync'),
        PlannerEvent(id: 'e2', title: 'Team Meeting', contactId: 'emily', category: 'Work', date: DateTime(2026, 4, 30), note: 'Discuss launch'),
        PlannerEvent(id: 'e3', title: 'Call Mike (Reminder)', contactId: 'mike', category: 'High School', date: DateTime(2026, 5, 5), note: 'Ask about job application'),
        PlannerEvent(id: 'e4', title: "Emily's Birthday", contactId: 'emily', category: 'Work', date: DateTime(2026, 5, 12), note: 'Send message'),
        PlannerEvent(id: 'e5', title: 'Family Dinner', contactId: 'david', category: 'Family', date: DateTime(2026, 5, 15), note: 'Dinner'),
      ],
    );
  }

  AppState copyWith({
    bool? isAuthed,
    bool? darkMode,
    int? selectedTab,
    List<Connection>? connections,
    List<CrmInteraction>? interactions,
    List<PlannerEvent>? events,
    List<String>? categories,
    bool? googleCalendarLinked,
    String? lastAiSummary,
  }) {
    return AppState(
      isAuthed: isAuthed ?? this.isAuthed,
      darkMode: darkMode ?? this.darkMode,
      selectedTab: selectedTab ?? this.selectedTab,
      connections: connections ?? this.connections,
      interactions: interactions ?? this.interactions,
      events: events ?? this.events,
      categories: categories ?? this.categories,
      googleCalendarLinked: googleCalendarLinked ?? this.googleCalendarLinked,
      lastAiSummary: lastAiSummary ?? this.lastAiSummary,
    );
  }
}

class AppController extends Notifier<AppState> {
  static const _uuid = Uuid();

  @override
  AppState build() => AppState.seeded();

  void signIn() => state = state.copyWith(isAuthed: true);
  void signOut() => state = AppState.seeded();
  void setTab(int index) => state = state.copyWith(selectedTab: index);
  void setDarkMode(bool value) => state = state.copyWith(darkMode: value);
  void toggleGoogleCalendar(bool value) => state = state.copyWith(googleCalendarLinked: value);

  void addConnection({required String name, required String email, required String category, required String notes}) {
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
    );
    state = state.copyWith(connections: [connection, ...state.connections]);
  }

  void updateConnection(Connection connection) {
    state = state.copyWith(connections: [for (final item in state.connections) if (item.id == connection.id) connection else item]);
  }

  void logInteraction(String contactId, InteractionType type, String title, String note) {
    final interaction = CrmInteraction(id: _uuid.v4(), contactId: contactId, type: type, title: title, note: note, date: DateTime.now());
    state = state.copyWith(interactions: [interaction, ...state.interactions]);
  }

  void addEvent(String title, String contactId, String category, DateTime date, String note) {
    final event = PlannerEvent(id: _uuid.v4(), title: title, contactId: contactId, category: category, date: date, note: note);
    state = state.copyWith(events: [...state.events, event]);
  }

  void deleteEvent(String eventId) {
    state = state.copyWith(events: [for (final event in state.events) if (event.id != eventId) event]);
  }

  void addCategory(String category) {
    if (category.trim().isEmpty || state.categories.contains(category.trim())) return;
    state = state.copyWith(categories: [...state.categories, category.trim()]);
  }

  Future<void> runAiUpdate(String contactId, String input, List<AttachmentRef> attachments) async {
    final result = await ref.read(aiUpdateServiceProvider).categorizeAndUpdate(input: input, fallbackContactId: contactId, attachments: attachments);
    final updatedConnections = state.connections.map((connection) {
      if (connection.id != result.contactId) return connection;
      final nextScore = (connection.bondScore + 3).clamp(0, 100);
      return connection.copyWith(nextStep: result.nextStep ?? connection.nextStep, lastContact: DateTime.now(), bondScore: nextScore);
    }).toList();
    state = state.copyWith(interactions: [...result.interactions, ...state.interactions], connections: updatedConnections, lastAiSummary: result.summary);
  }
}
