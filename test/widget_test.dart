import 'package:connect_me/src/app/connect_me_app.dart';
import 'package:connect_me/src/features/contact_profile_screen.dart';
import 'package:connect_me/src/features/tabs/planner_tab.dart';
import 'package:connect_me/src/features/tabs/settings_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpConnectMe(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: ConnectMeApp()));
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
  await tester.scrollUntilVisible(
    find.text('Jessica Taylor'),
    120,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('people-tab')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.tap(find.text('Jessica Taylor'));
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
    await tester.tap(find.text('Planner'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planner-tab')), findsOneWidget);
  });

  testWidgets('profile button opens heatmap profile', (tester) async {
    await pumpConnectMe(tester);
    await signInAsDemo(tester);

    await tester.tap(find.byKey(const Key('profile-button')));
    await tester.pumpAndSettle();

    expect(find.text('Alex Martinez'), findsOneWidget);
    expect(find.text('Connection Heatmap by Category'), findsOneWidget);
  });

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
    await tester.scrollUntilVisible(
      find.text('Mike Chen'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Mike Chen'));
    await tester.pumpAndSettle();
    expect(find.text('Update with AI'), findsOneWidget);
    expect(find.text('Update Mike Chen'), findsOneWidget);
  });

  testWidgets('contact profile renders AI insight dashboard cards', (
    tester,
  ) async {
    await pumpConnectMe(tester);
    await signInAsDemo(tester);

    await openJessicaProfile(tester);

    expect(find.text('Recommended Action!'), findsOneWidget);
    expect(find.text('AI Insight'), findsOneWidget);
    expect(find.text('Top Communication Channels'), findsOneWidget);
    expect(find.text('Interaction Frequency (12 months)'), findsOneWidget);
  });

  testWidgets('AI insight card expands why details', (tester) async {
    await pumpConnectMe(tester);
    await signInAsDemo(tester);

    await openJessicaProfile(tester);

    expect(find.byKey(const Key('ai-insight-why')), findsNothing);
    await tester.tap(find.byKey(const Key('ai-insight-card')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-insight-why')), findsOneWidget);
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
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: SettingsTab())),
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
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: SettingsTab())),
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
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: PlannerTab())),
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
