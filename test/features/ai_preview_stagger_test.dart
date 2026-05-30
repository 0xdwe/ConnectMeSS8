import 'package:connect_me/src/ai/ai_update.dart';
import 'package:connect_me/src/features/ai_update_screen.dart';
import '../test_overrides.dart';
import 'package:connect_me/src/state/app_state.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #042: AiUpdateScreen now reads `memoryProvider(contactId).future`
/// before running AI. Override `memoryStoreProvider` so widget tests
/// don't stall on real disk I/O via the production `FileMemoryStore`.
ProviderContainer _container() {
  final memoryStore = InMemoryMemoryStore();
  // Pass 4.3 #081: production aiUpdateProvider now constructs
  // LlmAiUpdate; these tests rely on MockAiUpdate's deterministic
  // append behavior so the stagger fixture is stable.
  return ProviderContainer(overrides: [
    ...signedInDemoOverrides(),
    memoryStoreProvider.overrideWithValue(memoryStore),
    aiUpdateProvider.overrideWith(
      (ref) => MockAiUpdate(
        memoryStore: memoryStore,
        appController: ref.read(appControllerProvider.notifier),
      ),
    ),
  ]);
}

void main() {
  group('AI Preview Stagger Animation', () {
    testWidgets('first card starts with low opacity and fades in', (tester) async {
      final container = _container();
      addTearDown(container.dispose);

      // Build the screen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.data(false),
            home: const AiUpdateScreen(
              contactId: 'mike',
              initialAttachments: [],
            ),
          ),
        ),
      );

      // Trigger preview by submitting
      await tester.enterText(find.byKey(const Key('ai-input-field')), 'Had coffee with Mike today.');
      await tester.tap(find.byKey(const Key('run-ai-button')));
      await tester.pump(); // Start generating
      await tester.pump(const Duration(milliseconds: 100)); // Allow AI service to complete
      await tester.pump(); // Render preview with animation at t=0

      // At frame 0, first card should have low opacity (0 or close to 0)
      final firstCard = find.byKey(const Key('preview-card-0'));
      expect(firstCard, findsOneWidget);

      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: firstCard,
          matching: find.byType(Opacity),
        ).first,
      );
      expect(opacity.opacity, lessThan(0.1));

      // Advance animation by 240ms
      await tester.pump(const Duration(milliseconds: 240));
      final opacityAfter = tester.widget<Opacity>(
        find.ancestor(
          of: firstCard,
          matching: find.byType(Opacity),
        ).first,
      );
      expect(opacityAfter.opacity, closeTo(1.0, 0.05));
    });

    testWidgets('cards stagger by 80ms per index', (tester) async {
      final container = _container();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.data(false),
            home: const AiUpdateScreen(
              contactId: 'mike',
              initialAttachments: [],
            ),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('ai-input-field')), 'Had coffee with Mike. Discussed his job. Reminder to follow up.');
      await tester.tap(find.byKey(const Key('run-ai-button')));
      await tester.pump(); // Start generating
      await tester.pump(const Duration(milliseconds: 100)); // Allow AI service to complete
      await tester.pump(); // Render preview with animation at t=0

      // At 0ms: card 0 animating, card 1 and 2 not started
      final card0 = find.byKey(const Key('preview-card-0'));
      final card1 = find.byKey(const Key('preview-card-1'));

      if (card1.evaluate().isNotEmpty) {
        final opacity1 = tester.widget<Opacity>(
          find.ancestor(of: card1, matching: find.byType(Opacity)).first,
        );
        expect(opacity1.opacity, lessThan(0.1));
      }

      // At 80ms: card 0 mid-animation, card 1 starting, card 2 not started
      await tester.pump(const Duration(milliseconds: 80));
      if (card1.evaluate().isNotEmpty) {
        final opacity1After = tester.widget<Opacity>(
          find.ancestor(of: card1, matching: find.byType(Opacity)).first,
        );
        expect(opacity1After.opacity, lessThan(0.5)); // Just starting
      }

      // At 320ms total: all cards should be visible (240ms + 80ms stagger for last card)
      await tester.pump(const Duration(milliseconds: 240));
      final opacity0Final = tester.widget<Opacity>(
        find.ancestor(of: card0, matching: find.byType(Opacity)).first,
      );
      expect(opacity0Final.opacity, closeTo(1.0, 0.05));

      if (card1.evaluate().isNotEmpty) {
        final opacity1Final = tester.widget<Opacity>(
          find.ancestor(of: card1, matching: find.byType(Opacity)).first,
        );
        expect(opacity1Final.opacity, closeTo(1.0, 0.05));
      }
    });

    testWidgets('cards translate from 8px down to 0', (tester) async {
      final container = _container();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.data(false),
            home: const AiUpdateScreen(
              contactId: 'mike',
              initialAttachments: [],
            ),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('ai-input-field')), 'Had coffee with Mike today.');
      await tester.tap(find.byKey(const Key('run-ai-button')));
      await tester.pump(); // Start generating
      await tester.pump(const Duration(milliseconds: 100)); // Allow AI service to complete
      await tester.pump(); // Render preview with animation at t=0

      // Find Transform widget - get the first one which is our animation transform
      final firstCard = find.byKey(const Key('preview-card-0'));
      final transforms = find.ancestor(
        of: firstCard,
        matching: find.byType(Transform),
      );
      expect(transforms, findsWidgets);

      // Get the first transform (our animation transform)
      final transformWidget = tester.widgetList<Transform>(transforms).first;
      final matrix = transformWidget.transform;
      expect(matrix.getTranslation().y, greaterThan(0));

      // Advance animation by 240ms
      await tester.pump(const Duration(milliseconds: 240));
      final transformAfter = tester.widgetList<Transform>(transforms).first;
      final matrixAfter = transformAfter.transform;
      expect(matrixAfter.getTranslation().y, closeTo(0, 0.1));
    });

    testWidgets('reduce motion: all cards render at full opacity immediately', (tester) async {
      final container = _container();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              theme: AppTheme.data(false),
              home: const AiUpdateScreen(
                contactId: 'mike',
                initialAttachments: [],
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('ai-input-field')), 'Had coffee with Mike. Discussed his job. Reminder to follow up.');
      await tester.tap(find.byKey(const Key('run-ai-button')));
      await tester.pump(); // Start generating
      await tester.pump(const Duration(milliseconds: 100)); // Allow AI service to complete
      await tester.pump(); // Render preview

      // All cards should be at full opacity immediately
      final card0 = find.byKey(const Key('preview-card-0'));
      final card1 = find.byKey(const Key('preview-card-1'));
      final card2 = find.byKey(const Key('preview-card-2'));

      expect(card0, findsOneWidget);

      // Check opacity is 1.0 from the start
      final opacity0 = tester.widget<Opacity>(
        find.ancestor(of: card0, matching: find.byType(Opacity)).first,
      );
      expect(opacity0.opacity, 1.0);

      if (card1.evaluate().isNotEmpty) {
        final opacity1 = tester.widget<Opacity>(
          find.ancestor(of: card1, matching: find.byType(Opacity)).first,
        );
        expect(opacity1.opacity, 1.0);
      }

      if (card2.evaluate().isNotEmpty) {
        final opacity2 = tester.widget<Opacity>(
          find.ancestor(of: card2, matching: find.byType(Opacity)).first,
        );
        expect(opacity2.opacity, 1.0);
      }

      // Transform should also be at final position (no offset)
      final transforms = find.ancestor(
        of: card0,
        matching: find.byType(Transform),
      );
      if (transforms.evaluate().isNotEmpty) {
        final transformWidget = tester.widgetList<Transform>(transforms).first;
        final matrix = transformWidget.transform;
        expect(matrix.getTranslation().y, 0);
      }
    });
  });
}
