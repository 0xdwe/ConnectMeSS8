import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/app_state.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
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
  group('AI Update Preview-and-Confirm Flow', () {
    test('AiUpdate.run returns AiUpdateResult without mutating state',
        () async {
      final container = _container();
      addTearDown(container.dispose);

      final beforeInteractions =
          container.read(appControllerProvider).interactions.length;
      final beforeConnections =
          container.read(appControllerProvider).connections;
      final beforeSummary =
          container.read(appControllerProvider).lastAiSummary;

      final mike = beforeConnections.firstWhere((c) => c.id == 'mike');
      final memory = await container.read(memoryProvider('mike').future);

      final result = await container.read(aiUpdateProvider).run(
            contact: mike,
            userInput: 'Had coffee with Mike today. He mentioned his new job.',
            currentMemory: memory,
            attachments: const [],
          );

      final afterState = container.read(appControllerProvider);

      // State should not change.
      expect(afterState.interactions.length, beforeInteractions);
      expect(afterState.connections, beforeConnections);
      expect(afterState.lastAiSummary, beforeSummary);

      // Result should contain parsed data.
      expect(result.interactions, isNotEmpty);
      expect(result.contactId, 'mike');
      expect(result.summary, isNotEmpty);
      expect(result.memoryDocument, isNotNull);
    });

    test('AiUpdate.commit applies preview result to state', () async {
      final container = _container();
      addTearDown(container.dispose);

      final beforeInteractions =
          container.read(appControllerProvider).interactions.length;

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

      await container.read(aiUpdateProvider).commit(result);

      final afterState = container.read(appControllerProvider);

      // State should be updated.
      expect(afterState.interactions.length, beforeInteractions + 1);
      expect(afterState.interactions.first.id, 'test-interaction');
      expect(afterState.interactions.first.source, InteractionSource.aiSuggested);
      expect(afterState.lastAiSummary, 'Test summary');

      // Contact should be updated.
      final mike = afterState.connections.firstWhere((c) => c.id == 'mike');
      expect(mike.nextStep, 'Follow up next week');
      expect(mike.bondScore, greaterThan(68)); // Original was 68.
    });

    test('AiUpdate.commit with edited interactions preserves user changes',
        () async {
      final container = _container();
      addTearDown(container.dispose);

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

      await container.read(aiUpdateProvider).commit(result);

      final afterState = container.read(appControllerProvider);
      final interaction = afterState.interactions.first;

      expect(interaction.title, 'User edited this title');
      expect(interaction.note, 'User edited this note');
      expect(interaction.date, DateTime(2026, 5, 14));
    });

    test('AI-suggested interactions are marked with aiSuggested source',
        () async {
      final container = _container();
      addTearDown(container.dispose);

      final emily = container
          .read(appControllerProvider)
          .connections
          .firstWhere((c) => c.id == 'emily');
      final memory = await container.read(memoryProvider('emily').future);

      final result = await container.read(aiUpdateProvider).run(
            contact: emily,
            userInput: 'Reminder to ask Emily about her first week',
            currentMemory: memory,
            attachments: const [],
          );

      // Run should mark interactions as AI-suggested.
      expect(result.interactions.first.source, InteractionSource.aiSuggested);
    });

    test('manual interactions retain manual source', () {
      final container = _container();
      addTearDown(container.dispose);

      container.read(appControllerProvider.notifier).logInteraction(
            'david',
            InteractionType.relationshipNote,
            'Manual note',
            'This was typed manually',
          );

      final state = container.read(appControllerProvider);
      expect(state.interactions.first.source, InteractionSource.manual);
    });

    test('commit persists the memory document via MemoryStore', () async {
      final store = InMemoryMemoryStore();
      final container = _container(store: store);
      addTearDown(container.dispose);

      final mike = container
          .read(appControllerProvider)
          .connections
          .firstWhere((c) => c.id == 'mike');
      final memory = await container.read(memoryProvider('mike').future);

      final result = await container.read(aiUpdateProvider).run(
            contact: mike,
            userInput: 'Had coffee with Mike yesterday',
            currentMemory: memory,
            attachments: const [],
          );

      // Pre-commit, the memory in the store has no history bullet.
      final preCommit = await store.load('mike');
      expect(preCommit, isNotNull);
      expect(preCommit!.history, isEmpty);

      await container.read(aiUpdateProvider).commit(result);

      final postCommit = await store.load('mike');
      expect(postCommit, isNotNull);
      expect(postCommit!.history, contains('Had coffee with Mike yesterday'));
    });

    test('cancel discards both interactions and memory append', () async {
      final store = InMemoryMemoryStore();
      final container = _container(store: store);
      addTearDown(container.dispose);

      final beforeInteractions =
          container.read(appControllerProvider).interactions.length;

      final mike = container
          .read(appControllerProvider)
          .connections
          .firstWhere((c) => c.id == 'mike');
      final memory = await container.read(memoryProvider('mike').future);
      final preHistory = memory.history;

      // Run produces a candidate result, but commit is never called.
      await container.read(aiUpdateProvider).run(
            contact: mike,
            userInput: 'Cancelled before save',
            currentMemory: memory,
            attachments: const [],
          );

      // Neither state nor store have moved.
      final afterState = container.read(appControllerProvider);
      expect(afterState.interactions.length, beforeInteractions);

      final stored = await store.load('mike');
      expect(stored?.history ?? '', preHistory);
    });
  });
}
