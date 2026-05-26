import 'package:connect_me/src/ai/ai_update.dart';
import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/app_state.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container({InMemoryMemoryStore? store}) {
  final memoryStore = store ?? InMemoryMemoryStore();
  return ProviderContainer(overrides: [
    memoryStoreProvider.overrideWithValue(memoryStore),
  ]);
}

void main() {
  test('connection and category mutations update session state', () {
    final container = _container();
    addTearDown(container.dispose);

    final controller = container.read(appControllerProvider.notifier);
    controller.addConnection(
      name: 'Sam Lee',
      email: 'sam@email.com',
      category: 'Work',
      notes: 'Met at demo day',
    );
    controller.addCategory('Workshop');

    final state = container.read(appControllerProvider);
    expect(state.connections.first.name, 'Sam Lee');
    expect(state.connections.first.email, 'sam@email.com');
    expect(state.categories, contains('Workshop'));
  });

  test('mock AI update adds categorized interaction', () async {
    final container = _container();
    addTearDown(container.dispose);

    final before = container.read(appControllerProvider).interactions.length;
    final mike = container
        .read(appControllerProvider)
        .connections
        .firstWhere((c) => c.id == 'mike');
    final memory = await container.read(memoryProvider('mike').future);

    final adapter = container.read(aiUpdateProvider);
    final result = await adapter.run(
      contact: mike,
      userInput: 'Remember to follow up with Mike next week.',
      currentMemory: memory,
      attachments: const [AttachmentRef(name: 'note.png', path: '/tmp/note.png')],
    );
    await adapter.commit(result);

    final state = container.read(appControllerProvider);
    expect(state.interactions.length, before + 1);
    expect(state.interactions.first.type, InteractionType.reminder);
    expect(state.interactions.first.attachments.first.name, 'note.png');
    expect(state.lastAiSummary, contains('Reminder'));
  });

  test('contactInsightFor returns relationship metadata', () {
    final container = _container();
    addTearDown(container.dispose);

    final state = container.read(appControllerProvider);
    final insight = state.contactInsightFor('jessica');

    // #050 trimmed ContactInsight to (contactId, relationshipLabel,
    // knownSinceYears). Person Summary now reads MemoryDocument.summary
    // via memoryProvider; "why now" copy comes from
    // RecommendationEngine output. The deleted assertions on summary,
    // why, recommendedAction, potentialScoreGain, preferredChannels,
    // and frequencyByMonth covered widgets that were already removed
    // by Pass 2 (RecommendedActionCard, CommunicationChannelsCard,
    // InteractionFrequencyCard).
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

  test('event CRUD supports edit, delete, and restore', () {
    final container = _container();
    addTearDown(container.dispose);

    final controller = container.read(appControllerProvider.notifier);
    controller.saveEvent(
      PlannerEvent(
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
      ),
    );

    expect(
      container.read(appControllerProvider).events.last.title,
      'Lunch with Sam',
    );

    controller.saveEvent(
      container
          .read(appControllerProvider)
          .events
          .last
          .copyWith(title: 'Lunch with Sarah', eventType: 'Coffee'),
    );

    final edited = container
        .read(appControllerProvider)
        .events
        .firstWhere((event) => event.id == 'custom-event');
    expect(edited.title, 'Lunch with Sarah');
    expect(edited.eventType, 'Coffee');

    final deleted = controller.deleteEvent('custom-event');
    expect(deleted?.id, 'custom-event');
    expect(
      container
          .read(appControllerProvider)
          .events
          .any((event) => event.id == 'custom-event'),
      isFalse,
    );

    controller.restoreEvent(deleted!);
    expect(
      container
          .read(appControllerProvider)
          .events
          .any((event) => event.id == 'custom-event'),
      isTrue,
    );
  });

  test('event type management protects defaults and updates custom types', () {
    final container = _container();
    addTearDown(container.dispose);

    final controller = container.read(appControllerProvider.notifier);
    controller.addEventType('Workshop');
    controller.renameEventType('Workshop', 'Demo Day');
    controller.deleteEventType('Plan');
    controller.deleteEventType('Demo Day');

    final eventTypes = container.read(appControllerProvider).eventTypes;
    expect(eventTypes, contains('Plan'));
    expect(eventTypes, isNot(contains('Workshop')));
    expect(eventTypes, isNot(contains('Demo Day')));
  });

  test('deleting connection removes related events and interactions', () async {
    final store = InMemoryMemoryStore();
    // Pre-populate the store so the cascade has something to delete.
    await store.save(MemoryDocument(
      contactId: 'mike',
      displayName: 'Mike Chen',
      lastUpdated: DateTime.utc(2026, 5, 19),
      summary: 'pre-existing memory',
    ));

    final container = _container(store: store);
    addTearDown(container.dispose);

    container.read(appControllerProvider.notifier).deleteConnection('mike');

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

    // Cascade (PRD Q3): the memory file is removed alongside the
    // connection. The cascade is fire-and-forget for this slice; pump
    // the event loop so the async delete lands before the assertion.
    await Future<void>.delayed(Duration.zero);
    expect(await store.load('mike'), isNull);
  });

  test('AiUpdate is exposed via aiUpdateProvider', () {
    final container = _container();
    addTearDown(container.dispose);

    final adapter = container.read(aiUpdateProvider);
    expect(adapter, isA<AiUpdate>());
    expect(adapter, isA<MockAiUpdate>());
  });

  group('signOut preserves user data (hotfix)', () {
    test('preserves user-added connection across sign-out', () {
      final container = _container();
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);
      controller.signIn();
      controller.addConnection(
        name: 'Riley Park',
        email: 'riley@example.com',
        category: 'Work',
        notes: 'Met at conference',
      );
      final addedId = container
          .read(appControllerProvider)
          .connections
          .firstWhere((c) => c.name == 'Riley Park')
          .id;

      controller.signOut();

      final state = container.read(appControllerProvider);
      expect(
        state.connections.any((c) => c.id == addedId),
        isTrue,
        reason: 'user-added connection must survive sign-out',
      );
    });

    test('drops sample connections on sign-out', () {
      final container = _container();
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);
      controller.signIn();
      controller.signOut();

      final state = container.read(appControllerProvider);
      expect(
        state.connections.where((c) => c.isSample),
        isEmpty,
        reason: 'sample seeded connections should be cleared on sign-out',
      );
    });

    test('drops events and interactions tied to sample contacts', () {
      final container = _container();
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);
      final sampleIds = container
          .read(appControllerProvider)
          .connections
          .where((c) => c.isSample)
          .map((c) => c.id)
          .toSet();

      controller.signIn();
      controller.signOut();

      final state = container.read(appControllerProvider);
      expect(
        state.events.any((e) => sampleIds.contains(e.contactId)),
        isFalse,
        reason: 'events for sample contacts must be dropped',
      );
      expect(
        state.interactions.any((i) => sampleIds.contains(i.contactId)),
        isFalse,
        reason: 'interactions for sample contacts must be dropped',
      );
    });

    test('preserves events and interactions tied to user-added connection',
        () {
      final container = _container();
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);
      controller.signIn();
      controller.addConnection(
        name: 'Taylor Reed',
        email: 'taylor@example.com',
        category: 'Friends',
        notes: '',
      );
      final addedId = container
          .read(appControllerProvider)
          .connections
          .firstWhere((c) => c.name == 'Taylor Reed')
          .id;

      controller.logInteraction(
        addedId,
        InteractionType.relationshipNote,
        'Coffee',
        'Caught up over coffee',
      );
      controller.addEvent(
        'Lunch with Taylor',
        addedId,
        'Friends',
        DateTime(2026, 6, 1),
        'Try the new place',
      );

      controller.signOut();

      final state = container.read(appControllerProvider);
      expect(
        state.interactions.any((i) => i.contactId == addedId),
        isTrue,
        reason: 'user interaction tied to kept connection must survive',
      );
      expect(
        state.events.any((e) => e.contactId == addedId),
        isTrue,
        reason: 'user event tied to kept connection must survive',
      );
    });

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
  });
}
