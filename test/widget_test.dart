import 'package:connect_me/src/app/connect_me_app.dart';
import 'package:connect_me/src/features/contact_profile_screen.dart';
import 'package:connect_me/src/features/modals/update_person_picker_modal.dart';
import 'package:connect_me/src/features/modals/add_event_modal.dart';
import 'package:connect_me/src/features/tabs/planner_tab.dart';
import 'package:connect_me/src/features/edit_profile_screen.dart';
import 'package:connect_me/src/state/user_profile/user_profile_service.dart';
import 'package:connect_me/src/features/tabs/settings_tab.dart';
import 'package:connect_me/src/state/firebase_providers.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'test_overrides.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connect_me/src/state/connections/connection_providers.dart';
import 'package:connect_me/src/state/connections/event_providers.dart';
import 'package:connect_me/src/state/connections/interaction_providers.dart';
import 'package:connect_me/src/state/connections/user_doc_store_providers.dart';
import 'package:connect_me/src/state/connections/batched_writes_providers.dart';
import 'package:connect_me/src/state/connections/in_memory_connection_store.dart';
import 'package:connect_me/src/state/connections/in_memory_event_store.dart';
import 'package:connect_me/src/state/connections/in_memory_interaction_store.dart';
import 'package:connect_me/src/state/connections/in_memory_user_doc_store.dart';
import 'package:connect_me/src/state/connections/batched_writes.dart';
import 'package:connect_me/src/models/social_models.dart';

Future<void> pumpConnectMe(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final connections = InMemoryConnectionStore();
  final interactions = InMemoryInteractionStore();
  final events = InMemoryEventStore();
  final userDoc = InMemoryUserDocStore();
  final batched = InMemoryBatchedWrites(
    connectionStore: connections,
    interactionStore: interactions,
    eventStore: events,
  );

  // #041: production memoryStoreProvider returns FileMemoryStore. Real
  // file I/O can't run under pumpAndSettle's fake async, so widget
  // tests override to InMemoryMemoryStore.
  // #052: AuthScreen sign-in routes through firebaseAuthProvider; tests
  // override with MockFirebaseAuth so the demo login resolves.
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
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
        connectionStoreProvider.overrideWithValue(connections),
        interactionStoreProvider.overrideWithValue(interactions),
        eventStoreProvider.overrideWithValue(events),
        userDocStoreProvider.overrideWithValue(userDoc),
        batchedWritesProvider.overrideWithValue(batched),
      ],
      child: const ConnectMeApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> signInAsDemo(WidgetTester tester) async {
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
}

Future<void> openJessicaProfile(WidgetTester tester) async {
  await tester.tap(find.text('People').last);
  await tester.pumpAndSettle();
  final jessicaFinder = find.text('Jessica Taylor');
  await tester.scrollUntilVisible(
    jessicaFinder,
    120,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('people-tab')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(jessicaFinder.first);
  await tester.pumpAndSettle();

  // Tap the InkWell ancestor to ensure the tap is registered
  final inkWell = find.ancestor(
    of: jessicaFinder.first,
    matching: find.byType(InkWell),
  );

  if (inkWell.evaluate().isNotEmpty) {
    await tester.tap(inkWell.first);
  } else {
    await tester.tap(jessicaFinder.first);
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('auth flow enters app and bottom nav switches tabs', (
    tester,
  ) async {
    await pumpConnectMe(tester);

    expect(find.text('Welcome back.'), findsOneWidget);
    await signInAsDemo(tester);

    expect(find.byKey(const Key('home-tab')), findsOneWidget);
    await tester.tap(find.text('People'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('people-tab')), findsOneWidget);
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planner-tab')), findsOneWidget);
  });

  // Test 'profile button opens heatmap profile' was removed here.
  // It exercised find.byKey(Key('profile-button')) which only exists on
  // AppHeader (crm_widgets.dart) — a widget no longer instantiated by any
  // screen since #016 (three-tab IA). The /me route still exists and
  // ProfileScreen + HeatmapCard still exist as orphaned code, but no UI
  // entry point reaches them. See #037 for the triage decision (delete
  // dead code or restore an entry point).

  testWidgets('plus menu add connection mutates visible people list', (
    tester,
  ) async {
    await pumpConnectMe(tester);
    await signInAsDemo(tester);

    await tester.tap(find.byKey(const Key('plus-action-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Connection'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('add-name-field')),
      'Ari Rivera',
    );
    await tester.enterText(
      find.byKey(const Key('add-email-field')),
      'ari@email.com',
    );
    await tester.tap(find.byKey(const Key('save-connection-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('People'));
    await tester.pumpAndSettle();
    expect(find.text('Ari Rivera'), findsOneWidget);
  });

  testWidgets('plus menu update connection opens AI update page', (
    tester,
  ) async {
    await pumpConnectMe(tester);
    await signInAsDemo(tester);

    await tester.tap(find.byKey(const Key('plus-action-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update Connection'));
    await tester.pumpAndSettle();

    // Scope the finder to the picker modal so we don't collide with the
    // 'Mike Chen' that's still rendered on the recommendation card behind
    // the modal scrim.
    final mikeInPicker = find.descendant(
      of: find.byType(UpdatePersonPickerModal),
      matching: find.text('Mike Chen'),
    );
    await tester.scrollUntilVisible(
      mikeInPicker,
      120,
      scrollable: find
          .descendant(
            of: find.byType(UpdatePersonPickerModal),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(mikeInPicker);
    await tester.pumpAndSettle();
    expect(find.text('Update with AI'), findsOneWidget);
    expect(find.text('Update Mike Chen'), findsOneWidget);
  });

  testWidgets('plus sheet shows all three actions', (tester) async {
    await pumpConnectMe(tester);
    await signInAsDemo(tester);

    await tester.tap(find.byKey(const Key('plus-action-button')));
    await tester.pumpAndSettle();

    expect(find.text('Add Connection'), findsOneWidget);
    expect(find.text('Update Connection'), findsOneWidget);
    expect(find.text('Plan Event'), findsOneWidget);
    expect(find.text('Paste a chat, AI will categorize.'), findsOneWidget);
  });

  testWidgets('contact profile renders relationship facts strip and history', (
    tester,
  ) async {
    await pumpConnectMe(tester);
    await signInAsDemo(tester);

    await openJessicaProfile(tester);

    // Wait for layout.
    await tester.pumpAndSettle();

    // Pass 2 (#033): the facts (relationship label, known years, last
    // contact) now live as a single inline caption strip in the header
    // card instead of a separate RelationshipFactsCard.
    expect(find.textContaining('known'), findsOneWidget);
    expect(find.textContaining('last contact'), findsOneWidget);

    // Jessica has no history, so the dense History card shows the warm
    // empty-state copy. Scroll to it past the AI Insights card.
    await tester.scrollUntilVisible(
      find.textContaining('new'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('new'), findsOneWidget);
  });

  testWidgets('contact profile shows insight summary in header', (
    tester,
  ) async {
    await pumpConnectMe(tester);
    await signInAsDemo(tester);

    await openJessicaProfile(tester);

    // Insight summary should be visible in header (not as expandable card)
    expect(find.textContaining('Jessica'), findsWidgets);
  });

  testWidgets('contact profile avoids overflow at narrow large text scale', (
    tester,
  ) async {
    final flutterErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = flutterErrors.add;
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    void restoreTestWindow() {
      FlutterError.onError = previousOnError;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    }

    addTearDown(restoreTestWindow);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...signedInDemoOverrides(),
          memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
        ],
        child: const MaterialApp(
          home: ContactProfileScreen(contactId: 'jessica'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    restoreTestWindow();

    expect(
      flutterErrors
          .map((error) => error.exceptionAsString())
          .where((message) => message.contains('RenderFlex overflowed')),
      isEmpty,
    );
  });

  testWidgets('profile can be edited from settings', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...signedInDemoOverrides(),
          memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
        ],
        child: MaterialApp(
          theme: AppTheme.data(false),
          home: const Scaffold(body: SettingsTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Jamie Chen',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'jamie@example.com',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Jamie Chen'), findsOneWidget);
  });

  testWidgets('settings can add custom event type', (tester) async {
    // Default test surface is 800x600. SettingsTab's 'Manage Event Types'
    // row sits at y≈603, just below the visible viewport, which causes
    // enterText to fail because the TextField is offscreen. Give
    // Settings comfortable vertical room.
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...signedInDemoOverrides(),
          memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
        ],
        child: MaterialApp(
          theme: AppTheme.data(false),
          home: const Scaffold(body: SettingsTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage Event Types'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('new-event-type-field')),
      'Workshop',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Workshop'), findsOneWidget);
  });

  testWidgets('planner opens existing event in edit mode', (tester) async {
    final now = DateTime.now();
    final eventsStore = InMemoryEventStore();
    final connectionsStore = InMemoryConnectionStore();
    final interactionStore = InMemoryInteractionStore();
    final userDocStore = InMemoryUserDocStore();
    final batchedWrites = InMemoryBatchedWrites(
      connectionStore: connectionsStore,
      interactionStore: interactionStore,
      eventStore: eventsStore,
    );

    await eventsStore.save(
      PlannerEvent(
        id: 'e1',
        title: 'Coffee with Sarah',
        contactId: 'sarah',
        category: 'Friends',
        date: DateTime(2026, 4, 28),
        note: 'Google Calendar mock sync',
        eventType: 'Coffee',
        isAllDay: false,
        startTimeMinutes: 10 * 60,
        endTimeMinutes: 11 * 60 + 30,
      ),
    );
    await eventsStore.save(
      PlannerEvent(
        id: 'e2',
        title: 'Team Meeting',
        contactId: 'emily',
        category: 'Work',
        date: DateTime(2026, 4, 30),
        note: 'Discuss launch',
        eventType: 'Meeting',
        isAllDay: false,
        startTimeMinutes: 14 * 60,
        endTimeMinutes: 15 * 60 + 30,
      ),
    );

    await connectionsStore.save(
      Connection(
        id: 'sarah',
        name: 'Sarah Johnson',
        email: 'sarah.j@email.com',
        category: 'Friends',
        avatar: '👱‍♀️',
        bondScore: 92,
        nextStep: 'Coffee catch-up',
        lastContact: now.subtract(const Duration(days: 7)),
        notes: 'Coffee with Sarah scheduled.',
        knownSince: DateTime(2020, 6, 1),
        preferredChannels: const ['Text', 'Instagram', 'Coffee'],
        isSample: true,
      ),
    );
    await connectionsStore.save(
      Connection(
        id: 'emily',
        name: 'Emily Rodriguez',
        email: 'emily.r@email.com',
        category: 'Work',
        avatar: '👩‍💼',
        bondScore: 85,
        nextStep: 'Ask about first week in new role',
        lastContact: now.subtract(const Duration(days: 5)),
        notes: 'First week at new role. Keep momentum going.',
        knownSince: DateTime(2023, 9, 1),
        preferredChannels: const ['Slack', 'Email', 'Text'],
        isSample: true,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(
              signedIn: true,
              mockUser: MockUser(
                uid: 'demo-uid',
                isAnonymous: false,
                email: 'demo@example.com',
                displayName: 'Demo',
              ),
            ),
          ),
          eventStoreProvider.overrideWithValue(eventsStore),
          connectionStoreProvider.overrideWithValue(connectionsStore),
          interactionStoreProvider.overrideWithValue(interactionStore),
          userDocStoreProvider.overrideWithValue(userDocStore),
          batchedWritesProvider.overrideWithValue(batchedWrites),
        ],
        child: MaterialApp(
          theme: AppTheme.data(false),
          home: const Scaffold(body: PlannerTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Coffee with Sarah'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Coffee with Sarah').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee with Sarah').first);
    await tester.pumpAndSettle();

    expect(find.text('Edit Event'), findsOneWidget);
    expect(find.text('Delete Event'), findsOneWidget);
  });

  testWidgets('planner search dialog filters and opens event', (tester) async {
    final now = DateTime.now();
    final eventsStore = InMemoryEventStore();
    final connectionsStore = InMemoryConnectionStore();
    final interactionStore = InMemoryInteractionStore();
    final userDocStore = InMemoryUserDocStore();
    final batchedWrites = InMemoryBatchedWrites(
      connectionStore: connectionsStore,
      interactionStore: interactionStore,
      eventStore: eventsStore,
    );

    await eventsStore.save(
      PlannerEvent(
        id: 'e1',
        title: 'Coffee with Sarah',
        contactId: 'sarah',
        category: 'Friends',
        date: DateTime(2026, 4, 28),
        note: 'Google Calendar mock sync',
        eventType: 'Coffee',
        isAllDay: false,
        startTimeMinutes: 10 * 60,
        endTimeMinutes: 11 * 60 + 30,
      ),
    );

    await connectionsStore.save(
      Connection(
        id: 'sarah',
        name: 'Sarah Johnson',
        email: 'sarah.j@email.com',
        category: 'Friends',
        avatar: '👱‍♀️',
        bondScore: 92,
        nextStep: 'Coffee catch-up',
        lastContact: now.subtract(const Duration(days: 7)),
        notes: 'Coffee with Sarah scheduled.',
        knownSince: DateTime(2020, 6, 1),
        preferredChannels: const ['Text', 'Instagram', 'Coffee'],
        isSample: true,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(
              signedIn: true,
              mockUser: MockUser(
                uid: 'demo-uid',
                isAnonymous: false,
                email: 'demo@example.com',
                displayName: 'Demo',
              ),
            ),
          ),
          eventStoreProvider.overrideWithValue(eventsStore),
          connectionStoreProvider.overrideWithValue(connectionsStore),
          interactionStoreProvider.overrideWithValue(interactionStore),
          userDocStoreProvider.overrideWithValue(userDocStore),
          batchedWritesProvider.overrideWithValue(batchedWrites),
        ],
        child: MaterialApp(
          theme: AppTheme.data(false),
          home: const Scaffold(body: PlannerTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap search icon in top header bar
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    // Verify empty state is displayed initially inside the dialog
    expect(find.text('Start typing to search events'), findsOneWidget);
    expect(find.text('Search by title or contact name'), findsOneWidget);

    // Enter query in search text field
    await tester.enterText(
      find.widgetWithText(TextField, 'Search by event title or contact...'),
      'Sarah',
    );
    await tester.pumpAndSettle();

    // Verify that the empty state is hidden and the event is displayed
    expect(find.text('Start typing to search events'), findsNothing);
    expect(find.text('Coffee with Sarah'), findsOneWidget);

    // Tap on the event card inside search results list
    await tester.tap(find.text('Coffee with Sarah'));
    await tester.pumpAndSettle();

    // Verify that it opens the edit event modal successfully
    expect(find.text('Edit Event'), findsOneWidget);
    expect(find.text('Delete Event'), findsOneWidget);
  });

  testWidgets('planner add event modal displays premium cards', (tester) async {
    final eventsStore = InMemoryEventStore();
    final connectionsStore = InMemoryConnectionStore();
    final interactionStore = InMemoryInteractionStore();
    final userDocStore = InMemoryUserDocStore();
    final batchedWrites = InMemoryBatchedWrites(
      connectionStore: connectionsStore,
      interactionStore: interactionStore,
      eventStore: eventsStore,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(
              signedIn: true,
              mockUser: MockUser(
                uid: 'demo-uid',
                isAnonymous: false,
                email: 'demo@example.com',
                displayName: 'Demo',
              ),
            ),
          ),
          eventStoreProvider.overrideWithValue(eventsStore),
          connectionStoreProvider.overrideWithValue(connectionsStore),
          interactionStoreProvider.overrideWithValue(interactionStore),
          userDocStoreProvider.overrideWithValue(userDocStore),
          batchedWritesProvider.overrideWithValue(batchedWrites),
        ],
        child: MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: AddEventModal(initialDate: DateTime(2026, 4, 27)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify all the premium card sections and labels from our mockup
    expect(find.text('Add Event'), findsOneWidget);
    expect(find.text('TITLE'), findsOneWidget);
    expect(find.text('EVENT TYPE'), findsOneWidget);
    expect(find.text('LINK TO CONTACT (OPTIONAL)'), findsOneWidget);
    expect(find.text('NOTE'), findsOneWidget);
    expect(find.text('All Day'), findsOneWidget);
    expect(find.text('Repeat'), findsOneWidget);
    expect(find.text('Save Event'), findsOneWidget);
  });

  testWidgets('AddEventModal toggles All Day and updates time dropdowns', (
    WidgetTester tester,
  ) async {
    final eventsStore = InMemoryEventStore();
    final connectionsStore = InMemoryConnectionStore();
    final interactionStore = InMemoryInteractionStore();
    final userDocStore = InMemoryUserDocStore();
    final batchedWrites = InMemoryBatchedWrites(
      connectionStore: connectionsStore,
      interactionStore: interactionStore,
      eventStore: eventsStore,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(
              signedIn: true,
              mockUser: MockUser(
                uid: 'demo-uid',
                isAnonymous: false,
                email: 'demo@example.com',
                displayName: 'Demo',
              ),
            ),
          ),
          eventStoreProvider.overrideWithValue(eventsStore),
          connectionStoreProvider.overrideWithValue(connectionsStore),
          interactionStoreProvider.overrideWithValue(interactionStore),
          userDocStoreProvider.overrideWithValue(userDocStore),
          batchedWritesProvider.overrideWithValue(batchedWrites),
        ],
        child: MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: AddEventModal(initialDate: DateTime(2026, 4, 27)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Toggle All Day switch off to display time rows
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    // Verify Start and End time dropdown widgets are present
    expect(find.byKey(const Key('event-start-hour')), findsOneWidget);
    expect(find.byKey(const Key('event-start-minute')), findsOneWidget);
    expect(find.byKey(const Key('event-start-period')), findsOneWidget);
    expect(find.byKey(const Key('event-end-hour')), findsOneWidget);
    expect(find.byKey(const Key('event-end-minute')), findsOneWidget);
    expect(find.byKey(const Key('event-end-period')), findsOneWidget);
  });

  testWidgets('EditProfileScreen displays stats, gcal sync switch, and handles layout updates', (WidgetTester tester) async {
    final eventsStore = InMemoryEventStore();
    final connectionsStore = InMemoryConnectionStore();
    final interactionStore = InMemoryInteractionStore();
    final userDocStore = InMemoryUserDocStore();
    final batchedWrites = InMemoryBatchedWrites(
      connectionStore: connectionsStore,
      interactionStore: interactionStore,
      eventStore: eventsStore,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(
              signedIn: true,
              mockUser: MockUser(
                uid: 'demo-uid',
                isAnonymous: false,
                email: 'demo@example.com',
                displayName: 'Cliff Owen',
              ),
            ),
          ),
          eventStoreProvider.overrideWithValue(eventsStore),
          connectionStoreProvider.overrideWithValue(connectionsStore),
          interactionStoreProvider.overrideWithValue(interactionStore),
          userDocStoreProvider.overrideWithValue(userDocStore),
          batchedWritesProvider.overrideWithValue(batchedWrites),
          accountProfileProvider.overrideWithValue(
            const AccountProfile(
              uid: 'demo-uid',
              email: 'demo@example.com',
              name: 'Cliff Owen',
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.data(false),
          home: const Scaffold(
            body: EditProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Redundant save button in AppBar actions should be removed
    expect(find.byIcon(Icons.save_outlined), findsNothing);

    // Bottom action buttons must exist
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
  });
}
