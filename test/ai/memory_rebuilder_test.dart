import 'package:connect_me/src/ai/fake_memory_rebuilder.dart';
import 'package:connect_me/src/ai/memory_rebuilder.dart';
import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeMemoryRebuilder', () {
    late FakeMemoryRebuilder rebuilder;

    setUp(() {
      rebuilder = FakeMemoryRebuilder();
    });

    test('rebuild returns a MemoryRebuildResult with updated summary and history',
        () async {
      final result = await rebuilder.rebuild(
        contact: Connection(
          id: 'test-contact',
          name: 'Test Contact',
          email: 'test@example.com',
          category: 'Friends',
          avatar: '😊',
          bondScore: 50,
          nextStep: '',
          lastContact: DateTime(2026, 1, 1),
          notes: '',
          knownSince: DateTime(2020),
          preferredChannels: const ['Text'],
        ),
        currentMemory: MemoryDocument(
          contactId: 'test-contact',
          displayName: 'Test Contact',
          lastUpdated: DateTime(2026, 5, 1),
          summary: 'Original summary',
          history: 'Original history',
        ),
        remainingInteractions: const [],
        deletedInteraction: CrmInteraction(
          id: 'del-1',
          contactId: 'test-contact',
          type: InteractionType.interaction,
          title: 'Deleted Event',
          note: '',
          date: DateTime(2026, 4, 1),
        ),
      );

      expect(result, isA<MemoryRebuildResult>());
      expect(result.memoryDocument.summary,
          contains('Test Contact'));
      expect(result.memoryDocument.summary,
          contains('Deleted Event'));
      expect(result.memoryDocument.history,
          contains('Deleted Event'));
    });

    test('rebuild returns a nextStep mentioning the contact name',
        () async {
      final result = await rebuilder.rebuild(
        contact: Connection(
          id: 'alice',
          name: 'Alice Wang',
          email: 'alice@example.com',
          category: 'Friends',
          avatar: '👩',
          bondScore: 70,
          nextStep: '',
          lastContact: DateTime(2026, 1, 1),
          notes: '',
          knownSince: DateTime(2020),
          preferredChannels: const ['Text'],
        ),
        currentMemory: MemoryDocument(
          contactId: 'alice',
          displayName: 'Alice Wang',
          lastUpdated: DateTime(2026, 5, 1),
        ),
        remainingInteractions: const [],
        deletedInteraction: CrmInteraction(
          id: 'del-2',
          contactId: 'alice',
          type: InteractionType.interaction,
          title: 'Coffee chat',
          note: '',
          date: DateTime(2026, 4, 1),
        ),
      );

      expect(result.nextStep, 'Check in with Alice Wang');
    });

    test('rebuild increments rebuildCallCount', () async {
      expect(rebuilder.rebuildCallCount, 0);

      await rebuilder.rebuild(
        contact: _dummyContact(),
        currentMemory: _dummyMemory(),
        remainingInteractions: const [],
        deletedInteraction: _dummyDeletedInteraction(),
      );
      expect(rebuilder.rebuildCallCount, 1);

      await rebuilder.rebuild(
        contact: _dummyContact(),
        currentMemory: _dummyMemory(),
        remainingInteractions: const [],
        deletedInteraction: _dummyDeletedInteraction(),
      );
      expect(rebuilder.rebuildCallCount, 2);
    });

    test('rebuild returns nextResult when set', () async {
      final customMemory = MemoryDocument(
        contactId: 'custom',
        displayName: 'Custom',
        lastUpdated: DateTime(2026, 6, 1),
        summary: 'Custom rebuilt memory',
      );
      rebuilder.nextResult = MemoryRebuildResult(
        memoryDocument: customMemory,
        nextStep: 'Custom next step',
      );

      final result = await rebuilder.rebuild(
        contact: _dummyContact(),
        currentMemory: _dummyMemory(),
        remainingInteractions: const [],
        deletedInteraction: _dummyDeletedInteraction(),
      );

      expect(result.memoryDocument.summary, 'Custom rebuilt memory');
      expect(result.nextStep, 'Custom next step');
      // Call count still increments
      expect(rebuilder.rebuildCallCount, 1);
    });
  });
}

Connection _dummyContact() => Connection(
      id: 'dummy',
      name: 'Dummy',
      email: 'dummy@example.com',
      category: 'Friends',
      avatar: '😊',
      bondScore: 50,
      nextStep: '',
      lastContact: DateTime(2026, 1, 1),
      notes: '',
      knownSince: DateTime(2020),
      preferredChannels: const ['Text'],
    );

MemoryDocument _dummyMemory() => MemoryDocument(
      contactId: 'dummy',
      displayName: 'Dummy',
      lastUpdated: DateTime(2026, 5, 1),
    );

CrmInteraction _dummyDeletedInteraction() => CrmInteraction(
      id: 'del-dummy',
      contactId: 'dummy',
      type: InteractionType.interaction,
      title: 'Dummy event',
      note: '',
      date: DateTime(2026, 4, 1),
    );
