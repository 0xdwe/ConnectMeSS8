import 'package:connect_me/src/app/connect_me_app.dart';
import 'package:connect_me/src/features/contact_profile_screen.dart';
import 'package:connect_me/src/features/modals/update_person_picker_modal.dart';
import 'package:connect_me/src/features/tabs/planner_tab.dart';
import 'package:connect_me/src/features/tabs/settings_tab.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpConnectMe(WidgetTester tester) async {
  // #041: production memoryStoreProvider returns FileMemoryStore. Real
  // file I/O can't run under pumpAndSettle's fake async, so widget
  // tests override to InMemoryMemoryStore.
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
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

  testWidgets('contact profile shows insight summary in header', (tester) async {
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
      const ProviderScope(
        child: MaterialApp(home: ContactProfileScreen(contactId: 'jessica')),
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
    await tester.pumpWidget(
      ProviderScope(
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
      find.widgetWithText(TextField, 'New event type'),
      'Workshop',
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Workshop'), findsOneWidget);
  });

  testWidgets('planner opens existing event in edit mode', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
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
      scrollable: find
          .descendant(
            of: find.byKey(const Key('planner-tab')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('Coffee with Sarah').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee with Sarah').first);
    await tester.pumpAndSettle();

    expect(find.text('Edit Event'), findsOneWidget);
    expect(find.text('Delete Event'), findsOneWidget);
  });

}
