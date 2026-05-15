import 'package:connect_me/src/app/connect_me_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester) async {
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
    expect(find.text('Recommended Action!'), findsOneWidget);
    expect(find.text('AI Insight'), findsOneWidget);
  });

  testWidgets(
    'tapping a recommendation on the recommendations screen opens the contact dashboard',
    (tester) async {
      await _pump(tester);

      await tester.tap(find.text('View All ->'));
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
      expect(find.text('Recommended Action!'), findsOneWidget);
      expect(find.text('AI Insight'), findsOneWidget);
    },
  );
}
