import 'package:connect_me/src/ai/memory_rebuilder.dart';
import 'package:connect_me/src/features/contact_profile_screen.dart';
import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/connections/batched_writes.dart';
import 'package:connect_me/src/state/connections/batched_writes_providers.dart';
import 'package:connect_me/src/state/connections/connection_providers.dart';
import 'package:connect_me/src/state/connections/connection_seeder.dart';
import 'package:connect_me/src/state/connections/event_providers.dart';
import 'package:connect_me/src/state/connections/in_memory_connection_store.dart';
import 'package:connect_me/src/state/connections/in_memory_event_store.dart';
import 'package:connect_me/src/state/connections/in_memory_interaction_store.dart';
import 'package:connect_me/src/state/connections/in_memory_user_doc_store.dart';
import 'package:connect_me/src/state/connections/interaction_providers.dart';
import 'package:connect_me/src/state/connections/user_doc_store_providers.dart';
import 'package:connect_me/src/state/firebase_providers.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:connect_me/src/state/memory/memory_rebuilder_providers.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pump [ContactProfileScreen] with in-memory stores seeded with
/// sample data matching [AppState.seeded].
///
/// [memoryStore] can be provided to pre-seed memory documents; defaults
/// to an empty [InMemoryMemoryStore]. [additionalOverrides] adds extra
/// provider overrides (e.g. a throwing memory rebuilder).
Future<void> _pump(
  WidgetTester tester,
  String contactId, {
  InMemoryMemoryStore? memoryStore,
  List<dynamic> additionalOverrides = const <dynamic>[],
}) async {
  final connections = InMemoryConnectionStore();
  connections.seedSync(SeederSampleSource.connections());
  final interactions = InMemoryInteractionStore();
  interactions.seedSync(SeederSampleSource.interactions());
  final events = InMemoryEventStore();
  events.seedSync(SeederSampleSource.events());
  final userDoc = InMemoryUserDocStore();
  final batched = InMemoryBatchedWrites(
    connectionStore: connections,
    interactionStore: interactions,
    eventStore: events,
  );
  final memory = memoryStore ?? InMemoryMemoryStore();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(
          MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(
              isAnonymous: false,
              uid: 'test-uid',
              email: 'test@example.com',
              displayName: 'Test User',
            ),
          ),
        ),
        connectionStoreProvider.overrideWithValue(connections),
        interactionStoreProvider.overrideWithValue(interactions),
        eventStoreProvider.overrideWithValue(events),
        userDocStoreProvider.overrideWithValue(userDoc),
        batchedWritesProvider.overrideWithValue(batched),
        memoryStoreProvider.overrideWithValue(memory),
        ...additionalOverrides,
      ],
      child: MaterialApp(
        theme: AppTheme.data(false),
        home: ContactProfileScreen(contactId: contactId),
      ),
    ),
  );
  // Pump microtasks so snapshot emissions land in state.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }

  // Scroll to Activity Log section so ListView renders it.
  await tester.scrollUntilVisible(
    find.text('Activity Log'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('Activity Log Delete (#123)', () {
    testWidgets('each activity log row shows a delete icon button', (
      tester,
    ) async {
      await _pump(tester, 'mike');

      expect(
        find.byKey(const Key('delete-interaction-i2')),
        findsOneWidget,
      );
    });

    testWidgets('tapping delete shows the confirmation dialog', (tester) async {
      await _pump(tester, 'mike');

      await tester.tap(
        find.byKey(const Key('delete-interaction-i2')),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Delete this activity?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('confirming delete shows an undo SnackBar', (tester) async {
      await _pump(tester, 'mike');

      await tester.tap(
        find.byKey(const Key('delete-interaction-i2')),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.text('Delete'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Undo'), findsOneWidget);
      expect(find.textContaining('Deleting'), findsOneWidget);
    });

    testWidgets('delete button is disabled while deletion is in progress', (
      tester,
    ) async {
      await _pump(tester, 'mike');

      await tester.tap(
        find.byKey(const Key('delete-interaction-i2')),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.text('Delete'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final deleteButton = tester.widget<IconButton>(
        find.byKey(const Key('delete-interaction-i2')),
      );
      expect(deleteButton.onPressed, isNull);

      await tester.tap(find.text('Undo'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    });

    testWidgets('undo restores the activity when pressed before timeout', (
      tester,
    ) async {
      await _pump(tester, 'mike');

      expect(find.text('Job application'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('delete-interaction-i2')),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.text('Delete'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.text('Undo'));
      await tester.pump();

      // Wait past the original undo window to confirm the deletion was cancelled.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.text('Job application'), findsOneWidget);
    });

    testWidgets('row is removed after undo window expires', (tester) async {
      await _pump(tester, 'mike');

      // Find the interaction title to verify it exists before deletion
      expect(find.text('Job application'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('delete-interaction-i2')),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.text('Delete'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Wait for the 4-second undo window to expire
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // The interaction row should be removed from the Activity Log
      expect(find.text('Job application'), findsNothing);
    });

    testWidgets('when memory rebuild fails, interaction is still deleted', (
      tester,
    ) async {
      // Pre-seed a memory document for mike so the rebuild branch is entered
      final memoryStore = InMemoryMemoryStore();
      await memoryStore.save(MemoryDocument.empty(
        contactId: 'mike',
        displayName: 'Mike',
        now: DateTime(2026),
      ));

      // Use a throwing memory rebuilder to simulate a rebuild failure
      final throwingRebuilder = _ThrowingMemoryRebuilder();

      await _pump(
        tester,
        'mike',
        memoryStore: memoryStore,
        additionalOverrides: [
          memoryRebuilderProvider.overrideWithValue(throwingRebuilder),
        ],
      );

      // Tap delete on i2 (Mike's interaction)
      await tester.tap(
        find.byKey(const Key('delete-interaction-i2')),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Confirm deletion
      await tester.tap(find.text('Delete'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Advance the fake clock by 4s to fire the undo Timer.
      await tester.pump(const Duration(seconds: 4));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // The interaction should be deleted regardless of rebuild failure
      expect(find.text('Job application'), findsNothing,
          reason: 'the interaction should be deleted even if rebuild fails');
    });
  });
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
