import 'package:connect_me/src/features/contact_profile_screen.dart';
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
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pump [ContactProfileScreen] with in-memory stores seeded with
/// sample data matching [AppState.seeded].
Future<void> _pump(WidgetTester tester, String contactId) async {
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
        memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
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
  });
}
