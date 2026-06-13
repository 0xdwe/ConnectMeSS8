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

ProviderContainer _container({InMemoryMemoryStore? store}) {
  final memoryStore = store ?? InMemoryMemoryStore();
  // Pass 4.3 #081: production aiUpdateProvider now constructs
  // LlmAiUpdate which would reach Firebase AI Logic. These tests
  // predate the cutover and rely on MockAiUpdate's deterministic
  // keyword extractor; override the provider to pin Mock as the
  // active adapter and reuse the same memoryStore + AppController
  // the screen reads.
  return ProviderContainer(
    overrides: [
      ...signedInDemoOverrides(),
      memoryStoreProvider.overrideWithValue(memoryStore),
      aiUpdateProvider.overrideWith(
        (ref) => MockAiUpdate(
          memoryStore: memoryStore,
          appController: ref.read(appControllerProvider.notifier),
        ),
      ),
    ],
  );
}

void main() {
  group('AI Update Preview-and-Confirm Flow', () {
    test(
      'AiUpdate.run returns AiUpdateResult without mutating state',
      () async {
        final container = _container();
        addTearDown(container.dispose);

        final beforeInteractions = container
            .read(appControllerProvider)
            .interactions
            .length;
        final beforeConnections = container
            .read(appControllerProvider)
            .connections;
        final beforeSummary = container
            .read(appControllerProvider)
            .lastAiSummary;

        final mike = beforeConnections.firstWhere((c) => c.id == 'mike');
        final memory = await container.read(memoryProvider('mike').future);

        final result = await container
            .read(aiUpdateProvider)
            .run(
              contact: mike,
              userInput:
                  'Had coffee with Mike today. He mentioned his new job.',
              currentMemory: memory,
              attachments: const [],
            );

        final afterState = container.read(appControllerProvider);

        // State should not change.
        expect(afterState.interactions.length, beforeInteractions);
        expect(afterState.connections, beforeConnections);
        expect(afterState.lastAiSummary, beforeSummary);

        // Result should contain parsed data.
        expect(result.interactions, isNotEmpty);
        expect(result.contactId, 'mike');
        expect(result.summary, isNotEmpty);
        expect(result.memoryDocument, isNotNull);
      },
    );

    test('AiUpdate.commit applies preview result to state', () async {
      final container = _container();
      addTearDown(container.dispose);

      final beforeInteractions = container
          .read(appControllerProvider)
          .interactions
          .length;

      final result = AiUpdateResult(
        summary: 'Test summary',
        contactId: 'mike',
        interactions: [
          CrmInteraction(
            id: 'test-interaction',
            contactId: 'mike',
            type: InteractionType.sharedActivity,
            title: 'Coffee chat',
            note: 'Discussed new job',
            date: DateTime(2026, 5, 15),
            source: InteractionSource.aiSuggested,
          ),
        ],
        nextStep: 'Follow up next week',
      );

      await container.read(aiUpdateProvider).commit(result);

      final afterState = container.read(appControllerProvider);

      // State should be updated.
      expect(afterState.interactions.length, beforeInteractions + 1);
      expect(afterState.interactions.first.id, 'test-interaction');
      expect(
        afterState.interactions.first.source,
        InteractionSource.aiSuggested,
      );
      expect(afterState.lastAiSummary, 'Test summary');

      // Contact should be updated.
      final mike = afterState.connections.firstWhere((c) => c.id == 'mike');
      expect(mike.nextStep, 'Follow up next week');
      expect(mike.bondScore, 68); // No explicit bondScoreDelta supplied.
    });

    test(
      'AiUpdate.commit with edited interactions preserves user changes',
      () async {
        final container = _container();
        addTearDown(container.dispose);

        final result = AiUpdateResult(
          summary: 'Test summary',
          contactId: 'sarah',
          interactions: [
            CrmInteraction(
              id: 'edited-interaction',
              contactId: 'sarah',
              type: InteractionType.sharedActivity,
              title: 'User edited this title',
              note: 'User edited this note',
              date: DateTime(2026, 5, 14),
              source: InteractionSource.aiSuggested,
            ),
          ],
        );

        await container.read(aiUpdateProvider).commit(result);

        final afterState = container.read(appControllerProvider);
        final interaction = afterState.interactions.first;

        expect(interaction.title, 'User edited this title');
        expect(interaction.note, 'User edited this note');
        expect(interaction.date, DateTime(2026, 5, 14));
      },
    );

    test(
      'AI-suggested interactions are marked with aiSuggested source',
      () async {
        final container = _container();
        addTearDown(container.dispose);

        final emily = container
            .read(appControllerProvider)
            .connections
            .firstWhere((c) => c.id == 'emily');
        final memory = await container.read(memoryProvider('emily').future);

        final result = await container
            .read(aiUpdateProvider)
            .run(
              contact: emily,
              userInput: 'Reminder to ask Emily about her first week',
              currentMemory: memory,
              attachments: const [],
            );

        // Run should mark interactions as AI-suggested.
        expect(result.interactions.first.source, InteractionSource.aiSuggested);
      },
    );

    test('manual interactions retain manual source', () {
      final container = _container();
      addTearDown(container.dispose);

      container
          .read(appControllerProvider.notifier)
          .logInteraction(
            'david',
            InteractionType.relationshipNote,
            'Manual note',
            'This was typed manually',
          );

      final state = container.read(appControllerProvider);
      expect(state.interactions.first.source, InteractionSource.manual);
    });

    test('commit persists the memory document via MemoryStore', () async {
      final store = InMemoryMemoryStore();
      final container = _container(store: store);
      addTearDown(container.dispose);

      final mike = container
          .read(appControllerProvider)
          .connections
          .firstWhere((c) => c.id == 'mike');
      final memory = await container.read(memoryProvider('mike').future);

      final result = await container
          .read(aiUpdateProvider)
          .run(
            contact: mike,
            userInput: 'Had coffee with Mike yesterday',
            currentMemory: memory,
            attachments: const [],
          );

      // Pre-commit, the memory in the store has no history bullet.
      final preCommit = await store.load('mike');
      expect(preCommit, isNotNull);
      expect(preCommit!.history, isEmpty);

      await container.read(aiUpdateProvider).commit(result);

      final postCommit = await store.load('mike');
      expect(postCommit, isNotNull);
      expect(postCommit!.history, contains('Had coffee with Mike yesterday'));
    });

    test('cancel discards both interactions and memory append', () async {
      final store = InMemoryMemoryStore();
      final container = _container(store: store);
      addTearDown(container.dispose);

      final beforeInteractions = container
          .read(appControllerProvider)
          .interactions
          .length;

      final mike = container
          .read(appControllerProvider)
          .connections
          .firstWhere((c) => c.id == 'mike');
      final memory = await container.read(memoryProvider('mike').future);
      final preHistory = memory.history;

      // Run produces a candidate result, but commit is never called.
      await container
          .read(aiUpdateProvider)
          .run(
            contact: mike,
            userInput: 'Cancelled before save',
            currentMemory: memory,
            attachments: const [],
          );

      // Neither state nor store have moved.
      final afterState = container.read(appControllerProvider);
      expect(afterState.interactions.length, beforeInteractions);

      final stored = await store.load('mike');
      expect(stored?.history ?? '', preHistory);
    });

    testWidgets('preview-and-save preserves bondScoreDelta end-to-end '
        '(Pass 4.3 #085 stall regression, 2026-06-01)', (tester) async {
      // The 2026-06-01 stall report had LlmAiUpdate emit
      // bondScoreDelta=23 but applyAiUpdateResult log delta=0.
      // Root cause: AiUpdateScreen.save() rebuilds AiUpdateResult
      // from the preview without forwarding bondScoreDelta, so the
      // constructor's default of 0 takes over. This test pumps the
      // full preview-then-save flow with MockAiUpdate (whose run
      // populates bondScoreDelta via applyBondScoreCurve) and
      // asserts the contact's bondScore actually moved by the
      // curve's output, not 0.
      final store = InMemoryMemoryStore();
      final container = _container(store: store);
      addTearDown(container.dispose);

      // Mike's seed bond is 68; MockAiUpdate uses depth=50, so the
      // expected delta is floor(50 * 32 / 160) = 10.
      final priorBond = container
          .read(appControllerProvider)
          .connections
          .firstWhere((c) => c.id == 'mike')
          .bondScore;
      expect(priorBond, 68, reason: 'seed sanity');

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

      await tester.enterText(
        find.byKey(const Key('ai-input-field')),
        'Caught up over coffee, talked about the new job.',
      );
      await tester.tap(find.byKey(const Key('run-ai-button')));
      await tester.pumpAndSettle();

      // Save through the preview path — this is the surface that
      // rebuilds AiUpdateResult and historically dropped the field.
      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pumpAndSettle();

      final after = container
          .read(appControllerProvider)
          .connections
          .firstWhere((c) => c.id == 'mike');
      expect(
        after.bondScore,
        priorBond + 10,
        reason:
            'preview-then-save must forward bondScoreDelta from the '
            'run() result through to applyAiUpdateResult; the curve '
            'produced +10 for Mike (bond=68, depth=50) and the score '
            'must reflect it.',
      );
    });
  });

  group('AI Update Preview "About <Name>" memory delta section', () {
    Future<void> pumpScreenAndSubmit(
      WidgetTester tester,
      ProviderContainer container, {
      required String input,
      String contactId = 'mike',
      bool disableAnimations = false,
    }) async {
      Widget app = UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.data(false),
          home: AiUpdateScreen(
            contactId: contactId,
            initialAttachments: const [],
          ),
        ),
      );
      if (disableAnimations) {
        app = MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: app,
        );
      }
      await tester.pumpWidget(app);
      await tester.enterText(find.byKey(const Key('ai-input-field')), input);
      await tester.tap(find.byKey(const Key('run-ai-button')));
      await tester.pump(); // Start generating
      await tester.pump(const Duration(milliseconds: 100)); // AI completes
      await tester.pump(); // Render preview at t=0
    }

    testWidgets(
      'preview shows About <Name> section with newly extracted topics',
      (tester) async {
        final container = _container();
        addTearDown(container.dispose);

        await pumpScreenAndSubmit(
          tester,
          container,
          // 'promotion' is in the mock topic-keyword list and is NOT in
          // mike's seeded starter topics, so the run produces it as a
          // newly-extracted topic.
          input: 'Mike got a big promotion at work today.',
        );
        // Allow the staggered controllers (interactions + delta card) to
        // finish so the section is fully rendered.
        await tester.pumpAndSettle();

        // Header copy.
        expect(find.text('About Mike Chen'), findsOneWidget);
        // Card key.
        expect(find.byKey(const Key('memory-delta-card')), findsOneWidget);
        // The newly-extracted topic chip is rendered.
        expect(
          find.byKey(const Key('memory-delta-topic-promotion')),
          findsOneWidget,
        );
      },
    );

    testWidgets('memory delta section announces correct semantic label', (
      tester,
    ) async {
      final container = _container();
      addTearDown(container.dispose);

      await pumpScreenAndSubmit(
        tester,
        container,
        input: 'Mike got a big promotion at work today.',
      );
      await tester.pumpAndSettle();

      // Header semantic announces "About <Name>, AI suggested".
      // The merged semantics label includes child text after the
      // header label, so use a regex prefix match.
      final semanticsHandle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(RegExp(r'^About Mike Chen, AI suggested')),
        findsOneWidget,
      );
      // Each new-topic chip announces "<topic>, newly added".
      expect(
        find.bySemanticsLabel(RegExp(r'promotion, newly added')),
        findsWidgets,
      );
      semanticsHandle.dispose();
    });

    testWidgets('cancel removes the memory delta section from the preview', (
      tester,
    ) async {
      final container = _container();
      addTearDown(container.dispose);

      await pumpScreenAndSubmit(
        tester,
        container,
        input: 'Mike got a big promotion at work today.',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('memory-delta-card')), findsOneWidget);

      await tester.tap(find.byKey(const Key('cancel-button')));
      await tester.pumpAndSettle();

      // Returned to the input view; delta is gone.
      expect(find.byKey(const Key('memory-delta-card')), findsNothing);
      expect(find.byKey(const Key('ai-input-field')), findsOneWidget);
    });

    testWidgets('cancel leaves memoryProvider unchanged', (tester) async {
      final store = InMemoryMemoryStore();
      final container = _container(store: store);
      addTearDown(container.dispose);

      // Read pre-run memory once so the lazy-create path runs and the
      // store is populated with the empty doc.
      final preMemory = await container.read(memoryProvider('mike').future);

      await pumpScreenAndSubmit(
        tester,
        container,
        input: 'Mike got a big promotion at work today.',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cancel-button')));
      await tester.pumpAndSettle();

      final afterCancel = await store.load('mike');
      expect(afterCancel, isNotNull);
      expect(afterCancel!.history, preMemory.history);
      expect(afterCancel.topics, preMemory.topics);
    });

    testWidgets(
      'reduce motion: memory delta card visible at full opacity immediately',
      (tester) async {
        final container = _container();
        addTearDown(container.dispose);

        await pumpScreenAndSubmit(
          tester,
          container,
          input: 'Mike got a big promotion at work today.',
          disableAnimations: true,
        );
        // No pumpAndSettle — reduce motion should set the controllers
        // to 1.0 on the first preview frame.
        final card = find.byKey(const Key('memory-delta-card'));
        expect(card, findsOneWidget);
        final opacity = tester.widget<Opacity>(
          find.ancestor(of: card, matching: find.byType(Opacity)).first,
        );
        expect(opacity.opacity, 1.0);
      },
    );

    testWidgets(
      'preview suppresses memory delta when no topic or history additions',
      (tester) async {
        final container = _container();
        addTearDown(container.dispose);

        // Override aiUpdateProvider with a stub that returns a result
        // whose memoryDocument is identical to the pre-run memory — no
        // new topics, no new history bullet — to force the empty-
        // additions edge case.
        final stubContainer = ProviderContainer(
          overrides: [
            ...signedInDemoOverrides(),
            memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
            aiUpdateProvider.overrideWith((ref) => _NoDeltaAiUpdate()),
          ],
        );
        addTearDown(stubContainer.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: stubContainer,
            child: MaterialApp(
              theme: AppTheme.data(false),
              home: const AiUpdateScreen(
                contactId: 'mike',
                initialAttachments: [],
              ),
            ),
          ),
        );

        await tester.enterText(
          find.byKey(const Key('ai-input-field')),
          'Anything',
        );
        await tester.tap(find.byKey(const Key('run-ai-button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // An interaction card still renders, but the memory delta does
        // not.
        expect(find.byKey(const Key('preview-card-0')), findsOneWidget);
        expect(find.byKey(const Key('memory-delta-card')), findsNothing);
      },
    );

    testWidgets(
      'commit failure surfaces a snackbar and leaves memory + interactions unchanged',
      (tester) async {
        // PRD Q4 / #046 — the user-visible expression of the
        // all-or-nothing contract on the AI Update screen. A forced
        // commit failure must not log an interaction or persist
        // memory; the user sees a retryable error.
        final store = InMemoryMemoryStore();
        final container = ProviderContainer(
          overrides: [
            ...signedInDemoOverrides(),
            memoryStoreProvider.overrideWithValue(store),
            aiUpdateProvider.overrideWith(
              (ref) => MockAiUpdate(
                memoryStore: ref.watch(memoryStoreProvider),
                appController: ref.read(appControllerProvider.notifier),
                failOnSave: true,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Drive the seed pass so memory mirrors the seed shape.
        await container.read(memorySeedingProvider.future);

        final priorMemory = await store.load('mike');
        final priorInteractionCount = container
            .read(appControllerProvider)
            .interactions
            .length;

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

        await tester.enterText(
          find.byKey(const Key('ai-input-field')),
          'Mike got a promotion',
        );
        await tester.tap(find.byKey(const Key('run-ai-button')));
        await tester.pumpAndSettle();

        // Hit Save — commit() throws on the save step.
        await tester.tap(find.byKey(const Key('save-button')));
        await tester.pumpAndSettle();

        // Snackbar surfaces.
        expect(find.textContaining("Couldn't save update"), findsOneWidget);
        // Preview view stays — the screen did NOT pop.
        expect(find.byKey(const Key('save-button')), findsOneWidget);
        // Memory unchanged.
        final afterMemory = await store.load('mike');
        expect(afterMemory!.history, priorMemory!.history);
        expect(afterMemory.topics, priorMemory.topics);
        // Interactions unchanged.
        expect(
          container.read(appControllerProvider).interactions.length,
          priorInteractionCount,
        );
      },
    );
  });
}

/// Stub adapter whose `run` returns a result with `memoryDocument`
/// equal to the pre-run memory — used to force the empty-additions
/// edge case in [_buildPreviewView].
class _NoDeltaAiUpdate implements AiUpdate {
  @override
  Future<AiUpdateResult> run({
    required Connection contact,
    required String userInput,
    required MemoryDocument currentMemory,
    required List<AttachmentRef> attachments,
    Future<void>? cancelToken,
  }) async {
    return AiUpdateResult(
      summary: 'No-op',
      contactId: contact.id,
      interactions: [
        CrmInteraction(
          id: 'noop-interaction',
          contactId: contact.id,
          type: InteractionType.interaction,
          title: 'Stub interaction',
          note: userInput,
          date: DateTime(2026, 5, 19),
          source: InteractionSource.aiSuggested,
        ),
      ],
      // Same doc as the pre-run memory — no new topics, no new bullet.
      memoryDocument: currentMemory,
    );
  }

  @override
  Future<void> commit(AiUpdateResult result) async {}
}
