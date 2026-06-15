import 'dart:async';

import 'package:connect_me/src/ai/ai_update.dart';
import 'package:connect_me/src/ai/fake_memory_rebuilder.dart';
import 'package:connect_me/src/ai/memory_rebuilder.dart';
import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/app_state.dart';
import 'package:connect_me/src/state/connections/batched_writes.dart';
import 'package:connect_me/src/state/connections/batched_writes_providers.dart';
import 'package:connect_me/src/state/connections/connection_providers.dart';
import 'package:connect_me/src/state/connections/connection_store.dart';
import 'package:connect_me/src/state/connections/event_providers.dart';
import 'package:connect_me/src/state/connections/event_store.dart';
import 'package:connect_me/src/state/connections/in_memory_connection_store.dart';
import 'package:connect_me/src/state/connections/in_memory_event_store.dart';
import 'package:connect_me/src/state/connections/in_memory_interaction_store.dart';
import 'package:connect_me/src/state/connections/in_memory_user_doc_store.dart';
import 'package:connect_me/src/state/connections/interaction_providers.dart';
import 'package:connect_me/src/state/connections/interaction_store.dart';
import 'package:connect_me/src/state/connections/user_doc_store.dart';
import 'package:connect_me/src/state/connections/user_doc_store_providers.dart';
import 'package:connect_me/src/state/firebase_providers.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:connect_me/src/state/memory/memory_rebuilder_providers.dart';
import 'package:connect_me/src/state/notifications/notification_preferences.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Build a [ProviderContainer] wired through the four Pass 4.5 store
/// seams: connection, interaction, event, user-doc, plus memory.
///
/// Pass [signedIn] = false to drive the signed-out sentinels (every
/// store's async surface throws). Default is signed-in: a stub auth
/// user is wired through `firebaseAuthProvider` so `currentUserProvider`
/// resolves to a non-null `User`. The signed-in store *overrides* still
/// take precedence — the auth wiring is just there to keep the stores'
/// internal sentinel guards from kicking in for tests that don't
/// override every store individually.
ProviderContainer _container({
  InMemoryMemoryStore? memoryStore,
  ConnectionStore? connectionStore,
  InteractionStore? interactionStore,
  EventStore? eventStore,
  UserDocStore? userDocStore,
  BatchedWrites? batchedWrites,
  DateTime Function()? clock,
  bool signedIn = true,
  MemoryRebuilder? memoryRebuilder,
  // Use dynamic because Riverpod 3's Override type is not part of the
  // public flutter_riverpod surface.
  List<dynamic>? overrides,
}) {
  final memory = memoryStore ?? InMemoryMemoryStore();
  final connections = connectionStore ?? InMemoryConnectionStore();
  final interactions = interactionStore ?? InMemoryInteractionStore();
  final events = eventStore ?? InMemoryEventStore();
  final userDoc = userDocStore ?? InMemoryUserDocStore();
  final batched =
      batchedWrites ??
      InMemoryBatchedWrites(
        connectionStore: connections,
        interactionStore: interactions,
        eventStore: events,
      );

  final mockAuth = MockFirebaseAuth(
    signedIn: signedIn,
    mockUser: signedIn
        ? MockUser(
            isAnonymous: false,
            uid: 'test-user',
            email: 'test@example.com',
            displayName: 'Test User',
          )
        : null,
  );

  return ProviderContainer(
    overrides: [
      firebaseAuthProvider.overrideWithValue(mockAuth),
      memoryStoreProvider.overrideWithValue(memory),
      connectionStoreProvider.overrideWithValue(connections),
      interactionStoreProvider.overrideWithValue(interactions),
      eventStoreProvider.overrideWithValue(events),
      userDocStoreProvider.overrideWithValue(userDoc),
      batchedWritesProvider.overrideWithValue(batched),
      if (clock != null) clockProvider.overrideWithValue(clock),
      // Pass 4.3 #081: production aiUpdateProvider now constructs
      // LlmAiUpdate which would reach Firebase AI Logic. These tests
      // predate the cutover and rely on MockAiUpdate's deterministic
      // shape; pin Mock as the active adapter, sharing the same
      // memoryStore + AppController the rest of the container reads.
      aiUpdateProvider.overrideWith(
        (ref) => MockAiUpdate(
          memoryStore: memory,
          appController: ref.read(appControllerProvider.notifier),
        ),
      ),
      if (overrides != null) ...overrides,
      if (memoryRebuilder != null)
        memoryRebuilderProvider.overrideWithValue(memoryRebuilder),
    ],
  );
}

/// Pump the event loop a few times so snapshot stream emissions land
/// in `state` before assertions read it. The InMemory stores publish
/// synchronously to a broadcast controller, but Riverpod's notifier
/// listener is asynchronous — without a pump, `state.connections` is
/// still the seeded list one frame after a `save`.
Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Pre-populate an [InMemoryConnectionStore] with the seed connections
/// so a test starts in the same shape the user sees on first launch
/// (post-#070, where Firestore is the source of truth and the snapshot
/// listener fills `state.connections` rather than the Notifier's
/// initial seeded value).
Future<void> _seedConnections(InMemoryConnectionStore store) async {
  for (final c in AppState.seeded().connections) {
    await store.save(c);
  }
}

Future<void> _seedInteractions(InMemoryInteractionStore store) async {
  for (final i in AppState.seeded().interactions) {
    await store.save(i);
  }
}

Future<void> _seedEvents(InMemoryEventStore store) async {
  for (final e in AppState.seeded().events) {
    await store.save(e);
  }
}

Connection _bondDriftTestConnection({
  required DateTime now,
  int bondScore = 50,
  DateTime? lastContact,
  DateTime? lastBondDriftAppliedAt,
}) {
  return Connection(
    id: 'drift-target',
    name: 'Drift Target',
    email: 'drift@example.com',
    category: 'Friends',
    avatar: '🙂',
    bondScore: bondScore,
    nextStep: '',
    lastContact: lastContact ?? now.subtract(const Duration(days: 42)),
    notes: '',
    knownSince: DateTime(2020),
    preferredChannels: const ['Text'],
    lastBondDriftAppliedAt: lastBondDriftAppliedAt,
  );
}

class _RecordingConnectionStore extends InMemoryConnectionStore {
  int activeSnapshotListeners = 0;

  @override
  Stream<Map<String, Connection>> snapshot() {
    late StreamController<Map<String, Connection>> controller;
    StreamSubscription<Map<String, Connection>>? sub;
    controller = StreamController<Map<String, Connection>>(
      onListen: () {
        activeSnapshotListeners++;
        sub = super.snapshot().listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () async {
        activeSnapshotListeners--;
        await sub?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }
}

class _RecordingInteractionStore extends InMemoryInteractionStore {
  int activeSnapshotListeners = 0;

  @override
  Stream<Map<String, CrmInteraction>> snapshot() {
    late StreamController<Map<String, CrmInteraction>> controller;
    StreamSubscription<Map<String, CrmInteraction>>? sub;
    controller = StreamController<Map<String, CrmInteraction>>(
      onListen: () {
        activeSnapshotListeners++;
        sub = super.snapshot().listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () async {
        activeSnapshotListeners--;
        await sub?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }
}

class _RecordingEventStore extends InMemoryEventStore {
  int activeSnapshotListeners = 0;

  @override
  Stream<Map<String, PlannerEvent>> snapshot() {
    late StreamController<Map<String, PlannerEvent>> controller;
    StreamSubscription<Map<String, PlannerEvent>>? sub;
    controller = StreamController<Map<String, PlannerEvent>>(
      onListen: () {
        activeSnapshotListeners++;
        sub = super.snapshot().listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () async {
        activeSnapshotListeners--;
        await sub?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }
}

class _RecordingUserDocStore extends InMemoryUserDocStore {
  int activeSnapshotListeners = 0;

  @override
  Stream<UserDocSnapshot> snapshot() {
    late StreamController<UserDocSnapshot> controller;
    StreamSubscription<UserDocSnapshot>? sub;
    controller = StreamController<UserDocSnapshot>(
      onListen: () {
        activeSnapshotListeners++;
        sub = super.snapshot().listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () async {
        activeSnapshotListeners--;
        await sub?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }
}

class _SignedOutTestConnectionStore implements ConnectionStore {
  const _SignedOutTestConnectionStore();

  StateError get _error => StateError('signed out');

  @override
  Future<Connection?> load(String contactId) => Future.error(_error);

  @override
  Future<void> save(Connection connection) => Future.error(_error);

  @override
  Future<void> delete(String contactId) => Future.error(_error);

  @override
  Future<Map<String, Connection>> listAll() => Future.error(_error);

  @override
  Stream<Map<String, Connection>> snapshot() =>
      Stream.value(const <String, Connection>{});

  @override
  Map<String, Connection>? snapshotSync() => const <String, Connection>{};

  @override
  Future<void> dispose() async {}
}

class _SignedOutTestInteractionStore implements InteractionStore {
  const _SignedOutTestInteractionStore();

  StateError get _error => StateError('signed out');

  @override
  Future<CrmInteraction?> load(String interactionId) => Future.error(_error);

  @override
  Future<void> save(CrmInteraction interaction) => Future.error(_error);

  @override
  Future<void> delete(String interactionId) => Future.error(_error);

  @override
  Future<Map<String, CrmInteraction>> listAll() => Future.error(_error);

  @override
  Stream<Map<String, CrmInteraction>> snapshot() =>
      Stream.value(const <String, CrmInteraction>{});

  @override
  Map<String, CrmInteraction>? snapshotSync() =>
      const <String, CrmInteraction>{};

  @override
  Future<void> dispose() async {}
}

class _SignedOutTestEventStore implements EventStore {
  const _SignedOutTestEventStore();

  StateError get _error => StateError('signed out');

  @override
  Future<PlannerEvent?> load(String eventId) => Future.error(_error);

  @override
  Future<void> save(PlannerEvent event) => Future.error(_error);

  @override
  Future<void> delete(String eventId) => Future.error(_error);

  @override
  Future<Map<String, PlannerEvent>> listAll() => Future.error(_error);

  @override
  Stream<Map<String, PlannerEvent>> snapshot() =>
      Stream.value(const <String, PlannerEvent>{});

  @override
  Map<String, PlannerEvent>? snapshotSync() => const <String, PlannerEvent>{};

  @override
  Future<void> dispose() async {}
}

class _SignedOutTestUserDocStore implements UserDocStore {
  const _SignedOutTestUserDocStore();

  StateError get _error => StateError('signed out');

  @override
  Future<void> saveCategories(List<String> categories) => Future.error(_error);

  @override
  Future<void> saveEventTypes(List<String> eventTypes) => Future.error(_error);

  @override
  Future<void> saveNotificationPreferences(
    NotificationPreferences preferences,
  ) => Future.error(_error);

  @override
  Stream<UserDocSnapshot> snapshot() => Stream.value(UserDocSnapshot.empty);

  @override
  UserDocSnapshot? snapshotSync() => UserDocSnapshot.empty;

  @override
  Future<void> dispose() async {}
}

void main() {
  group('Bond Drift application', () {
    test(
      'app hydration applies first eligible drift through ConnectionStore',
      () async {
        final now = DateTime(2026, 6, 4, 12);
        final connections = InMemoryConnectionStore();
        final interactions = InMemoryInteractionStore();
        await connections.save(_bondDriftTestConnection(now: now));
        await interactions.clear();

        final container = _container(
          connectionStore: connections,
          interactionStore: interactions,
          clock: () => now,
        );
        addTearDown(container.dispose);

        container.read(appControllerProvider);
        await _settle();

        final saved = (await connections.load('drift-target'))!;
        expect(saved.bondScore, 45);
        expect(saved.lastBondDriftAppliedAt, now);
      },
    );

    test(
      'skips drift when last application was less than 3 days ago',
      () async {
        final now = DateTime(2026, 6, 4, 12);
        final previous = now.subtract(const Duration(days: 2, hours: 23));
        final connections = InMemoryConnectionStore();
        final interactions = InMemoryInteractionStore();
        await connections.save(
          _bondDriftTestConnection(now: now, lastBondDriftAppliedAt: previous),
        );
        await interactions.clear();

        final container = _container(
          connectionStore: connections,
          interactionStore: interactions,
          clock: () => now,
        );
        addTearDown(container.dispose);

        container.read(appControllerProvider);
        await _settle();

        final saved = (await connections.load('drift-target'))!;
        expect(saved.bondScore, 50);
        expect(saved.lastBondDriftAppliedAt, previous);
      },
    );

    test('skips persistence when policy returns no candidate drift', () async {
      final now = DateTime(2026, 6, 4, 12);
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      await connections.save(
        _bondDriftTestConnection(
          now: now,
          lastContact: now.subtract(const Duration(days: 1)),
        ),
      );
      await interactions.clear();

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
        clock: () => now,
      );
      addTearDown(container.dispose);

      container.read(appControllerProvider);
      await _settle();

      final saved = (await connections.load('drift-target'))!;
      expect(saved.bondScore, 50);
      expect(saved.lastBondDriftAppliedAt, isNull);
    });

    test(
      'app hydration plus recommendation refresh does not double-apply drift',
      () async {
        final now = DateTime(2026, 6, 4, 12);
        final connections = InMemoryConnectionStore();
        final interactions = InMemoryInteractionStore();
        await connections.save(_bondDriftTestConnection(now: now));
        await interactions.clear();

        final container = _container(
          connectionStore: connections,
          interactionStore: interactions,
          clock: () => now,
        );
        addTearDown(container.dispose);

        container.read(appControllerProvider);
        await _settle();
        final afterHydration = (await connections.load('drift-target'))!;
        expect(afterHydration.bondScore, 45);
        expect(afterHydration.lastBondDriftAppliedAt, now);

        await container.read(recommendationsProvider.future);
        await _settle();

        final afterRefresh = (await connections.load('drift-target'))!;
        expect(afterRefresh.bondScore, 45);
        expect(afterRefresh.lastBondDriftAppliedAt, now);
      },
    );
  });

  test(
    'addConnection writes through ConnectionStore and snapshot lands in state',
    () async {
      final connections = InMemoryConnectionStore();
      final container = _container(connectionStore: connections);
      addTearDown(container.dispose);

      // Force AppController to subscribe before the write.
      container.read(appControllerProvider);

      final controller = container.read(appControllerProvider.notifier);
      final saved = await controller.addConnection(
        name: 'Sam Lee',
        email: 'sam@email.com',
        category: 'Work',
        notes: 'Met at demo day',
      );

      // Verify the write hit the store first (write-then-state contract).
      expect(await connections.load(saved.id), isNotNull);

      await _settle();

      final state = container.read(appControllerProvider);
      expect(
        state.connections.map((c) => c.id),
        contains(saved.id),
        reason: 'snapshot listener should pick up the new connection',
      );
    },
  );

  test('addCategory writes through UserDocStore', () async {
    final userDoc = InMemoryUserDocStore();
    final container = _container(userDocStore: userDoc);
    addTearDown(container.dispose);

    container.read(appControllerProvider);

    await container
        .read(appControllerProvider.notifier)
        .addCategory('Workshop');
    await _settle();

    final state = container.read(appControllerProvider);
    expect(state.categories, contains('Workshop'));
  });

  test(
    'mock AI update batches interaction + connection bondScore bump',
    () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      await _seedConnections(connections);

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
      );
      addTearDown(container.dispose);

      container.read(appControllerProvider);
      await _settle();

      final mike = (await connections.load('mike'))!;
      final priorScore = mike.bondScore;

      final memory = await container.read(memoryProvider('mike').future);

      final adapter = container.read(aiUpdateProvider);
      final result = await adapter.run(
        contact: mike,
        userInput: 'Remember to follow up with Mike next week.',
        currentMemory: memory,
        attachments: const [
          AttachmentRef(name: 'note.png', path: '/tmp/note.png'),
        ],
      );
      await adapter.commit(result);
      await _settle();

      final state = container.read(appControllerProvider);
      expect(state.interactions.first.type, InteractionType.reminder);
      expect(state.interactions.first.attachments.first.name, 'note.png');
      expect(state.lastAiSummary, contains('Reminder'));

      // bondScore bumped via the multi-store batch.
      final updatedMike = state.connections.firstWhere((c) => c.id == 'mike');
      // Pass 4.3 PRD §Q6 addendum / #085: MockAiUpdate uses depth=50
      // and the diminishing-returns curve. Mike's seed bond is 68 →
      // floor(50 × 32 / 160) = 10. The post-update score is
      // priorScore + 10, not the legacy +3.
      expect(updatedMike.bondScore, priorScore + 10);
    },
  );

  test('contactInsightFor returns relationship metadata', () async {
    final connections = InMemoryConnectionStore();
    await _seedConnections(connections);

    final container = _container(connectionStore: connections);
    addTearDown(container.dispose);

    container.read(appControllerProvider);
    await _settle();

    final state = container.read(appControllerProvider);
    final insight = state.contactInsightFor('jessica');

    expect(insight.contactId, 'jessica');
    expect(insight.relationshipLabel, 'College');
    expect(insight.knownSinceYears, greaterThanOrEqualTo(1));
  });

  test('user profile updates drive app state', () {
    final container = _container();
    addTearDown(container.dispose);

    container
        .read(appControllerProvider.notifier)
        .updateUser(
          name: 'Jamie Chen',
          email: 'jamie@example.com',
          avatar: '🙂',
          avatarKind: AvatarKind.emoji,
        );

    final user = container.read(appControllerProvider).user;
    expect(user.name, 'Jamie Chen');
    expect(user.email, 'jamie@example.com');
    expect(user.avatar, '🙂');
    expect(user.avatarKind, AvatarKind.emoji);
  });

  test(
    'event CRUD writes through EventStore and surfaces via snapshot',
    () async {
      final events = InMemoryEventStore();
      final container = _container(eventStore: events);
      addTearDown(container.dispose);

      container.read(appControllerProvider);

      final controller = container.read(appControllerProvider.notifier);
      final custom = PlannerEvent(
        id: 'custom-event',
        title: 'Lunch with Sam',
        contactId: 'sarah',
        category: 'Friends',
        date: DateTime(2026, 5, 20),
        note: 'Try ramen place',
        eventType: 'Lunch',
        isAllDay: false,
        startTimeMinutes: 12 * 60,
        endTimeMinutes: 13 * 60,
        isRecurring: true,
        recurrencePattern: RecurrencePattern.monthly,
      );
      await controller.saveEvent(custom);
      await _settle();

      expect(
        container.read(appControllerProvider).events.last.title,
        'Lunch with Sam',
      );

      await controller.saveEvent(
        custom.copyWith(title: 'Lunch with Sarah', eventType: 'Coffee'),
      );
      await _settle();

      final edited = container
          .read(appControllerProvider)
          .events
          .firstWhere((event) => event.id == 'custom-event');
      expect(edited.title, 'Lunch with Sarah');
      expect(edited.eventType, 'Coffee');

      final deleted = await controller.deleteEvent('custom-event');
      expect(deleted?.id, 'custom-event');
      await _settle();

      expect(
        container
            .read(appControllerProvider)
            .events
            .any((event) => event.id == 'custom-event'),
        isFalse,
      );

      await controller.restoreEvent(deleted!);
      await _settle();
      expect(
        container
            .read(appControllerProvider)
            .events
            .any((event) => event.id == 'custom-event'),
        isTrue,
      );
    },
  );

  test(
    'saveEvent normalizes stale optional fields before EventStore save',
    () async {
      final events = InMemoryEventStore();
      final container = _container(eventStore: events);
      addTearDown(container.dispose);

      container.read(appControllerProvider);

      final controller = container.read(appControllerProvider.notifier);
      await controller.saveEvent(
        PlannerEvent(
          id: 'stale-event',
          title: 'All-day reminder',
          category: 'Friends',
          date: DateTime(2026, 6, 2),
          note: 'Stale fields should be cleared',
          isAllDay: true,
          startTimeMinutes: 9 * 60,
          endTimeMinutes: 10 * 60,
          isRecurring: false,
          recurrencePattern: RecurrencePattern.weekly,
        ),
      );
      await _settle();

      final saved = (await events.load('stale-event'))!;
      expect(saved.startTimeMinutes, isNull);
      expect(saved.endTimeMinutes, isNull);
      expect(saved.recurrencePattern, isNull);
    },
  );

  test(
    'restoreEvent normalizes stale optional fields before EventStore save',
    () async {
      final events = InMemoryEventStore();
      final container = _container(eventStore: events);
      addTearDown(container.dispose);

      container.read(appControllerProvider);

      final controller = container.read(appControllerProvider.notifier);
      await controller.restoreEvent(
        PlannerEvent(
          id: 'restored-stale-event',
          title: 'Restored all-day reminder',
          category: 'Friends',
          date: DateTime(2026, 6, 2),
          note: 'Stale fields should be cleared',
          isAllDay: true,
          startTimeMinutes: 9 * 60,
          endTimeMinutes: 10 * 60,
          isRecurring: false,
          recurrencePattern: RecurrencePattern.weekly,
        ),
      );
      await _settle();

      final saved = (await events.load('restored-stale-event'))!;
      expect(saved.startTimeMinutes, isNull);
      expect(saved.endTimeMinutes, isNull);
      expect(saved.recurrencePattern, isNull);
    },
  );

  test(
    'event type management protects defaults and updates custom types',
    () async {
      final container = _container();
      addTearDown(container.dispose);

      container.read(appControllerProvider);

      final controller = container.read(appControllerProvider.notifier);
      await controller.addEventType('Workshop');
      await _settle();
      await controller.renameEventType('Workshop', 'Demo Day');
      await _settle();
      await controller.deleteEventType('Plan'); // protected
      await controller.deleteEventType('Demo Day');
      await _settle();

      final eventTypes = container.read(appControllerProvider).eventTypes;
      expect(eventTypes, contains('Plan'));
      expect(eventTypes, isNot(contains('Workshop')));
      expect(eventTypes, isNot(contains('Demo Day')));
    },
  );

  test('deleteConnection cascades to interactions, events, and memory '
      'via batched write + memory delete', () async {
    final connections = InMemoryConnectionStore();
    final interactions = InMemoryInteractionStore();
    final events = InMemoryEventStore();
    final memory = InMemoryMemoryStore();
    await _seedConnections(connections);
    await _seedInteractions(interactions);
    await _seedEvents(events);
    await memory.save(
      MemoryDocument(
        contactId: 'mike',
        displayName: 'Mike Chen',
        lastUpdated: DateTime.utc(2026, 5, 19),
        summary: 'pre-existing memory',
      ),
    );

    final container = _container(
      connectionStore: connections,
      interactionStore: interactions,
      eventStore: events,
      memoryStore: memory,
    );
    addTearDown(container.dispose);

    container.read(appControllerProvider);
    await _settle();

    await container
        .read(appControllerProvider.notifier)
        .deleteConnection('mike');
    await _settle();

    final state = container.read(appControllerProvider);
    expect(
      state.connections.any((connection) => connection.id == 'mike'),
      isFalse,
    );
    expect(state.events.any((event) => event.contactId == 'mike'), isFalse);
    expect(
      state.interactions.any((interaction) => interaction.contactId == 'mike'),
      isFalse,
    );
    expect(await memory.load('mike'), isNull);
  });

  test('deleteConnection rolls back state when batched write fails', () async {
    final connections = InMemoryConnectionStore();
    final interactions = InMemoryInteractionStore();
    final events = InMemoryEventStore();
    await _seedConnections(connections);
    await _seedInteractions(interactions);
    await _seedEvents(events);

    final batched = InMemoryBatchedWrites(
      connectionStore: connections,
      interactionStore: interactions,
      eventStore: events,
      failOnCommit: true,
    );

    final container = _container(
      connectionStore: connections,
      interactionStore: interactions,
      eventStore: events,
      batchedWrites: batched,
    );
    addTearDown(container.dispose);

    container.read(appControllerProvider);
    await _settle();

    expect(
      () => container
          .read(appControllerProvider.notifier)
          .deleteConnection('mike'),
      throwsA(isA<StateError>()),
    );
    await _settle();

    final state = container.read(appControllerProvider);
    // Mike is still present because the batch threw before any
    // store mutation landed.
    expect(state.connections.any((c) => c.id == 'mike'), isTrue);
  });

  test(
    'removeSampleConnections commits one combined batch across all sample ids',
    () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      final events = InMemoryEventStore();
      await _seedConnections(connections);
      await _seedInteractions(interactions);
      await _seedEvents(events);

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
        eventStore: events,
      );
      addTearDown(container.dispose);

      container.read(appControllerProvider);
      await _settle();

      // Pre-state: every seed connection is sample-flagged.
      final pre = container.read(appControllerProvider);
      final sampleIds = pre.connections
          .where((c) => c.isSample)
          .map((c) => c.id)
          .toSet();
      expect(
        sampleIds,
        isNotEmpty,
        reason: 'seeded connections are all samples',
      );
      final relatedInteractionIds = pre.interactions
          .where((i) => sampleIds.contains(i.contactId))
          .map((i) => i.id)
          .toSet();
      final relatedEventIds = pre.events
          .where((e) => e.contactId != null && sampleIds.contains(e.contactId!))
          .map((e) => e.id)
          .toSet();

      await container
          .read(appControllerProvider.notifier)
          .removeSampleConnections();
      await _settle();

      // Post-state: every sample connection is gone, plus every
      // related interaction and event.
      final state = container.read(appControllerProvider);
      expect(
        state.connections.any((c) => c.isSample),
        isFalse,
        reason: 'all sample connections removed',
      );
      for (final id in sampleIds) {
        expect(await connections.load(id), isNull);
      }
      for (final id in relatedInteractionIds) {
        expect(await interactions.load(id), isNull);
      }
      for (final id in relatedEventIds) {
        expect(await events.load(id), isNull);
      }
    },
  );

  test(
    'removeSampleConnections rolls back state when batched write fails',
    () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      final events = InMemoryEventStore();
      await _seedConnections(connections);
      await _seedInteractions(interactions);
      await _seedEvents(events);

      final batched = InMemoryBatchedWrites(
        connectionStore: connections,
        interactionStore: interactions,
        eventStore: events,
        failOnCommit: true,
      );

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
        eventStore: events,
        batchedWrites: batched,
      );
      addTearDown(container.dispose);

      container.read(appControllerProvider);
      await _settle();
      final preCount = container.read(appControllerProvider).connections.length;

      expect(
        () => container
            .read(appControllerProvider.notifier)
            .removeSampleConnections(),
        throwsA(isA<StateError>()),
      );
      await _settle();

      // Every sample is still in place: the batch threw before any
      // store mutation landed.
      final state = container.read(appControllerProvider);
      expect(state.connections, hasLength(preCount));
      expect(state.connections.where((c) => c.isSample), isNotEmpty);
    },
  );

  test('removeSampleConnections is a no-op when no samples remain', () async {
    final connections = InMemoryConnectionStore();
    final container = _container(connectionStore: connections);
    addTearDown(container.dispose);

    container.read(appControllerProvider);
    await _settle();

    // Empty store — no samples, no throw.
    await container
        .read(appControllerProvider.notifier)
        .removeSampleConnections();
    await _settle();

    expect(container.read(appControllerProvider).connections, isEmpty);
  });

  test('AiUpdate is exposed via aiUpdateProvider', () {
    final container = _container();
    addTearDown(container.dispose);

    final adapter = container.read(aiUpdateProvider);
    expect(adapter, isA<AiUpdate>());
    expect(adapter, isA<MockAiUpdate>());
  });

  group('signOut (Pass 4.5 #070 — Firestore is source of truth)', () {
    test(
      'signOut clears in-memory connections / interactions / events',
      () async {
        final connections = InMemoryConnectionStore();
        final interactions = InMemoryInteractionStore();
        final events = InMemoryEventStore();
        await _seedConnections(connections);
        await _seedInteractions(interactions);
        await _seedEvents(events);

        final container = _container(
          connectionStore: connections,
          interactionStore: interactions,
          eventStore: events,
        );
        addTearDown(container.dispose);

        final controller = container.read(appControllerProvider.notifier);
        await _settle();
        controller.signIn();
        // Sanity: snapshot has populated state from the seeded stores.
        expect(container.read(appControllerProvider).connections, isNotEmpty);

        controller.signOut();

        final state = container.read(appControllerProvider);
        expect(state.isAuthed, isFalse);
        expect(state.selectedTab, 0);
        expect(
          state.connections,
          isEmpty,
          reason:
              'signOut drops in-memory mirror; Firestore is the source of truth',
        );
        expect(state.interactions, isEmpty);
        expect(state.events, isEmpty);
      },
    );

    test('signOut resets categories / eventTypes to defaults', () async {
      final container = _container();
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);
      controller.signIn();
      await controller.addCategory('Mentor');
      await _settle();
      expect(
        container.read(appControllerProvider).categories,
        contains('Mentor'),
      );

      controller.signOut();

      final state = container.read(appControllerProvider);
      expect(
        state.categories,
        equals(UserDocDefaults.categories()),
        reason: 'sign-out resets the in-memory categories list to defaults',
      );
      expect(state.eventTypes, equals(UserDocDefaults.eventTypes()));
    });

    test(
      'after signOut, a re-populated store snapshot rebuilds state on next read',
      () async {
        // The Pass 4.5 contract: sign-out drops the in-memory mirror,
        // and the next sign-in's snapshot listener (running against the
        // new auth UID's store) refills state from Firestore. The
        // headless equivalent is verifying that a save against the
        // active store after sign-out re-emits and is reflected in
        // state.
        final connections = InMemoryConnectionStore();
        final container = _container(connectionStore: connections);
        addTearDown(container.dispose);

        final controller = container.read(appControllerProvider.notifier);
        await _settle();
        controller.signIn();
        controller.signOut();
        expect(container.read(appControllerProvider).connections, isEmpty);

        // Simulate the next sign-in's snapshot landing.
        await connections.save(
          Connection(
            id: 'returning',
            name: 'Returning User',
            email: 'r@example.com',
            category: 'Work',
            avatar: '👤',
            bondScore: 70,
            nextStep: '',
            lastContact: DateTime(2026, 5, 1),
            notes: '',
            knownSince: DateTime(2025, 1, 1),
            preferredChannels: const ['Text'],
          ),
        );
        await _settle();

        expect(
          container.read(appControllerProvider).connections.map((c) => c.id),
          contains('returning'),
        );
      },
    );

    test(
      'firebaseAuth.signOut rebuilds auth-aware stores, cancels old '
      'snapshot listeners, then sign-in replays state from the stores',
      () async {
        final auth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(
            uid: 'test-user',
            email: 'test@example.com',
            isAnonymous: false,
          ),
        );
        final connections = _RecordingConnectionStore();
        final interactions = _RecordingInteractionStore();
        final events = _RecordingEventStore();
        final userDoc = _RecordingUserDocStore();
        await _seedConnections(connections);
        await _seedInteractions(interactions);
        await _seedEvents(events);
        await userDoc.saveCategories(['Team']);
        await userDoc.saveEventTypes(['Retro']);

        final container = ProviderContainer(
          overrides: [
            firebaseAuthProvider.overrideWithValue(auth),
            memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
            connectionStoreProvider.overrideWith((ref) {
              if (ref.watch(currentUserProvider) == null) {
                return const _SignedOutTestConnectionStore();
              }
              return connections;
            }),
            interactionStoreProvider.overrideWith((ref) {
              if (ref.watch(currentUserProvider) == null) {
                return const _SignedOutTestInteractionStore();
              }
              return interactions;
            }),
            eventStoreProvider.overrideWith((ref) {
              if (ref.watch(currentUserProvider) == null) {
                return const _SignedOutTestEventStore();
              }
              return events;
            }),
            userDocStoreProvider.overrideWith((ref) {
              if (ref.watch(currentUserProvider) == null) {
                return const _SignedOutTestUserDocStore();
              }
              return userDoc;
            }),
            batchedWritesProvider.overrideWithValue(
              InMemoryBatchedWrites(
                connectionStore: connections,
                interactionStore: interactions,
                eventStore: events,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        container.read(appControllerProvider);
        await _settle();
        expect(connections.activeSnapshotListeners, 1);
        expect(interactions.activeSnapshotListeners, 1);
        expect(events.activeSnapshotListeners, 1);
        expect(userDoc.activeSnapshotListeners, 1);
        expect(container.read(appControllerProvider).connections, isNotEmpty);
        expect(container.read(appControllerProvider).categories, ['Team']);

        await auth.signOut();
        await _settle();

        final signedOutConnectionStore = container.read(
          connectionStoreProvider,
        );
        final signedOutInteractionStore = container.read(
          interactionStoreProvider,
        );
        final signedOutEventStore = container.read(eventStoreProvider);
        final signedOutUserDocStore = container.read(userDocStoreProvider);
        await expectLater(
          signedOutConnectionStore.load('mike'),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          signedOutInteractionStore.load('seed'),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          signedOutEventStore.load('seed'),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          signedOutUserDocStore.saveCategories(['Nope']),
          throwsA(isA<StateError>()),
        );
        expect(connections.activeSnapshotListeners, 0);
        expect(interactions.activeSnapshotListeners, 0);
        expect(events.activeSnapshotListeners, 0);
        expect(userDoc.activeSnapshotListeners, 0);

        await connections.save(
          Connection(
            id: 'after-signout',
            name: 'After Signout',
            email: 'after@example.com',
            category: 'Work',
            avatar: '👤',
            bondScore: 50,
            nextStep: '',
            lastContact: DateTime.utc(2026, 6, 2),
            notes: '',
            knownSince: DateTime.utc(2026, 1, 1),
            preferredChannels: const ['Text'],
          ),
        );
        await _settle();
        expect(
          container.read(appControllerProvider).connections.map((c) => c.id),
          isNot(contains('after-signout')),
          reason: 'old connection snapshot subscription must be cancelled',
        );

        auth.mockUser = MockUser(
          uid: 'test-user',
          email: 'test@example.com',
          isAnonymous: false,
        );
        await auth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password',
        );
        container.read(appControllerProvider);
        await _settle();

        expect(connections.activeSnapshotListeners, 1);
        expect(interactions.activeSnapshotListeners, 1);
        expect(events.activeSnapshotListeners, 1);
        expect(userDoc.activeSnapshotListeners, 1);
        expect(
          container.read(appControllerProvider).connections.map((c) => c.id),
          contains('after-signout'),
          reason: 'new sign-in listener should replay the store mirror',
        );
        expect(container.read(appControllerProvider).categories, ['Team']);
      },
    );

    test('flips isAuthed to false and resets selectedTab to 0', () {
      final container = _container();
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);
      controller.signIn();
      controller.setTab(3);
      expect(container.read(appControllerProvider).isAuthed, isTrue);
      expect(container.read(appControllerProvider).selectedTab, 3);

      controller.signOut();

      final state = container.read(appControllerProvider);
      expect(state.isAuthed, isFalse);
      expect(state.selectedTab, 0);
    });

    test('sign-out hotfix is removed: user-added connection does not survive '
        'in memory (Firestore now owns persistence)', () async {
      final connections = InMemoryConnectionStore();
      await _seedConnections(connections);

      final container = _container(connectionStore: connections);
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);
      await _settle();
      controller.signIn();
      final saved = await controller.addConnection(
        name: 'Riley Park',
        email: 'riley@example.com',
        category: 'Work',
        notes: 'Met at conference',
      );
      await _settle();
      expect(
        container
            .read(appControllerProvider)
            .connections
            .any((c) => c.id == saved.id),
        isTrue,
      );

      controller.signOut();

      // After signOut, the in-memory list is cleared. The durable
      // record lives in the connection store (which simulates the
      // Firestore source of truth); on the next sign-in it would be
      // restored via the snapshot listener.
      expect(container.read(appControllerProvider).connections, isEmpty);
      // The store-level write survived (this is what the
      // pre-Pass-4.5 hotfix achieved at the in-memory layer).
      expect(await connections.load(saved.id), isNotNull);
    });
  });

  test(
    'snapshot-listener-driven state update after a remote-equivalent write',
    () async {
      final connections = InMemoryConnectionStore();
      final container = _container(connectionStore: connections);
      addTearDown(container.dispose);

      container.read(appControllerProvider);
      await _settle();

      // Simulate a write coming in from another device's instance by
      // saving directly through the store (bypassing AppController).
      // The snapshot listener inside AppController should pick it up.
      final remote = Connection(
        id: 'remote',
        name: 'Remote User',
        email: 'remote@example.com',
        category: 'Work',
        avatar: '👤',
        bondScore: 60,
        nextStep: '',
        lastContact: DateTime(2026, 5, 26),
        notes: '',
        knownSince: DateTime(2024, 1, 1),
        preferredChannels: const ['Text'],
      );
      await connections.save(remote);
      await _settle();

      expect(
        container.read(appControllerProvider).connections.map((c) => c.id),
        contains('remote'),
      );
    },
  );

  test(
    'applyAiUpdateResult rolls back state when batched write fails',
    () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      final events = InMemoryEventStore();
      await _seedConnections(connections);
      await _seedInteractions(interactions);
      await _seedEvents(events);

      final batched = InMemoryBatchedWrites(
        connectionStore: connections,
        interactionStore: interactions,
        eventStore: events,
        failOnCommit: true,
      );

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
        eventStore: events,
        batchedWrites: batched,
      );
      addTearDown(container.dispose);

      container.read(appControllerProvider);
      await _settle();

      final mike = (await connections.load('mike'))!;
      final priorScore = mike.bondScore;
      final priorInteractionCount = container
          .read(appControllerProvider)
          .interactions
          .length;

      final result = AiUpdateResult(
        summary: 'should fail',
        contactId: 'mike',
        interactions: [
          CrmInteraction(
            id: 'i-test',
            contactId: 'mike',
            type: InteractionType.reminder,
            title: 'Test',
            note: 'Test',
            date: DateTime(2026, 5, 26),
            source: InteractionSource.aiSuggested,
          ),
        ],
        nextStep: 'Follow up',
      );

      await expectLater(
        container
            .read(appControllerProvider.notifier)
            .applyAiUpdateResult(result),
        throwsA(isA<StateError>()),
      );
      await _settle();

      // Connection bondScore unchanged; interaction not added.
      final state = container.read(appControllerProvider);
      expect(
        state.connections.firstWhere((c) => c.id == 'mike').bondScore,
        priorScore,
      );
      expect(state.interactions.length, priorInteractionCount);
    },
  );

  group('applyAiUpdateResult — PRD §Q6 addendum / #085 curve wiring', () {
    test('bondScoreDelta=0 leaves bondScore unchanged', () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      await _seedConnections(connections);

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      final mike = (await connections.load('mike'))!;
      final priorScore = mike.bondScore;

      // Construct an AiUpdateResult with bondScoreDelta=0 directly.
      // Models the LLM judging interactionDepth=0 ("trivial") at any
      // bond — score should not move.
      final result = AiUpdateResult(
        summary: 'No-op',
        contactId: 'mike',
        interactions: [
          CrmInteraction(
            id: 'noop-test',
            contactId: 'mike',
            type: InteractionType.interaction,
            title: 'Brief check-in',
            note: 'Hi',
            date: DateTime(2026, 6, 1),
            source: InteractionSource.aiSuggested,
          ),
        ],
      );

      await container
          .read(appControllerProvider.notifier)
          .applyAiUpdateResult(result);
      await _settle();

      final updatedMike = container
          .read(appControllerProvider)
          .connections
          .firstWhere((c) => c.id == 'mike');
      expect(updatedMike.bondScore, priorScore);
    });

    test('bondScoreDelta=10 increases bondScore by exactly 10', () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      await _seedConnections(connections);

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      final mike = (await connections.load('mike'))!;
      final priorScore = mike.bondScore;

      final result = AiUpdateResult(
        summary: 'Curve-driven',
        contactId: 'mike',
        interactions: [
          CrmInteraction(
            id: 'delta10-test',
            contactId: 'mike',
            type: InteractionType.interaction,
            title: 'Substantive',
            note: 'A real conversation.',
            date: DateTime(2026, 6, 1),
            source: InteractionSource.aiSuggested,
          ),
        ],
        bondScoreDelta: 10,
      );

      await container
          .read(appControllerProvider.notifier)
          .applyAiUpdateResult(result);
      await _settle();

      final updatedMike = container
          .read(appControllerProvider)
          .connections
          .firstWhere((c) => c.id == 'mike');
      expect(updatedMike.bondScore, priorScore + 10);
    });

    test('large delta clamps to 100 (never exceeds the upper bound)', () async {
      // Defensive: the AppController-side clamp must hold even when
      // the curve plus current bond would naturally exceed 100. The
      // curve helper alone cannot guarantee the post-add bound.
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      await _seedConnections(connections);

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      // David seeds at 95 in AppState.seeded(). Picking a delta of
      // 20 → 95 + 20 = 115, which must clamp to 100.
      final david = (await connections.load('david'))!;
      expect(david.bondScore, 95);

      final result = AiUpdateResult(
        summary: 'Big delta',
        contactId: 'david',
        interactions: [
          CrmInteraction(
            id: 'clamp-test',
            contactId: 'david',
            type: InteractionType.interaction,
            title: 'Major moment',
            note: 'David just got engaged.',
            date: DateTime(2026, 6, 1),
            source: InteractionSource.aiSuggested,
          ),
        ],
        bondScoreDelta: 20,
      );

      await container
          .read(appControllerProvider.notifier)
          .applyAiUpdateResult(result);
      await _settle();

      final updatedDavid = container
          .read(appControllerProvider)
          .connections
          .firstWhere((c) => c.id == 'david');
      expect(updatedDavid.bondScore, 100);
    });

    test(
      '#117: applyAiUpdateResult sets lastAiUpdatedContactId and '
      'lastAiUpdatedAt synchronously',
      () async {
        final connections = InMemoryConnectionStore();
        final interactions = InMemoryInteractionStore();
        await _seedConnections(connections);

        final container = _container(
          connectionStore: connections,
          interactionStore: interactions,
        );
        addTearDown(container.dispose);
        container.read(appControllerProvider);
        await _settle();

        final result = AiUpdateResult(
          summary: 'Signal test',
          contactId: 'emily',
          interactions: [
            CrmInteraction(
              id: 'signal-test',
              contactId: 'emily',
              type: InteractionType.interaction,
              title: 'AI Update',
              note: 'Signal lifecycle test.',
              date: DateTime(2026, 6, 15),
              source: InteractionSource.aiSuggested,
            ),
          ],
        );

        final before = DateTime.now();
        await container
            .read(appControllerProvider.notifier)
            .applyAiUpdateResult(result);
        await _settle();
        final after = DateTime.now();

        final state = container.read(appControllerProvider);
        expect(state.lastAiUpdatedContactId, 'emily');
        expect(
          state.lastAiUpdatedAt,
          isNotNull,
        );
        final at = state.lastAiUpdatedAt!;
        // Allow ±1 second tolerance for test execution timing.
        expect(
          at.isAfter(before.subtract(const Duration(seconds: 1))) &&
              at.isBefore(after.add(const Duration(seconds: 1))),
          isTrue,
          reason: 'lastAiUpdatedAt should be close to wall-clock time of apply',
        );
      },
    );

    test('#117: clearLastAiUpdate clears both fields to null', () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      await _seedConnections(connections);

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      final result = AiUpdateResult(
        summary: 'Clear test',
        contactId: 'emily',
        interactions: [
          CrmInteraction(
            id: 'clear-test',
            contactId: 'emily',
            type: InteractionType.interaction,
            title: 'AI Update',
            note: 'Clear lifecycle test.',
            date: DateTime(2026, 6, 15),
            source: InteractionSource.aiSuggested,
          ),
        ],
      );

      await container
          .read(appControllerProvider.notifier)
          .applyAiUpdateResult(result);
      await _settle();

      // Verify fields are set
      expect(container.read(appControllerProvider).lastAiUpdatedContactId,
          isNotNull);
      expect(
          container.read(appControllerProvider).lastAiUpdatedAt, isNotNull);

      // Clear the signal
      container.read(appControllerProvider.notifier).clearLastAiUpdate();
      await _settle();

      // Verify fields are cleared
      final state = container.read(appControllerProvider);
      expect(state.lastAiUpdatedContactId, isNull);
      expect(state.lastAiUpdatedAt, isNull);
    });
  });

  group('deleteInteraction', () {
    test('deletes the interaction through the store', () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      await _seedConnections(connections);
      await _seedInteractions(interactions);

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      // Verify i1 exists before deletion
      final before = await interactions.load('i1');
      expect(before, isNotNull);

      await container
          .read(appControllerProvider.notifier)
          .deleteInteraction('i1');
      await _settle();

      // Verify it's gone from the store
      final after = await interactions.load('i1');
      expect(after, isNull);
    });

    test('recalculates lastContact from remaining interactions', () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      await _seedConnections(connections);
      await _seedInteractions(interactions);

      // Add a second interaction for sarah (she has only i1 at 2026-04-20)
      final laterInteraction = CrmInteraction(
        id: 'sarah-late',
        contactId: 'sarah',
        type: InteractionType.reminder,
        title: 'Later check-in',
        note: '',
        date: DateTime(2026, 5, 15),
      );
      await interactions.save(laterInteraction);

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      // Delete the older interaction (i1, 2026-04-20)
      await container
          .read(appControllerProvider.notifier)
          .deleteInteraction('i1');
      await _settle();

      // lastContact should now be the remaining interaction's date (2026-05-15)
      final updatedSarah = (await connections.load('sarah'))!;
      expect(updatedSarah.lastContact, DateTime(2026, 5, 15));
    });

    test('subtracts bondScoreDelta from bondScore', () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      final now = DateTime(2026, 6, 15);

      // Use a dedicated connection with no drift risk (recent lastContact)
      await connections.save(
        Connection(
          id: 'delta-target',
          name: 'Delta Target',
          email: 'delta@example.com',
          category: 'Friends',
          avatar: '😊',
          bondScore: 50,
          nextStep: '',
          lastContact: now.subtract(const Duration(days: 2)),
          notes: '',
          knownSince: DateTime(2025, 1, 1),
          preferredChannels: const ['Text'],
        ),
      );
      await interactions.save(
        CrmInteraction(
          id: 'delta-test',
          contactId: 'delta-target',
          type: InteractionType.relationshipNote,
          title: 'Bond booster',
          note: '',
          date: now.subtract(const Duration(days: 2)),
          bondScoreDelta: 10,
          source: InteractionSource.aiSuggested,
        ),
      );

      // Manually bump the connection bondScore to reflect the delta
      final connection = (await connections.load('delta-target'))!;
      await connections.save(
        connection.copyWith(bondScore: connection.bondScore + 10),
      );

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
        clock: () => now,
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      // Verify bondScore was bumped to 60 before deletion (50 + 10)
      final before = (await connections.load('delta-target'))!;
      expect(before.bondScore, 60);

      // Delete the delta interaction
      await container
          .read(appControllerProvider.notifier)
          .deleteInteraction('delta-test');
      await _settle();

      // bondScore should drop by 10 (the delta), clamped to [0,100]
      final updated = (await connections.load('delta-target'))!;
      expect(updated.bondScore, 50);
    });

    test('falls back to connection lastContact when no interactions remain', () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      final now = DateTime(2026, 6, 15);

      // Create a connection with a single interaction
      await connections.save(
        Connection(
          id: 'single',
          name: 'Single Contact',
          email: 'single@example.com',
          category: 'Friends',
          avatar: '😊',
          bondScore: 50,
          nextStep: '',
          lastContact: DateTime(2026, 1, 15),
          notes: '',
          knownSince: DateTime(2025, 1, 1),
          preferredChannels: const ['Text'],
        ),
      );
      await interactions.save(
        CrmInteraction(
          id: 'only-interaction',
          contactId: 'single',
          type: InteractionType.reminder,
          title: 'The only one',
          note: '',
          date: DateTime(2026, 6, 10),
        ),
      );

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
        clock: () => now,
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      // Delete the only interaction
      await container
          .read(appControllerProvider.notifier)
          .deleteInteraction('only-interaction');
      await _settle();

      // lastContact should remain at the connection's original value
      final updated = (await connections.load('single'))!;
      expect(updated.lastContact, DateTime(2026, 1, 15));
    });

    test('bondScoreDelta=0 leaves bondScore unchanged', () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      final now = DateTime(2026, 6, 15);

      await connections.save(
        Connection(
          id: 'zero-delta',
          name: 'Zero Delta',
          email: 'zero@example.com',
          category: 'Friends',
          avatar: '😊',
          bondScore: 42,
          nextStep: '',
          lastContact: now.subtract(const Duration(days: 1)),
          notes: '',
          knownSince: DateTime(2025, 1, 1),
          preferredChannels: const ['Text'],
        ),
      );
      await interactions.save(
        CrmInteraction(
          id: 'zero-test',
          contactId: 'zero-delta',
          type: InteractionType.reminder,
          title: 'No delta',
          note: '',
          date: now.subtract(const Duration(days: 1)),
          bondScoreDelta: 0,
        ),
      );

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
        clock: () => now,
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      await container
          .read(appControllerProvider.notifier)
          .deleteInteraction('zero-test');
      await _settle();

      final updated = (await connections.load('zero-delta'))!;
      expect(updated.bondScore, 42);
    });

    test('throws StateError when interaction not found', () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      await _seedConnections(connections);
      await _seedInteractions(interactions);

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      await expectLater(
        container
            .read(appControllerProvider.notifier)
            .deleteInteraction('nonexistent'),
        throwsA(isA<StateError>()),
      );
    });

    test('clamps bondScore to 0 when delta exceeds current score', () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      final now = DateTime(2026, 6, 15);

      await connections.save(Connection(
        id: 'clamp-test',
        name: 'Clamp',
        email: 'clamp@example.com',
        category: 'Friends',
        avatar: '🧲',
        bondScore: 5, // Low score
        nextStep: 'Reach out',
        lastContact: DateTime(2026, 5, 1),
        notes: '',
        knownSince: DateTime(2020),
        preferredChannels: const ['Text'],
      ));

      await interactions.save(CrmInteraction(
        id: 'big-delta',
        contactId: 'clamp-test',
        type: InteractionType.interaction,
        title: 'Big boost',
        note: 'Huge delta',
        date: DateTime(2026, 6, 10),
        bondScoreDelta: 10, // Delta exceeds current score
      ));

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
        clock: () => now,
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      await container
          .read(appControllerProvider.notifier)
          .deleteInteraction('big-delta');
      await _settle();

      final updated = (await connections.load('clamp-test'))!;
      expect(updated.bondScore, 0); // Clamped from 5 - 10 = -5 → 0
    });

    test('after delete, memory is rebuilt via FakeMemoryRebuilder', () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      final memory = InMemoryMemoryStore();
      await _seedConnections(connections);
      await _seedInteractions(interactions);

      // Pre-seed a memory document for sarah
      await memory.save(MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah',
        lastUpdated: DateTime(2026, 5, 1),
        summary: 'Original summary',
        history: 'Original history',
      ));

      final fakeRebuilder = FakeMemoryRebuilder();

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
        memoryStore: memory,
        overrides: [
          memoryRebuilderProvider.overrideWithValue(fakeRebuilder),
        ],
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      expect(fakeRebuilder.rebuildCallCount, 0);

      await container
          .read(appControllerProvider.notifier)
          .deleteInteraction('i1');
      await _settle();

      // FakeMemoryRebuilder should have been called once
      expect(fakeRebuilder.rebuildCallCount, 1);

      // Memory document should have been updated
      final updatedMemory = await memory.load('sarah');
      expect(updatedMemory, isNotNull);
      expect(updatedMemory!.summary, contains('Sarah'));
    });

    test('after delete, nextStep is updated from rebuild result', () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      final memory = InMemoryMemoryStore();
      await _seedConnections(connections);
      await _seedInteractions(interactions);

      await memory.save(MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah',
        lastUpdated: DateTime(2026, 5, 1),
      ));

      final fakeRebuilder = FakeMemoryRebuilder();

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
        memoryStore: memory,
        overrides: [
          memoryRebuilderProvider.overrideWithValue(fakeRebuilder),
        ],
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      await container
          .read(appControllerProvider.notifier)
          .deleteInteraction('i1');
      await _settle();

      final updatedSarah = (await connections.load('sarah'))!;
      expect(updatedSarah.nextStep, equals('Check in with Sarah Johnson'));
    });

    test('after delete, memoryEpochProvider is bumped', () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      final memory = InMemoryMemoryStore();
      await _seedConnections(connections);
      await _seedInteractions(interactions);

      await memory.save(MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah',
        lastUpdated: DateTime(2026, 5, 1),
      ));

      final fakeRebuilder = FakeMemoryRebuilder();

      final now = DateTime(2026, 6, 15);

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
        memoryStore: memory,
        clock: () => now,
        overrides: [
          memoryRebuilderProvider.overrideWithValue(fakeRebuilder),
        ],
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      // Capture epoch before delete
      final epochBefore = container.read(memoryEpochProvider);

      await container
          .read(appControllerProvider.notifier)
          .deleteInteraction('i1');
      await _settle();

      final epochAfter = container.read(memoryEpochProvider);
      expect(epochAfter, isNotNull);
      expect(epochAfter, epochBefore == null ? isNotNull : greaterThan(epochBefore!));
    });

    test('after delete, recommendationsCacheProvider cache is cleared',
        () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      final memory = InMemoryMemoryStore();
      await _seedConnections(connections);
      await _seedInteractions(interactions);

      await memory.save(MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah',
        lastUpdated: DateTime(2026, 5, 1),
      ));

      final fakeRebuilder = FakeMemoryRebuilder();

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
        memoryStore: memory,
        overrides: [
          memoryRebuilderProvider.overrideWithValue(fakeRebuilder),
        ],
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      // Set a cache so we can verify it's cleared
      final cacheHolder = container.read(recommendationsCacheProvider);
      cacheHolder.cache = RecommendationsCache(
        computedAt: DateTime(2026, 6, 1),
        list: const [],
        store: memory,
        connections: container.read(appControllerProvider).connections,
        interactions: container.read(appControllerProvider).interactions,
      );
      expect(cacheHolder.cache, isNotNull);

      await container
          .read(appControllerProvider.notifier)
          .deleteInteraction('i1');
      await _settle();

      expect(cacheHolder.cache, isNull);
    });

    test('if memory rebuild fails, interaction is still deleted (non-fatal)',
        () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      final memory = InMemoryMemoryStore();
      await _seedConnections(connections);
      await _seedInteractions(interactions);

      // Don't pre-seed a memory document — memoryStore.load returns
      // null, so the rebuild branch is skipped entirely. This tests
      // the non-fatal path where memory rebuild is skipped/absent.

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
        memoryStore: memory,
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      // Verify the interaction exists before deletion
      final before = await interactions.load('i1');
      expect(before, isNotNull);

      await container
          .read(appControllerProvider.notifier)
          .deleteInteraction('i1');
      await _settle();

      // Interaction should still be deleted even without memory rebuild
      final after = await interactions.load('i1');
      expect(after, isNull);
    });

    test('if memory rebuild throws, interaction and connection are still updated',
        () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      final memory = InMemoryMemoryStore();
      await _seedConnections(connections);

      // Create an interaction with a non-zero bondScoreDelta so we can
      // verify the connection score was recalculated even when rebuild fails.
      await interactions.save(CrmInteraction(
        id: 'delta-interaction',
        contactId: 'mike',
        type: InteractionType.interaction,
        title: 'Big boost',
        note: 'Huge delta',
        date: DateTime(2026, 6, 10),
        bondScoreDelta: 10,
      ));

      // Pre-seed a memory document so the rebuild branch is entered
      await memory.save(MemoryDocument.empty(
        contactId: 'mike',
        displayName: 'Mike',
        now: DateTime(2026),
      ));

      // Use a throwing rebuilder
      final throwingRebuilder = _ThrowingMemoryRebuilder();
      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
        memoryStore: memory,
        memoryRebuilder: throwingRebuilder,
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      final mikeBefore = (await connections.load('mike'))!;

      await container
          .read(appControllerProvider.notifier)
          .deleteInteraction('delta-interaction');
      await _settle();

      // Interaction is still deleted
      expect(await interactions.load('delta-interaction'), isNull);

      // Connection is still updated (bondScore recalculated downward)
      final mikeAfter = (await connections.load('mike'))!;
      expect(mikeAfter.bondScore, lessThan(mikeBefore.bondScore));
    });

    test('sets pendingMemoryRebuildProvider during rebuild and clears after',
        () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      final memory = InMemoryMemoryStore();
      await _seedConnections(connections);
      await _seedInteractions(interactions);

      await memory.save(MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah',
        lastUpdated: DateTime(2026, 5, 1),
      ));

      final rebuildCompleter = Completer<MemoryRebuildResult>();
      final delayingRebuilder = _DelayingMemoryRebuilder(rebuildCompleter.future);

      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
        memoryStore: memory,
        overrides: [
          memoryRebuilderProvider.overrideWithValue(delayingRebuilder),
        ],
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      // Start deleteInteraction but don't await — it will pause at the rebuild
      final deleteFuture =
          container.read(appControllerProvider.notifier).deleteInteraction('i1');

      // Pump several times to let the method reach the rebuild step
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      // The provider should be set to 'sarah' during the rebuild
      expect(
        container.read(pendingMemoryRebuildProvider),
        equals('sarah'),
      );

      // Complete the rebuild
      rebuildCompleter.complete(MemoryRebuildResult(
        memoryDocument: MemoryDocument(
          contactId: 'sarah',
          displayName: 'Sarah',
          lastUpdated: DateTime(2026, 6, 15),
          summary: 'Rebuilt memory for Sarah',
        ),
        nextStep: 'Check in with Sarah',
      ));

      await deleteFuture;
      await _settle();

      // After the method completes, the provider should be cleared
      expect(container.read(pendingMemoryRebuildProvider), isNull);
    });

    test('clears pendingMemoryRebuildProvider when rebuild fails', () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      final memory = InMemoryMemoryStore();
      await _seedConnections(connections);

      await interactions.save(CrmInteraction(
        id: 'delta-interaction',
        contactId: 'mike',
        type: InteractionType.interaction,
        title: 'Big boost',
        note: 'Huge delta',
        date: DateTime(2026, 6, 10),
        bondScoreDelta: 10,
      ));

      await memory.save(MemoryDocument.empty(
        contactId: 'mike',
        displayName: 'Mike',
        now: DateTime(2026),
      ));

      final throwingRebuilder = _ThrowingMemoryRebuilder();
      final container = _container(
        connectionStore: connections,
        interactionStore: interactions,
        memoryStore: memory,
        memoryRebuilder: throwingRebuilder,
      );
      addTearDown(container.dispose);
      container.read(appControllerProvider);
      await _settle();

      await container
          .read(appControllerProvider.notifier)
          .deleteInteraction('delta-interaction');
      await _settle();

      // Provider should be null even though rebuild threw
      expect(container.read(pendingMemoryRebuildProvider), isNull);
    });
  });
}

/// A [MemoryRebuilder] that completes from a [Future], used to test
/// intermediate state during the rebuild.
class _DelayingMemoryRebuilder implements MemoryRebuilder {
  _DelayingMemoryRebuilder(this.future);
  final Future<MemoryRebuildResult> future;

  @override
  Future<MemoryRebuildResult> rebuild({
    required Connection contact,
    required MemoryDocument currentMemory,
    required List<CrmInteraction> remainingInteractions,
    required CrmInteraction deletedInteraction,
  }) {
    return future;
  }
}

/// A [MemoryRebuilder] that always throws, used to test the non-fatal
/// error path where the rebuild fails but the interaction is still deleted.
class _ThrowingMemoryRebuilder implements MemoryRebuilder {
  @override
  Future<MemoryRebuildResult> rebuild({
    required Connection contact,
    required MemoryDocument currentMemory,
    required List<CrmInteraction> remainingInteractions,
    required CrmInteraction deletedInteraction,
  }) {
    throw Exception('Rebuild failed — simulated network error');
  }
}
