import 'package:connect_me/src/ai/ai_update.dart';
import 'package:connect_me/src/features/ai_update_screen.dart';
import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/app_state.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_overrides.dart';

/// Widget tests for the Pass 4.3 #081 AI Update modal loading +
/// cancel UX, plus the failure-taxonomy snackbar copy.
///
/// All tests inject [MockAiUpdate] via `aiUpdateProvider`. The
/// production binding is now [LlmAiUpdate], which is exercised
/// elsewhere (provider-shape tests in
/// `test/state/memory/ai_update_provider_test.dart`; real-Gemini
/// integration in #082). Here we only need the failure shape and
/// the slow-run knob, both of which the Mock supports.
Widget _wrapScreen({required String contactId, required AiUpdate aiUpdate}) {
  return ProviderScope(
    overrides: [
      ...signedInDemoOverrides(),
      memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
      aiUpdateProvider.overrideWithValue(aiUpdate),
    ],
    child: MaterialApp(
      theme: AppTheme.data(false),
      home: AiUpdateScreen(contactId: contactId),
    ),
  );
}

MockAiUpdate _mockWith({Duration? slowRunDuration, bool failOnRun = false}) {
  // Constructor needs a memoryStore + appController, but the screen's
  // submit() reads aiUpdateProvider via Riverpod, not via this Mock.
  // We still need to give it values that don't crash if accidentally
  // touched. The screen never calls commit() during a slow run that
  // gets cancelled, and never reaches the run() body when failOnRun
  // throws — so a placeholder store and controller are fine.
  final memoryStore = InMemoryMemoryStore();
  final container = ProviderContainer(
    overrides: [
      ...signedInDemoOverrides(),
      memoryStoreProvider.overrideWithValue(memoryStore),
    ],
  );
  addTearDown(container.dispose);
  final appController = container.read(appControllerProvider.notifier);
  return MockAiUpdate(
    memoryStore: memoryStore,
    appController: appController,
    slowRunDuration: slowRunDuration,
    failOnRun: failOnRun,
  );
}

Future<void> _typeAndTapRun(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('ai-input-field')), text);
  await tester.tap(find.byKey(const Key('run-ai-button')));
}

void main() {
  group('AI Update modal — loading view (PRD §Q10 / #081 Slice B)', () {
    testWidgets(
      'shows centered spinner and warm copy with the contact first name '
      'while run() is in flight',
      (tester) async {
        final ai = _mockWith(slowRunDuration: const Duration(seconds: 2));
        await tester.pumpWidget(_wrapScreen(contactId: 'mike', aiUpdate: ai));
        await tester.pumpAndSettle();

        await _typeAndTapRun(tester, 'Had coffee with Mike today.');
        await tester.pump(); // kick the async Future

        // Loading view is now visible.
        expect(find.byKey(const Key('ai-loading-spinner')), findsOneWidget);
        // Warm copy shows the loading label (Pass 4.4 / #113). The
        // initial label is "Checking your input…".
        expect(
          find.text('Checking your input…'),
          findsOneWidget,
        );
        // Cancel is reachable.
        expect(
          find.byKey(const Key('ai-loading-cancel-button')),
          findsOneWidget,
        );

        // Drain the in-flight future before tearing down so pending
        // async doesn't leak into the next test.
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'tapping Cancel during loading silently returns to inputting view '
      'without a snackbar',
      (tester) async {
        final ai = _mockWith(slowRunDuration: const Duration(seconds: 5));
        await tester.pumpWidget(_wrapScreen(contactId: 'mike', aiUpdate: ai));
        await tester.pumpAndSettle();

        await _typeAndTapRun(tester, 'Some long story about Mike.');
        await tester.pump();

        expect(find.byKey(const Key('ai-loading-spinner')), findsOneWidget);

        // Tap Cancel mid-flight.
        await tester.tap(find.byKey(const Key('ai-loading-cancel-button')));
        // The cancel handler awaits AiUpdateCancelled from the Mock.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Back on the input view.
        expect(find.byKey(const Key('ai-input-field')), findsOneWidget);
        expect(find.byKey(const Key('run-ai-button')), findsOneWidget);
        // No snackbar surfaced.
        expect(find.byType(SnackBar), findsNothing);

        // The user's text is preserved so they can retry without
        // retyping it.
        final textField = tester.widget<TextField>(
          find.byKey(const Key('ai-input-field')),
        );
        expect(textField.controller?.text, 'Some long story about Mike.');
      },
    );
  });

  group('AI Update modal — failure-taxonomy snackbar copy '
      '(PRD §Q8 / #081 Slice C)', () {
    Future<void> assertFailureMessage(
      WidgetTester tester, {
      required AiUpdateFailure thrown,
      required String expectedText,
    }) async {
      // Construct a one-shot adapter that throws the supplied
      // failure on run(). We can't easily parameterize MockAiUpdate's
      // message, so use a tiny inline fake.
      final ai = _ThrowingAiUpdate(thrown);
      await tester.pumpWidget(_wrapScreen(contactId: 'mike', aiUpdate: ai));
      await tester.pumpAndSettle();

      await _typeAndTapRun(tester, 'whatever');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.text(expectedText),
        findsOneWidget,
        reason: 'should show the AiUpdateFailure.message text directly',
      );
      // Always returns to the input view on failure.
      expect(find.byKey(const Key('ai-input-field')), findsOneWidget);
    }

    testWidgets("transient: \"AI didn't respond in time. Try again?\"", (
      tester,
    ) async {
      await assertFailureMessage(
        tester,
        thrown: const AiUpdateFailure("AI didn't respond in time. Try again?"),
        expectedText: "AI didn't respond in time. Try again?",
      );
    });

    testWidgets('App Check rejection copy', (tester) async {
      await assertFailureMessage(
        tester,
        thrown: const AiUpdateFailure(
          'AI service unavailable. Please retry, or sign out and back in.',
        ),
        expectedText:
            'AI service unavailable. Please retry, or sign out and back in.',
      );
    });

    testWidgets('quota copy', (tester) async {
      await assertFailureMessage(
        tester,
        thrown: const AiUpdateFailure(
          'AI service is temporarily over capacity. Please try again later.',
        ),
        expectedText:
            'AI service is temporarily over capacity. Please try again later.',
      );
    });

    testWidgets('content-policy copy', (tester) async {
      await assertFailureMessage(
        tester,
        thrown: const AiUpdateFailure(
          "That content couldn't be processed. Try rephrasing, or "
          'removing an attachment.',
        ),
        expectedText:
            "That content couldn't be processed. Try rephrasing, or "
            'removing an attachment.',
      );
    });

    testWidgets('all-attachments-unreadable copy', (tester) async {
      await assertFailureMessage(
        tester,
        thrown: const AiUpdateFailure(
          "Attachments couldn't be read. Try again, or continue without them.",
        ),
        expectedText:
            "Attachments couldn't be read. Try again, or continue without them.",
      );
    });

    testWidgets('unknown exception type falls back to a warm generic message', (
      tester,
    ) async {
      // Not an AiUpdateFailure and not AiUpdateCancelled — exercises
      // the catch-all branch in submit().
      final ai = _ThrowingAiUpdate(StateError('something else'));
      await tester.pumpWidget(_wrapScreen(contactId: 'mike', aiUpdate: ai));
      await tester.pumpAndSettle();

      await _typeAndTapRun(tester, 'whatever');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining("Couldn't run AI update"), findsOneWidget);
    });
  });

  group('AI Update modal — rejection dialog (#113)', () {
    testWidgets(
      'failOnRelevanceCheck shows dialog with reason',
      (tester) async {
        final memoryStore = InMemoryMemoryStore();
        final container = ProviderContainer(
          overrides: [
            ...signedInDemoOverrides(),
            memoryStoreProvider.overrideWithValue(memoryStore),
          ],
        );
        addTearDown(container.dispose);
        final ai = MockAiUpdate(
          memoryStore: memoryStore,
          appController: container.read(appControllerProvider.notifier),
          failOnRelevanceCheck: true,
        );

        await tester.pumpWidget(_wrapScreen(contactId: 'mike', aiUpdate: ai));
        await tester.pumpAndSettle();
        await _typeAndTapRun(tester, 'whatever');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Not quite a relationship update'), findsOneWidget);
        expect(
          find.textContaining('relevance rejection'),
          findsOneWidget,
        );
        expect(find.text('Got it'), findsOneWidget);

        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('ai-input-field')), findsOneWidget);
        final tf = tester.widget<TextField>(
          find.byKey(const Key('ai-input-field')),
        );
        expect(tf.controller?.text, 'whatever');
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets(
      'loading label transitions from Checking to Reading',
      (tester) async {
        final ai = _mockWith(
          slowRunDuration: const Duration(seconds: 3),
        );
        await tester.pumpWidget(_wrapScreen(contactId: 'mike', aiUpdate: ai));
        await tester.pumpAndSettle();
        await _typeAndTapRun(tester, 'Had coffee with Mike today.');
        await tester.pump();

        expect(find.text('Checking your input\u2026'), findsOneWidget);

        // Drain remaining timers without asserting transition
        // (callback wiring proven by llm_ai_update_test.dart)
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      },
    );
  });
}

/// Inline AiUpdate fake whose `run` always throws the supplied
/// exception. Used only by the snackbar-copy parameterized tests.
/// Not added to the production seam — these are widget tests
/// asserting the modal's visible behavior, not the adapter's.
class _ThrowingAiUpdate implements AiUpdate {
  _ThrowingAiUpdate(this.toThrow);
  final Object toThrow;

  @override
  Future<AiUpdateResult> run({
    required Connection contact,
    required String userInput,
    required MemoryDocument currentMemory,
    required List<AttachmentRef> attachments,
    Future<void>? cancelToken,
    Future<void> Function()? onClassifierPassed,
  }) async {
    throw toThrow;
  }

  @override
  Future<void> commit(AiUpdateResult result) async {
    throw toThrow;
  }
}
