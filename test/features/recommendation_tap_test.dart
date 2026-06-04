import 'package:connect_me/src/app/connect_me_app.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_overrides.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // #052: AuthScreen sign-in routes through firebaseAuthProvider; tests
  // override with MockFirebaseAuth so the demo login resolves.
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...signedOutDemoOverrides(),
        memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
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
    // Pass 2 #034 replaced 'Recommended Action!' / 'AI Insight' with the
    // AI Insights collapsible card using 'AI Insights' (section header)
    // and 'Recommendation' (callout title).
    expect(find.text('AI Insights'), findsOneWidget);
    expect(find.text('Recommendation'), findsOneWidget);
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
