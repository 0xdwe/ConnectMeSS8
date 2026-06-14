import 'package:connect_me/src/app/connect_me_app.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_overrides.dart';

Future<void> _pumpAndSignIn(WidgetTester tester, {required InMemoryMemoryStore memoryStore}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...signedOutDemoOverrides(),
        memoryStoreProvider.overrideWithValue(memoryStore),
      ],
      child: const ConnectMeApp(),
    ),
  );
  await tester.pumpAndSettle();

  // Sign in
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
  testWidgets('Tapping Context History button opens blurred dialog with matching history', (
    tester,
  ) async {
    final memoryStore = InMemoryMemoryStore();
    final memory = MemoryDocument(
      contactId: 'mike',
      displayName: 'Mike Chen',
      lastUpdated: DateTime(2026, 6, 14),
      summary: 'Mike is working on a startup.',
      history: '- 2026-06-01 — Mike Chen got a promotion at his startup.',
      topics: const ['startup'],
      topicSuggestions: [
        TopicSuggestionGroup(
          topic: 'startup',
          lastMentionedAt: DateTime(2026, 6, 1),
          suggestions: const [
            TopicSuggestion(
              kind: TopicSuggestionKind.ask,
              text: 'Ask how the startup is going.',
              context: 'He got a promotion at his startup.',
            ),
          ],
        ),
      ],
    );
    await memoryStore.save(memory);

    await _pumpAndSignIn(tester, memoryStore: memoryStore);

    // Go to People tab
    await tester.tap(find.text('People').last);
    await tester.pumpAndSettle();

    // Scroll to and tap Mike Chen
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
    await tester.tap(
      find
          .ancestor(of: find.text('Mike Chen'), matching: find.byType(InkWell))
          .first,
    );
    await tester.pumpAndSettle();

    // Verify 'startup' topic pill is present
    expect(find.text('startup'), findsOneWidget);

    // Tap 'startup' topic pill to select it
    await tester.tap(find.text('startup'));
    await tester.pumpAndSettle();

    // Verify suggestion and Context header are visible
    expect(find.text('Conversation Starter :'), findsOneWidget);
    expect(find.text('Context :'), findsOneWidget);

    // Verify Icons.open_in_new button is rendered next to Context:
    final openInNewButton = find.byIcon(Icons.open_in_new);
    expect(openInNewButton, findsOneWidget);

    // Tap the open link button
    await tester.tap(openInNewButton);
    await tester.pumpAndSettle();

    // Verify general dialog is opened with correct title and subtitle
    expect(find.text('Context History'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('startup'),
      ),
      findsOneWidget,
    );

    // Verify matched elements from Memory History are shown
    expect(find.text('Memory'), findsOneWidget);
    expect(find.text('Mike Chen got a promotion at his startup.'), findsOneWidget);

    // Tap close button on dialog
    final closeButton = find.byIcon(Icons.close);
    expect(closeButton, findsOneWidget);
    await tester.tap(closeButton);
    await tester.pumpAndSettle();

    // Verify dialog is dismissed
    expect(find.text('Context History'), findsNothing);
  });
}
