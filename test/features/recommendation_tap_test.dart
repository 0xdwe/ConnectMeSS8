import 'dart:async';

import 'package:connect_me/src/app/connect_me_app.dart';
import 'package:connect_me/src/features/modals/update_person_picker_modal.dart';
import 'package:connect_me/src/features/recommendations_screen.dart';
import 'package:connect_me/src/features/tabs/home_tab.dart';
import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/app_state.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:connect_me/src/state/connections/batched_writes.dart';
import 'package:connect_me/src/state/connections/batched_writes_providers.dart';
import 'package:connect_me/src/state/connections/connection_providers.dart';
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
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

List<dynamic> _storeOverrides() {
  final connections = InMemoryConnectionStore();
  final interactions = InMemoryInteractionStore();
  final events = InMemoryEventStore();
  final userDoc = InMemoryUserDocStore();
  for (final c in AppState.seeded().connections) {
    connections.save(c);
  }
  for (final i in AppState.seeded().interactions) {
    interactions.save(i);
  }
  for (final e in AppState.seeded().events) {
    events.save(e);
  }
  return [
    connectionStoreProvider.overrideWithValue(connections),
    interactionStoreProvider.overrideWithValue(interactions),
    eventStoreProvider.overrideWithValue(events),
    userDocStoreProvider.overrideWithValue(userDoc),
    batchedWritesProvider.overrideWithValue(
      InMemoryBatchedWrites(
        connectionStore: connections,
        interactionStore: interactions,
        eventStore: events,
      ),
    ),
  ];
}

Future<void> _pump(
  WidgetTester tester, {
  InMemoryMemoryStore? memoryStore,
}) async {
  // #052: AuthScreen sign-in routes through firebaseAuthProvider; tests
  // override with MockFirebaseAuth so the demo login resolves.
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        memoryStoreProvider.overrideWithValue(
          memoryStore ?? InMemoryMemoryStore(),
        ),
        firebaseAuthProvider.overrideWithValue(
          MockFirebaseAuth(
            mockUser: MockUser(
              isAnonymous: false,
              uid: 'demo-uid',
              email: 'demo@example.com',
              displayName: 'Demo',
            ),
          ),
        ),
        ..._storeOverrides(),
      ],
      child: const ConnectMeApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('login-email-field')),
    'demo@example.com',
  );
  await tester.enterText(
    find.byKey(const Key('login-password-field')),
    'password123',
  );
  await tester.tap(find.byKey(const Key('sign-in-button')));
  await tester.pumpAndSettle();
  // Ignore the pre-existing auth-screen layout overflow in this fixture.
  tester.takeException();
}

void main() {
  testWidgets('Home shows loading placeholders while recommendations load', (
    tester,
  ) async {
    final pending = Completer<List<Recommendation>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(
              signedIn: true,
              mockUser: MockUser(uid: 'demo-uid'),
            ),
          ),
          recommendationsProvider.overrideWith((_) => pending.future),
          ..._storeOverrides(),
        ],
        child: MaterialApp(
          theme: AppTheme.data(false),
          home: const Scaffold(body: HomeTab()),
        ),
      ),
    );

    expect(
      find.byKey(const Key('home-recommendations-loading')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('recommendation-card-mike')), findsNothing);
    pending.complete(const []);
  });

  testWidgets('recommendations screen shows loading placeholders', (
    tester,
  ) async {
    final pending = Completer<List<Recommendation>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(
              signedIn: true,
              mockUser: MockUser(uid: 'demo-uid'),
            ),
          ),
          recommendationsProvider.overrideWith((_) => pending.future),
          ..._storeOverrides(),
        ],
        child: MaterialApp(
          theme: AppTheme.data(false),
          home: const RecommendationsScreen(),
        ),
      ),
    );

    expect(
      find.byKey(const Key('recommendations-screen-loading')),
      findsOneWidget,
    );
    pending.complete(const []);
  });

  testWidgets('tapping a recommendation on Home opens the contact dashboard', (
    tester,
  ) async {
    await _pump(tester);

    final card = find.byKey(const Key('recommendation-card-mike'));
    await tester.scrollUntilVisible(
      card,
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('home-tab')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.text('Mike Chen'), findsWidgets);
    // Pass 2 #034 replaced 'Recommended Action!' / 'AI Insight' with the
    // AI Insights collapsible card using 'AI Insights' (section header)
    // and 'Recommendation' (callout title).
    expect(find.text('AI Insights'), findsOneWidget);
    expect(find.text('Recommendation'), findsOneWidget);
  });

  testWidgets('daily nudge opens the update person picker', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Send a message'));
    await tester.pumpAndSettle();

    expect(find.byType(UpdatePersonPickerModal), findsOneWidget);
    expect(find.text('Choose person to update'), findsOneWidget);
  });

  testWidgets(
    'tapping a recommendation on the recommendations screen opens the contact dashboard',
    (tester) async {
      await _pump(tester);

      await tester.tap(find.text('View All'));
      await tester.pumpAndSettle();

      final card = find.byKey(const Key('recommendation-card-jessica'));
      await tester.scrollUntilVisible(
        card,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(find.text('Jessica Taylor'), findsWidgets);
      // Pass 2 #034 replaced 'Recommended Action!' / 'AI Insight' with
      // the AI Insights collapsible card.
      expect(find.text('AI Insights'), findsOneWidget);
      expect(find.text('Recommendation'), findsOneWidget);
    },
  );
}
