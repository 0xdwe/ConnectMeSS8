import 'package:connect_me/src/app/connect_me_app.dart';
import 'package:connect_me/src/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> _pumpAndSignIn(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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
  return container;
}

void main() {
  testWidgets(
    'recommendations screen ignores stale recommendation ids',
    (tester) async {
      final container = await _pumpAndSignIn(tester);

      // The seeded recommendations list references 'mike', 'jessica',
      // 'sarah', 'david'. Delete 'mike' so the recommendation for 'mike'
      // points at no connection.
      container.read(appControllerProvider.notifier).deleteConnection('mike');
      await tester.pumpAndSettle();

      // Navigate to the recommendations screen via the View All link
      // on the home tab.
      await tester.tap(find.text('View All'));
      await tester.pumpAndSettle();

      // The screen must render without throwing. The other (still-valid)
      // recommendation cards should render; the stale 'mike' card is
      // silently skipped.
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('recommendation-card-mike')), findsNothing);
      expect(
        find.byKey(const Key('recommendation-card-jessica')),
        findsOneWidget,
      );
    },
  );
}
