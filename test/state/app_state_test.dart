import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('connection and category mutations update session state', () {
    final container = ProviderContainer();
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
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final before = container.read(appControllerProvider).interactions.length;
    await container.read(appControllerProvider.notifier).runAiUpdate(
      'mike',
      'Remember to follow up with Mike next week.',
      const [AttachmentRef(name: 'note.png', path: '/tmp/note.png')],
    );

    final state = container.read(appControllerProvider);
    expect(state.interactions.length, before + 1);
    expect(state.interactions.first.type, InteractionType.reminder);
    expect(state.interactions.first.attachments.first.name, 'note.png');
    expect(state.lastAiSummary, contains('Reminder'));
  });

  test('contactInsightFor returns future-AI-shaped insight data', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(appControllerProvider);
    final insight = state.contactInsightFor('jessica');

    expect(insight.contactId, 'jessica');
    expect(insight.summary, isNotEmpty);
    expect(insight.why, isNotEmpty);
    expect(insight.recommendedAction, isNotEmpty);
    expect(insight.potentialScoreGain, greaterThan(0));
    expect(insight.relationshipLabel, 'College');
    expect(insight.knownSinceYears, greaterThanOrEqualTo(1));
    expect(insight.preferredChannels, contains('FaceTime'));
    expect(insight.frequencyByMonth, hasLength(12));
  });

  test('user profile updates drive app state', () {
    final container = ProviderContainer();
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
    final container = ProviderContainer();
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
    final container = ProviderContainer();
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

  test('shared activity creates interaction and bumps contact momentum', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final before = container.read(appControllerProvider).interactions.length;
    container
        .read(appControllerProvider.notifier)
        .logSharedActivity(
          contactId: 'sarah',
          type: SharedActivityType.note,
          content: 'Walked by the river and talked about summer plans.',
        );

    final state = container.read(appControllerProvider);
    expect(state.interactions.length, before + 1);
    expect(state.interactions.first.contactId, 'sarah');
    expect(state.interactions.first.type, InteractionType.sharedActivity);
    expect(state.interactions.first.note, contains('summer plans'));
  });

  test('deleting connection removes related events and interactions', () {
    final container = ProviderContainer();
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
  });
}
