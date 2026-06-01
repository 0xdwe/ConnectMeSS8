import 'package:connect_me/src/ai/ai_update.dart';
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
  bool signedIn = true,
}) {
  final memory = memoryStore ?? InMemoryMemoryStore();
  final connections = connectionStore ?? InMemoryConnectionStore();
  final interactions = interactionStore ?? InMemoryInteractionStore();
  final events = eventStore ?? InMemoryEventStore();
  final userDoc = userDocStore ?? InMemoryUserDocStore();
  final batched = batchedWrites ??
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

  return ProviderContainer(overrides: [
    firebaseAuthProvider.overrideWithValue(mockAuth),
    memoryStoreProvider.overrideWithValue(memory),
    connectionStoreProvider.overrideWithValue(connections),
    interactionStoreProvider.overrideWithValue(interactions),
    eventStoreProvider.overrideWithValue(events),
    userDocStoreProvider.overrideWithValue(userDoc),
    batchedWritesProvider.overrideWithValue(batched),
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
  ]);
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

void main() {
  test('addConnection writes through ConnectionStore and snapshot lands in state',
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
  });

  test('addCategory writes through UserDocStore', () async {
    final userDoc = InMemoryUserDocStore();
    final container = _container(userDocStore: userDoc);
    addTearDown(container.dispose);

    container.read(appControllerProvider);

    await container.read(appControllerProvider.notifier).addCategory('Workshop');
    await _settle();

    final state = container.read(appControllerProvider);
    expect(state.categories, contains('Workshop'));
  });

  test('mock AI update batches interaction + connection bondScore bump',
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

    final mike =
        (await connections.load('mike'))!;
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
  });

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

    container.read(appControllerProvider.notifier).updateUser(
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

  test('event CRUD writes through EventStore and surfaces via snapshot',
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
  });

  test('event type management protects defaults and updates custom types',
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
  });

  test(
    'deleteConnection cascades to interactions, events, and memory '
    'via batched write + memory delete',
    () async {
      final connections = InMemoryConnectionStore();
      final interactions = InMemoryInteractionStore();
      final events = InMemoryEventStore();
      final memory = InMemoryMemoryStore();
      await _seedConnections(connections);
      await _seedInteractions(interactions);
      await _seedEvents(events);
      await memory.save(MemoryDocument(
        contactId: 'mike',
        displayName: 'Mike Chen',
        lastUpdated: DateTime.utc(2026, 5, 19),
        summary: 'pre-existing memory',
      ));

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
        state.interactions
            .any((interaction) => interaction.contactId == 'mike'),
        isFalse,
      );
      expect(await memory.load('mike'), isNull);
    },
  );

  test(
    'deleteConnection rolls back state when batched write fails',
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
    },
  );

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
      expect(sampleIds, isNotEmpty,
          reason: 'seeded connections are all samples');
      final relatedInteractionIds = pre.interactions
          .where((i) => sampleIds.contains(i.contactId))
          .map((i) => i.id)
          .toSet();
      final relatedEventIds = pre.events
          .where((e) =>
              e.contactId != null && sampleIds.contains(e.contactId!))
          .map((e) => e.id)
          .toSet();

      await container
          .read(appControllerProvider.notifier)
          .removeSampleConnections();
      await _settle();

      // Post-state: every sample connection is gone, plus every
      // related interaction and event.
      final state = container.read(appControllerProvider);
      expect(state.connections.any((c) => c.isSample), isFalse,
          reason: 'all sample connections removed');
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
      final preCount =
          container.read(appControllerProvider).connections.length;

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

  test(
    'removeSampleConnections is a no-op when no samples remain',
    () async {
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
    },
  );

  test('AiUpdate is exposed via aiUpdateProvider', () {
    final container = _container();
    addTearDown(container.dispose);

    final adapter = container.read(aiUpdateProvider);
    expect(adapter, isA<AiUpdate>());
    expect(adapter, isA<MockAiUpdate>());
  });

  group('signOut (Pass 4.5 #070 — Firestore is source of truth)', () {
    test('signOut clears in-memory connections / interactions / events',
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
      expect(
        container.read(appControllerProvider).connections,
        isNotEmpty,
      );

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
    });

    test('signOut resets categories / eventTypes to defaults', () async {
      final container = _container();
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);
      controller.signIn();
      await controller.addCategory('Mentor');
      await _settle();
      expect(container.read(appControllerProvider).categories,
          contains('Mentor'));

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
        await connections.save(Connection(
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
        ));
        await _settle();

        expect(
          container
              .read(appControllerProvider)
              .connections
              .map((c) => c.id),
          contains('returning'),
        );
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

    test(
      'sign-out hotfix is removed: user-added connection does not survive '
      'in memory (Firestore now owns persistence)',
      () async {
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
        expect(
          container.read(appControllerProvider).connections,
          isEmpty,
        );
        // The store-level write survived (this is what the
        // pre-Pass-4.5 hotfix achieved at the in-memory layer).
        expect(await connections.load(saved.id), isNotNull);
      },
    );
  });

  test('snapshot-listener-driven state update after a remote-equivalent write',
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
      container
          .read(appControllerProvider)
          .connections
          .map((c) => c.id),
      contains('remote'),
    );
  });

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

      final mike =
          (await connections.load('mike'))!;
      final priorScore = mike.bondScore;
      final priorInteractionCount =
          container.read(appControllerProvider).interactions.length;

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

    test('large delta clamps to 100 (never exceeds the upper bound)',
        () async {
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
  });
}
