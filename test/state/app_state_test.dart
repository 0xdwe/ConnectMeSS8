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
}
