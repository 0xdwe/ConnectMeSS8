import 'package:connect_me/src/app/connect_me_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpAndSignIn(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: ConnectMeApp()));
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
}

void main() {
  testWidgets(
    'tapping Update with AI on a contact dashboard opens the AI Update screen',
    (tester) async {
      await _pumpAndSignIn(tester);

      await tester.tap(find.text('People').last);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Mike Chen'),
        120,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('people-tab')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Mike Chen'));
      await tester.pumpAndSettle();

      final updateButton = find.widgetWithText(FilledButton, 'Update with AI');
      await tester.ensureVisible(updateButton);
      await tester.pumpAndSettle();
      await tester.tap(updateButton);
      await tester.pumpAndSettle();

      expect(find.text('Update with AI'), findsWidgets);
      expect(find.text('Update Mike Chen'), findsOneWidget);
    },
  );
}
