import 'package:connect_me/src/app/connect_me_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpConnectMe(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: ConnectMeApp()));
}

void main() {
  testWidgets('auth flow enters app and bottom nav switches tabs', (
    tester,
  ) async {
    await pumpConnectMe(tester);

    expect(find.text('Remember people\nlike it matters.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sign-in-button')));
    await tester.pumpAndSettle();

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
    await tester.tap(find.byKey(const Key('sign-in-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-button')));
    await tester.pumpAndSettle();

    expect(find.text('Alex Martinez'), findsOneWidget);
    expect(find.text('Connection Heatmap by Category'), findsOneWidget);
  });

  testWidgets('plus menu add connection mutates visible people list', (
    tester,
  ) async {
    await pumpConnectMe(tester);
    await tester.tap(find.byKey(const Key('sign-in-button')));
    await tester.pumpAndSettle();

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
    await tester.tap(find.byKey(const Key('sign-in-button')));
    await tester.pumpAndSettle();

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
    expect(find.text('AI Update'), findsOneWidget);
    expect(find.text('Update Mike Chen'), findsOneWidget);
  });

  testWidgets('contact profile renders AI insight dashboard cards', (
    tester,
  ) async {
    await pumpConnectMe(tester);
    await tester.tap(find.byKey(const Key('sign-in-button')));
    await tester.pumpAndSettle();

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

    expect(find.text('Recommended Action!'), findsOneWidget);
    expect(find.text('AI Insight'), findsOneWidget);
    expect(find.text('Top Communication Channels'), findsOneWidget);
    expect(find.text('Interaction Frequency (12 months)'), findsOneWidget);
  });

  testWidgets('AI insight card expands why details', (tester) async {
    await pumpConnectMe(tester);
    await tester.tap(find.byKey(const Key('sign-in-button')));
    await tester.pumpAndSettle();

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

    expect(find.byKey(const Key('ai-insight-why')), findsNothing);
    await tester.tap(find.byKey(const Key('ai-insight-card')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-insight-why')), findsOneWidget);
  });
}
