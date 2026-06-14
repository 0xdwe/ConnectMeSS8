import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/social_models.dart';
import '../ai/ai_update_commit_plan.dart';
import 'connections/batched_writes.dart';
import 'connections/batched_writes_providers.dart';
import 'connections/connection_providers.dart';
import 'connections/connection_store.dart';
import 'connections/event_providers.dart';
import 'connections/event_store.dart';
import 'connections/interaction_providers.dart';
import 'connections/user_doc_store.dart';
import 'connections/user_doc_store_providers.dart';
import 'connections/connection_seeder.dart';
import 'connections/firebase_connection_store.dart';
import 'firebase_providers.dart';
import 'memory/memory_providers.dart';
import 'planner_event_normalizer.dart';
import 'relationship_maintenance_policy.dart';

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
        isSample: true,
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
        isSample: true,
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
        isSample: true,
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
        isSample: true,
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
        isSample: true,
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
    final now = DateTime.now();
    final knownSinceYears = (now.difference(contact.knownSince).inDays / 365)
        .floor()
        .clamp(1, 99);

    return ContactInsight(
      contactId: contact.id,
      relationshipLabel: contact.category,
      knownSinceYears: knownSinceYears,
    );
  }
}

/// Source of truth for connections, interactions, events, categories
/// and event types is now Firestore, mirrored locally by the four
/// stores (`ConnectionStore`, `InteractionStore`, `EventStore`,
/// `UserDocStore`) — Pass 4.5 #070, PRD §Q4.
///
/// AppController is the single write coordinator: every mutating
/// method writes through the appropriate store(s) BEFORE updating
/// `state`. The two multi-store operations
/// ([deleteConnection], [applyAiUpdateResult]) go through
/// [BatchedWrites] for atomic-across-collections semantics. On
/// store failure, the in-memory `state` is not advanced — the
/// existing `AiUpdate.commit` retryable error path runs, and the
/// caller observes the thrown exception.
///
/// **Read paths.** AppController also owns the four snapshot
/// listeners. On construction it subscribes to each store's
/// `snapshot()` stream and projects new emissions into `state`.
/// This keeps `state.connections` etc. consistent with the live
/// Firestore mirror, including writes from another device.
///
/// **Sign-out hotfix removed.** The pre-Pass-4.5 `signOut` had a
/// special "preserve user data" cascade because in-memory state
/// was the only durable record. With Firestore as the source of
/// truth, sign-out can revert to its trivial shape: flip
/// `isAuthed`, reset the tab, drop in-memory connection /
/// interaction / event / categories / eventTypes back to defaults.
/// The auth-aware provider rebuilds tear down the snapshot
/// listeners on the next sign-in / swap; AppController itself
/// rebuilds on the auth swap (see `firebaseAuthProvider` watch
/// in [build]).
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

  StreamSubscription<Map<String, Connection>>? _connectionsSub;
  StreamSubscription<Map<String, CrmInteraction>>? _interactionsSub;
  StreamSubscription<Map<String, PlannerEvent>>? _eventsSub;
  StreamSubscription<UserDocSnapshot>? _userDocSub;
  bool _hasConnectionsSnapshot = false;
  bool _hasInteractionsSnapshot = false;
  bool _bondDriftCheckScheduled = false;
  bool _disposed = false;
  final Map<String, DateTime> _pendingBondDriftAppliedAtById =
      <String, DateTime>{};

  @override
  AppState build() {
    // Auth-aware rebuild cascades transitively: every store
    // provider below watches `currentUserProvider`, so a sign-in /
    // sign-out / swap rebuilds the store identities, which
    // rebuilds this controller. The previous build's snapshot
    // subscriptions cancel below before re-subscribing to the new
    // stores. Mirrors the auth-aware shape from Pass 4.2 #058 —
    // the controller's identity is per-UID transitively.

    _connectionsSub?.cancel();
    _interactionsSub?.cancel();
    _eventsSub?.cancel();
    _userDocSub?.cancel();
    _connectionsSub = null;
    _interactionsSub = null;
    _eventsSub = null;
    _userDocSub = null;
    _hasConnectionsSnapshot = false;
    _hasInteractionsSnapshot = false;
    _bondDriftCheckScheduled = false;
    _disposed = false;
    _pendingBondDriftAppliedAtById.clear();

    final connectionStore = ref.watch(connectionStoreProvider);
    final interactionStore = ref.watch(interactionStoreProvider);
    final eventStore = ref.watch(eventStoreProvider);
    final userDocStore = ref.watch(userDocStoreProvider);

    final user = ref.watch(currentUserProvider);
    if (user != null && connectionStore is FirebaseConnectionStore) {
      final firestore = ref.watch(firestoreProvider);
      Future(() async {
        try {
          final seeder = ConnectionSeeder(firestore: firestore, uid: user.uid);
          await seeder.run(choice: SeederChoice.samples);
        } catch (_) {}
      });
    }

    _connectionsSub = connectionStore.snapshot().listen(
      (snapshot) {
        // Snapshot ordering: keep insertion order from the map
        // (Firestore returns documents in collection order). Tests
        // can override with their own InMemory store and rely on
        // its broadcast order.
        state = state.copyWith(connections: snapshot.values.toList());
        _hasConnectionsSnapshot = true;
        _scheduleBondDriftCheck();
      },
      onError: (_) {
        // Listener errors leave the last-known-good state in place.
        // The store's snapshotSync mirror is also unchanged on
        // error per PRD §Q6.
      },
    );

    _interactionsSub = interactionStore.snapshot().listen((snapshot) {
      // Newest-first ordering matches the prior in-memory
      // shape (`addInteraction` prepended) so widgets that read
      // `state.interactions` keep the same chronological feel.
      final values = snapshot.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      state = state.copyWith(interactions: values);
      _hasInteractionsSnapshot = true;
      _scheduleBondDriftCheck();
    }, onError: (_) {});

    _eventsSub = eventStore.snapshot().listen((snapshot) {
      // Date-sorted ascending matches the calendar UI's expected
      // order. `restoreEvent` previously sorted; doing it here
      // keeps the contract uniform regardless of write source.
      final values = snapshot.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      state = state.copyWith(events: values);
    }, onError: (_) {});

    _userDocSub = userDocStore.snapshot().listen((snapshot) {
      // Empty snapshots happen during sign-out / pre-seed. Fall
      // back to the seed defaults so category / event-type
      // pickers don't blank out for one frame.
      final categories = snapshot.categories.isEmpty
          ? UserDocDefaults.categories()
          : snapshot.categories;
      final eventTypes = snapshot.eventTypes.isEmpty
          ? UserDocDefaults.eventTypes()
          : snapshot.eventTypes;
      state = state.copyWith(categories: categories, eventTypes: eventTypes);
    }, onError: (_) {});

    ref.onDispose(() {
      _disposed = true;
      _connectionsSub?.cancel();
      _interactionsSub?.cancel();
      _eventsSub?.cancel();
      _userDocSub?.cancel();
    });

    // Initial state is the seeded value. The store snapshot
    // listeners replace `state.connections` etc. with the live
    // mirror as soon as they fire. Tests that override the stores
    // with InMemory adapters still see seeded data because the
    // initial state ships with the seed; the override starts empty
    // unless the test populates it, in which case the snapshot
    // overwrites the seed on the first emission.
    return AppState.seeded();
  }

  void _scheduleBondDriftCheck() {
    if (!_hasConnectionsSnapshot || !_hasInteractionsSnapshot) return;
    if (_bondDriftCheckScheduled) return;
    _bondDriftCheckScheduled = true;
    Future(() async {
      if (_disposed) return;
      _bondDriftCheckScheduled = false;
      await _applyEligibleBondDrift();
    });
  }

  Future<void> _applyEligibleBondDrift() async {
    final now = ref.read(clockProvider)();
    final connectionStore = ref.read(connectionStoreProvider);
    for (final connection in state.connections) {
      final pendingAppliedAt = _pendingBondDriftAppliedAtById[connection.id];
      if (pendingAppliedAt != null) {
        if (connection.lastBondDriftAppliedAt == pendingAppliedAt) {
          _pendingBondDriftAppliedAtById.remove(connection.id);
        } else {
          continue;
        }
      }

      final result = RelationshipMaintenancePolicy.evaluate(
        connection: connection,
        interactions: state.interactions,
        now: now,
      );
      if (!result.isBondDriftApplicationEligible) continue;
      if (result.candidateBondDrift >= 0) continue;

      final updated = connection.copyWith(
        bondScore: connection.bondScore + result.candidateBondDrift,
        lastBondDriftAppliedAt: now,
      );
      _pendingBondDriftAppliedAtById[connection.id] = now;
      try {
        await connectionStore.save(updated);
      } catch (_) {
        _pendingBondDriftAppliedAtById.remove(connection.id);
      }
    }
  }

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

  /// Sign out is now trivial: flip `isAuthed`, reset the tab, and
  /// drop the in-memory mirrors back to defaults. Firestore is the
  /// source of truth — the auth-aware provider rebuilds tear down
  /// the snapshot listeners; the next sign-in re-subscribes against
  /// the new UID and rebuilds `state` from the live mirror.
  ///
  /// The Pass 4.5 hotfix logic (preserve non-sample connections /
  /// cascade sample drops to interactions and events) is REMOVED.
  /// Hotfix-era data loss across the upgrade is documented in the
  /// PRD §Q7; user-added data persisted via the post-#070 path
  /// survives sign-out automatically because it lives in
  /// Firestore.
  void signOut() {
    state = state.copyWith(
      isAuthed: false,
      selectedTab: 0,
      connections: const <Connection>[],
      interactions: const <CrmInteraction>[],
      events: const <PlannerEvent>[],
      categories: UserDocDefaults.categories(),
      eventTypes: UserDocDefaults.eventTypes(),
    );
  }

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

  /// Persist a new connection via [ConnectionStore.save]. The
  /// snapshot listener in [build] picks up the write and updates
  /// `state.connections`.
  ///
  /// Returns the constructed [Connection] so callers can reference
  /// the newly assigned id without re-reading state.
  Future<Connection> addConnection({
    required String name,
    required String email,
    required String category,
    required String notes,
    String phone = '',
    String address = '',
    String instagram = '',
    String linkedin = '',
    String whatsapp = '',
    String line = '',
    String avatar = '👤',
  }) async {
    final connection = Connection(
      id: _uuid.v4(),
      name: name,
      email: email,
      category: category,
      avatar: avatar,
      bondScore: 50,
      nextStep: 'Start first real conversation',
      lastContact: DateTime.now(),
      notes: notes,
      knownSince: DateTime.now(),
      preferredChannels: const ['Text'],
      phone: phone,
      address: address,
      instagram: instagram,
      linkedin: linkedin,
      whatsapp: whatsapp,
      line: line,
    );
    await ref.read(connectionStoreProvider).save(connection);
    return connection;
  }

  Future<void> updateConnection(Connection connection) async {
    await ref.read(connectionStoreProvider).save(connection);
  }

  /// Atomically delete a connection plus its dependent interactions
  /// and events. Memory cascade fires after the batch commits.
  /// On batch failure, in-memory state is not advanced — the caller
  /// sees the thrown exception from [BatchedWrites].
  Future<void> deleteConnection(String contactId) async {
    final batched = ref.read(batchedWritesProvider);
    await batched.commitDeleteConnection(
      contactId: contactId,
      interactions: state.interactions,
      events: state.events,
    );
    // Memory cascade: the memory store has its own write contract
    // (Pass 4.2). Fire after the multi-store batch commits — if the
    // batch failed, the memory delete should not run. Best-effort
    // (matches the pre-Pass-4.5 fire-and-forget shape); rollback
    // for memory is outside the Firestore-batch boundary.
    try {
      await ref.read(memoryStoreProvider).delete(contactId);
    } catch (_) {
      // Memory is informational; a transient failure here does not
      // reverse the connection delete.
    }
  }

  /// Drop every sample connection and the interactions / events
  /// tied to those connections. Used in onboarding's "Start fresh"
  /// path before the user has built their own list.
  ///
  /// Implementation: composes one Firestore batch covering every
  /// sample connection plus its dependent interactions and events,
  /// committed atomically via [BatchedWrites.commitRemoveSampleConnections]
  /// (Pass 4.5 #070 review C2). On batch failure, in-memory state
  /// is not advanced — the caller sees the thrown exception.
  /// Memory cascade fires per-id post-batch best-effort.
  Future<void> removeSampleConnections() async {
    final samples = state.connections
        .where((c) => c.isSample)
        .toList(growable: false);
    if (samples.isEmpty) return;
    final batched = ref.read(batchedWritesProvider);
    await batched.commitRemoveSampleConnections(
      connections: samples,
      interactions: state.interactions,
      events: state.events,
    );
    // Memory cascade: same shape as [deleteConnection] — best-effort,
    // post-batch, per-id (memory store has its own write contract).
    for (final sample in samples) {
      try {
        await ref.read(memoryStoreProvider).delete(sample.id);
      } catch (_) {
        // Informational; a transient failure here does not reverse
        // the connection deletes.
      }
    }
  }

  Future<void> logInteraction(
    String contactId,
    InteractionType type,
    String title,
    String note,
  ) async {
    final interaction = CrmInteraction(
      id: _uuid.v4(),
      contactId: contactId,
      type: type,
      title: title,
      note: note,
      date: DateTime.now(),
    );
    await ref.read(interactionStoreProvider).save(interaction);
  }

  Future<void> addEvent(
    String title,
    String contactId,
    String category,
    DateTime date,
    String note,
  ) async {
    await saveEvent(
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

  Future<void> saveEvent(PlannerEvent event) async {
    await ref.read(eventStoreProvider).save(normalizePlannerEvent(event));
  }

  /// Delete an event and return the deleted record so the UI can
  /// offer a snackbar undo. Reads from the in-memory mirror to find
  /// the prior record before the snapshot listener removes it.
  Future<PlannerEvent?> deleteEvent(String eventId) async {
    PlannerEvent? deleted;
    for (final event in state.events) {
      if (event.id == eventId) {
        deleted = event;
        break;
      }
    }
    if (deleted == null) return null;
    await ref.read(eventStoreProvider).delete(eventId);
    return deleted;
  }

  Future<void> restoreEvent(PlannerEvent event) async {
    await ref.read(eventStoreProvider).save(normalizePlannerEvent(event));
  }

  Future<void> addCategory(String category) async {
    final clean = category.trim();
    if (clean.isEmpty || state.categories.contains(clean)) {
      return;
    }
    final next = <String>[...state.categories, clean];
    await ref.read(userDocStoreProvider).saveCategories(next);
  }

  Future<void> deleteCategory(String category) async {
    final clean = category.trim();
    if (!state.categories.contains(clean)) {
      return;
    }
    final next = state.categories.where((c) => c != clean).toList();
    await ref.read(userDocStoreProvider).saveCategories(next);
  }

  Future<void> addEventType(String eventType) async {
    final clean = eventType.trim();
    if (clean.isEmpty || state.eventTypes.contains(clean)) return;
    final next = <String>[...state.eventTypes, clean];
    await ref.read(userDocStoreProvider).saveEventTypes(next);
    state = state.copyWith(eventTypes: next);
  }

  /// Rename an event type. Cascades to every event that referenced
  /// the old type. The user-doc list update lives in
  /// [UserDocStore]; the event cascade goes through
  /// [EventStore.save] per affected event. The two writes are NOT
  /// in the same Firestore batch — the user-doc and event
  /// collections live under different document paths but the
  /// updates are compatible (a stale event tagged with the old
  /// name is recoverable from the client). This matches the
  /// AC text: "user-doc + cascade".
  Future<void> renameEventType(String oldValue, String newValue) async {
    final clean = newValue.trim();
    if (clean.isEmpty || state.eventTypes.contains(clean)) return;
    final next = <String>[
      for (final item in state.eventTypes)
        if (item == oldValue) clean else item,
    ];
    await ref.read(userDocStoreProvider).saveEventTypes(next);
    state = state.copyWith(eventTypes: next);
    final eventStore = ref.read(eventStoreProvider);
    for (final event in state.events) {
      if (event.eventType == oldValue) {
        await eventStore.save(event.copyWith(eventType: clean));
      }
    }
  }

  Future<void> deleteEventType(String eventType) async {
    if (defaultEventTypes.contains(eventType)) return;
    final next = <String>[
      for (final item in state.eventTypes)
        if (item != eventType) item,
    ];
    await ref.read(userDocStoreProvider).saveEventTypes(next);
    state = state.copyWith(eventTypes: next);
    final eventStore = ref.read(eventStoreProvider);
    for (final event in state.events) {
      if (event.eventType == eventType) {
        await eventStore.save(event.copyWith(eventType: 'Plan'));
      }
    }
  }

  /// Apply a previously-produced [AiUpdateResult] to Firestore via
  /// the multi-store atomic batch (PRD §Q4 #070).
  ///
  /// The batch writes the new interaction AND the bumped
  /// connection in one Firestore commit. On commit failure the
  /// caller observes the thrown exception; in-memory state is not
  /// advanced because the snapshot listeners only update on
  /// successful writes.
  ///
  /// `lastAiSummary` updates locally because it is informational UI
  /// state, not a stored Firestore field.
  Future<void> applyAiUpdateResult(AiUpdateResult result) async {
    final connection = state.connections.firstWhere(
      (c) => c.id == result.contactId,
      orElse: () => throw StateError(
        'applyAiUpdateResult: contactId ${result.contactId} not found',
      ),
    );
    final plan = buildAiUpdateCommitPlan(
      result: result,
      connection: connection,
      now: DateTime.now(),
    );

    await ref
        .read(batchedWritesProvider)
        .commitAiUpdate(
          interaction: plan.interaction,
          updatedConnection: plan.updatedConnection,
        );

    // lastAiSummary is informational; not part of the persisted
    // Firestore shape. Update only after a successful batch commit
    // so a failed batch leaves the prior summary in place.
    state = state.copyWith(lastAiSummary: plan.summary);
  }
}
