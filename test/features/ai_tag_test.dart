import 'package:connect_me/src/ai/ai_update.dart';
import 'package:connect_me/src/app/connect_me_app.dart';
import 'package:connect_me/src/state/app_state.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_overrides.dart';

Widget _bootedApp() {
  final memoryStore = InMemoryMemoryStore();
  return ProviderScope(
    overrides: [
      ...signedInDemoOverrides(),
      memoryStoreProvider.overrideWithValue(memoryStore),
      aiUpdateProvider.overrideWith(
        (ref) => MockAiUpdate(
          memoryStore: memoryStore,
          appController: ref.read(appControllerProvider.notifier),
        ),
      ),
    ].cast(),
    child: const ConnectMeApp(),
  );
}

Future<void> _pumpAndSignIn(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_bootedApp());
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
  testWidgets('AI-suggested interactions show AI tag in contact profile', (
    tester,
  ) async {
    await _pumpAndSignIn(tester);

    // Navigate to Mike's profile
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

    // Use AI update to add an interaction
    await tester.tap(find.byKey(const Key('update-with-ai-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('ai-input-field')),
      'Had coffee with Mike today',
    );
    await tester.tap(find.byKey(const Key('run-ai-button')));
    await tester.pumpAndSettle();

    // Save the preview
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    // Should be back on profile, verify AI tag appears in history below
    // the AI Insights card. Scroll until the badge is visible.
    await tester.scrollUntilVisible(
      find.text('AI'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('AI'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsWidgets);
  });

  testWidgets('manual interactions do not show AI tag', (tester) async {
    await tester.pumpWidget(_bootedApp());
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

    // Navigate to Sarah's profile
    await tester.tap(find.text('People').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Sarah Johnson'),
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('people-tab')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Sarah Johnson'));
    await tester.pumpAndSettle();

    // Seeded interactions default to manual source, so they should not have AI tags
    // Before we add any AI interactions, there should be no AI tags on the profile
    final aiTagsBeforeAiUpdate = find.text('AI');
    expect(aiTagsBeforeAiUpdate, findsNothing);
  });
}
