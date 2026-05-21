import 'package:connect_me/src/app/connect_me_app.dart';
import 'package:connect_me/src/state/firebase_providers.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Integration coverage for #043: an AI update mentioning known
/// keywords surfaces those topics on the contact profile pill row.
///
/// Same shape as `update_with_ai_test.dart`: sign in via the loaded
/// app shell, navigate via People → Mike Chen → Update with AI, run
/// the AI flow with a keyword-rich input, save, and assert the new
/// pills appear on Mike's profile screen.
Future<void> _pumpAndSignIn(WidgetTester tester) async {
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
  testWidgets(
    'AI update with keyword input drives Conversation Topics pills',
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

      // Pre-update: the seed-pass writes a single category-derived
      // topic for each contact (Mike's category is 'High School', so
      // the seed topic is 'high school'). The static category
      // defaults only apply when memory.topics is empty, so we
      // assert against the seeded shape.
      expect(find.text('high school'), findsOneWidget);

      await tester.tap(find.byKey(const Key('update-with-ai-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('ai-input-field')),
        'Mike got a promotion at his startup.',
      );
      await tester.tap(find.byKey(const Key('run-ai-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pumpAndSettle();

      // Save returns to the profile via the AiUpdateScreen pop. Make
      // sure the pill row is visible — it sits inside the AI Insights
      // card near the top, but scroll into view defensively.
      await tester.ensureVisible(find.text('Conversation Topics'));
      await tester.pumpAndSettle();

      // Memory-derived pills: keyword extraction filled topics with
      // 'promotion' and 'startup' (in keyword-list order). They
      // appear alongside the seeded 'work' topic, all under the cap.
      expect(find.text('promotion'), findsOneWidget);
      expect(find.text('startup'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping a memory-extracted pill with no curated entry shows the templated fallback',
    (tester) async {
      // Coverage for #044: a topic the curated `_topicSuggestions`
      // map does not know about (e.g. 'kindergarten' — it's in the
      // keyword extractor but not in any category's curated map)
      // should drive the three rotating templates with `{topic}`
      // and `{firstName}` slots filled in.
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

      await tester.tap(find.byKey(const Key('update-with-ai-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('ai-input-field')),
        "Mike's kid just started kindergarten last week.",
      );
      await tester.tap(find.byKey(const Key('run-ai-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Conversation Topics'));
      await tester.pumpAndSettle();

      // Pill exists for the memory-extracted topic.
      expect(find.text('kindergarten'), findsOneWidget);

      // Tap the pill to open the suggestions sheet.
      await tester.tap(find.text('kindergarten'));
      await tester.pumpAndSettle();

      // Three templated suggestions, slots filled with the topic and
      // Mike's first name.
      expect(find.text("How's the kindergarten going?"), findsOneWidget);
      expect(
        find.text(
            'Last time you mentioned kindergarten \u2014 anything new?'),
        findsOneWidget,
      );
      expect(
        find.text("Curious how Mike's kindergarten is going."),
        findsOneWidget,
      );
    },
  );
}
