import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AI Update Preview-and-Confirm Flow', () {
    test('previewAiUpdate returns AiUpdateResult without mutating state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);
      final beforeInteractions = container.read(appControllerProvider).interactions.length;
      final beforeConnections = container.read(appControllerProvider).connections;
      final beforeSummary = container.read(appControllerProvider).lastAiSummary;

      final result = await controller.previewAiUpdate(
        'mike',
        'Had coffee with Mike today. He mentioned his new job.',
        const [],
      );

      final afterState = container.read(appControllerProvider);
      
      // State should not change
      expect(afterState.interactions.length, beforeInteractions);
      expect(afterState.connections, beforeConnections);
      expect(afterState.lastAiSummary, beforeSummary);
      
      // Result should contain parsed data
      expect(result.interactions, isNotEmpty);
      expect(result.contactId, 'mike');
      expect(result.summary, isNotEmpty);
    });

    test('commitAiUpdate applies preview result to state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);
      final beforeInteractions = container.read(appControllerProvider).interactions.length;
      
      final result = AiUpdateResult(
        summary: 'Test summary',
        contactId: 'mike',
        interactions: [
          CrmInteraction(
            id: 'test-interaction',
            contactId: 'mike',
            type: InteractionType.sharedActivity,
            title: 'Coffee chat',
            note: 'Discussed new job',
            date: DateTime(2026, 5, 15),
            source: InteractionSource.aiSuggested,
          ),
        ],
        nextStep: 'Follow up next week',
      );

      controller.commitAiUpdate(result);

      final afterState = container.read(appControllerProvider);
      
      // State should be updated
      expect(afterState.interactions.length, beforeInteractions + 1);
      expect(afterState.interactions.first.id, 'test-interaction');
      expect(afterState.interactions.first.source, InteractionSource.aiSuggested);
      expect(afterState.lastAiSummary, 'Test summary');
      
      // Contact should be updated
      final mike = afterState.connections.firstWhere((c) => c.id == 'mike');
      expect(mike.nextStep, 'Follow up next week');
      expect(mike.bondScore, greaterThan(68)); // Original was 68
    });

    test('commitAiUpdate with edited interactions preserves user changes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);
      
      final result = AiUpdateResult(
        summary: 'Test summary',
        contactId: 'sarah',
        interactions: [
          CrmInteraction(
            id: 'edited-interaction',
            contactId: 'sarah',
            type: InteractionType.sharedActivity,
            title: 'User edited this title',
            note: 'User edited this note',
            date: DateTime(2026, 5, 14),
            source: InteractionSource.aiSuggested,
          ),
        ],
      );

      controller.commitAiUpdate(result);

      final afterState = container.read(appControllerProvider);
      final interaction = afterState.interactions.first;
      
      expect(interaction.title, 'User edited this title');
      expect(interaction.note, 'User edited this note');
      expect(interaction.date, DateTime(2026, 5, 14));
    });

    test('AI-suggested interactions are marked with aiSuggested source', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);
      
      final result = await controller.previewAiUpdate(
        'emily',
        'Reminder to ask Emily about her first week',
        const [],
      );

      // Preview should mark interactions as AI-suggested
      expect(result.interactions.first.source, InteractionSource.aiSuggested);
    });

    test('manual interactions retain manual source', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);
      
      controller.logInteraction(
        'david',
        InteractionType.relationshipNote,
        'Manual note',
        'This was typed manually',
      );

      final state = container.read(appControllerProvider);
      expect(state.interactions.first.source, InteractionSource.manual);
    });
  });
}
