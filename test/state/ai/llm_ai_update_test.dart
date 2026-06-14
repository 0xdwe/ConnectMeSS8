import 'dart:async';

import 'package:connect_me/src/ai/ai_update.dart';
import 'package:connect_me/src/ai/attachment_preparer.dart';
import 'package:connect_me/src/ai/bond_score_curve.dart';
import 'package:connect_me/src/ai/llm_ai_update.dart';
import 'package:connect_me/src/ai/llm_ai_update_response.dart';
import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/app_state.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_overrides.dart';

/// Failure-path tests for [LlmAiUpdate].
///
/// Per PRD §Q10 these tests use the adapter's own injection knobs
/// (`failOnNetwork`, `failOnQuota`, `failOnContentPolicy`,
/// `cancelMidRun`, `failOnSave`, `failOnApply`) rather than a fake
/// `FirebaseAI` SDK handle. Knobs short-circuit before any SDK
/// access so the tests are deterministic, headless, and free.
///
/// Real-Gemini formatting and live-API tests live under
/// `integration_test/state/ai/` (#082) gated behind
/// `--dart-define=RUN_GEMINI_TESTS=1`.

ProviderContainer _container({InMemoryMemoryStore? store}) {
  final memoryStore = store ?? InMemoryMemoryStore();
  return ProviderContainer(
    overrides: [
      ...signedInDemoOverrides(),
      memoryStoreProvider.overrideWithValue(memoryStore),
    ],
  );
}

LlmAiUpdate _adapter(
  ProviderContainer container, {
  bool failOnNetwork = false,
  bool failOnQuota = false,
  bool failOnContentPolicy = false,
  bool failOnAppCheck = false,
  bool cancelMidRun = false,
  bool failOnSave = false,
  bool failOnApply = false,
}) {
  return LlmAiUpdate(
    firebaseAi: null,
    memoryStore: container.read(memoryStoreProvider),
    appController: container.read(appControllerProvider.notifier),
    recentInteractionsLookup: (contactId) => container
        .read(appControllerProvider)
        .interactions
        .where((i) => i.contactId == contactId)
        .toList(),
    failOnNetwork: failOnNetwork,
    failOnQuota: failOnQuota,
    failOnContentPolicy: failOnContentPolicy,
    failOnAppCheck: failOnAppCheck,
    cancelMidRun: cancelMidRun,
    failOnSave: failOnSave,
    failOnApply: failOnApply,
  );
}

Connection _connection(AppState state, String id) =>
    state.connections.firstWhere((c) => c.id == id);

void main() {
  group('LlmAiUpdate.run — failure-path injection', () {
    test('cancelMidRun throws AiUpdateCancelled before any SDK call', () async {
      final container = _container();
      addTearDown(container.dispose);
      final adapter = _adapter(container, cancelMidRun: true);

      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      final memory = await container.read(memoryProvider('sarah').future);

      await expectLater(
        () => adapter.run(
          contact: sarah,
          userInput: 'anything',
          currentMemory: memory,
          attachments: const [],
        ),
        throwsA(isA<AiUpdateCancelled>()),
      );
    });

    test(
      'failOnNetwork throws AiUpdateFailure with retry-friendly copy',
      () async {
        final container = _container();
        addTearDown(container.dispose);
        final adapter = _adapter(container, failOnNetwork: true);
        final sarah = _connection(
          container.read(appControllerProvider),
          'sarah',
        );
        final memory = await container.read(memoryProvider('sarah').future);

        await expectLater(
          () => adapter.run(
            contact: sarah,
            userInput: 'anything',
            currentMemory: memory,
            attachments: const [],
          ),
          throwsA(
            isA<AiUpdateFailure>().having(
              (e) => e.message.toLowerCase(),
              'message',
              contains('try again'),
            ),
          ),
        );
      },
    );

    test('failOnQuota throws AiUpdateFailure with capacity copy', () async {
      final container = _container();
      addTearDown(container.dispose);
      final adapter = _adapter(container, failOnQuota: true);
      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      final memory = await container.read(memoryProvider('sarah').future);

      await expectLater(
        () => adapter.run(
          contact: sarah,
          userInput: 'anything',
          currentMemory: memory,
          attachments: const [],
        ),
        throwsA(
          isA<AiUpdateFailure>().having(
            (e) => e.message.toLowerCase(),
            'message',
            contains('over capacity'),
          ),
        ),
      );
    });

    test('failOnContentPolicy throws AiUpdateFailure with rephrase '
        'copy', () async {
      final container = _container();
      addTearDown(container.dispose);
      final adapter = _adapter(container, failOnContentPolicy: true);
      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      final memory = await container.read(memoryProvider('sarah').future);

      await expectLater(
        () => adapter.run(
          contact: sarah,
          userInput: 'anything',
          currentMemory: memory,
          attachments: const [],
        ),
        throwsA(
          isA<AiUpdateFailure>().having(
            (e) => e.message.toLowerCase(),
            'message',
            contains('rephras'),
          ),
        ),
      );
    });

    test('classifyFirebaseException maps firebase_app_check exceptions to '
        'the PRD §Q8 "sign out and back in" copy', () {
      // The end-to-end test above uses the failOnAppCheck top-level
      // shortcut. This unit test pins the production catch arm's
      // classifier directly so a regression in the routing logic
      // (e.g. plugin name typo) is caught even when the shortcut
      // path stays correct.
      final mapped = debugClassifyFirebaseException(
        FirebaseException(
          plugin: 'firebase_app_check',
          code: 'unknown',
          message: 'App attestation failed.',
        ),
      );
      expect(mapped, isA<AiUpdateFailure>());
      expect(
        mapped!.message.toLowerCase(),
        allOf(contains('unavailable'), contains('sign out')),
      );
    });

    test('classifyFirebaseException returns null for unknown plugins '
        'so the retry loop treats them as transient', () {
      // Unknown FirebaseException plugins (e.g. firebase_core) fall
      // through to the transient retry path. The classifier returns
      // null so the calling catch arm assigns lastError and continues
      // the loop — same shape as a TimeoutException.
      final mapped = debugClassifyFirebaseException(
        FirebaseException(
          plugin: 'firebase_core',
          code: 'unknown',
          message: 'something else',
        ),
      );
      expect(mapped, isNull);
    });

    test('failOnAppCheck routes through PRD §Q8 "sign out and back in" '
        'copy (Pass 4.3 hotfix — debug-token 403)', () async {
      // Real-world hit: on iOS, the firebase_app_check debug provider
      // exchanges a per-device debug token for a real attestation.
      // If that token is not registered in the Firebase console for
      // project connect-me-e20b1, the exchange returns HTTP 403
      // "App attestation failed" / PERMISSION_DENIED, which surfaces
      // as a `FirebaseException(plugin: 'firebase_app_check')`. The
      // first build of #081 fell through to the warm catch-all
      // because LlmAiUpdate's typed catches only knew about
      // `FirebaseAIException` (a sibling type). This test pins the
      // routing so a future regression is caught headlessly.
      final container = _container();
      addTearDown(container.dispose);
      final adapter = _adapter(container, failOnAppCheck: true);
      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      final memory = await container.read(memoryProvider('sarah').future);

      await expectLater(
        () => adapter.run(
          contact: sarah,
          userInput: 'anything',
          currentMemory: memory,
          attachments: const [],
        ),
        throwsA(
          isA<AiUpdateFailure>().having(
            (e) => e.message.toLowerCase(),
            'message',
            allOf(contains('unavailable'), contains('sign out')),
          ),
        ),
      );
    });

    test('failed run leaves memory and state untouched', () async {
      // PRD §Q8 invariant: run is purely constructive. A run that
      // throws (any failure mode) must not have written memory or
      // mutated AppController state. With injection knobs this is
      // trivially true (we short-circuit before touching anything),
      // but the contract is explicit so we test it.
      final store = InMemoryMemoryStore();
      final container = _container(store: store);
      addTearDown(container.dispose);
      final adapter = _adapter(container, failOnNetwork: true);

      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      // Construct memoryBefore directly so we do NOT trigger the
      // lazy-create path on `memoryProvider`. That path silently
      // saves an empty doc to the store, which would make the
      // "store untouched" assertion below fail for a reason
      // unrelated to the failed run.
      final memoryBefore = MemoryDocument.empty(
        contactId: sarah.id,
        displayName: sarah.name,
        now: DateTime.utc(2026, 5, 27),
      );
      final interactionsBefore = container
          .read(appControllerProvider)
          .interactions
          .length;

      await expectLater(
        () => adapter.run(
          contact: sarah,
          userInput: 'anything',
          currentMemory: memoryBefore,
          attachments: const [],
        ),
        throwsA(isA<AiUpdateFailure>()),
      );

      // Memory store has nothing new — the failed run never wrote.
      expect(await store.listAll(), hasLength(0));
      // AppController interactions count is unchanged.
      expect(
        container.read(appControllerProvider).interactions.length,
        interactionsBefore,
      );
    });
  });

  group('LlmAiUpdate.run — all-images-failed-AND-no-text composite '
      'hard fail (PRD §Q7)', () {
    test('user attached only images that all fail with empty input '
        '→ AiUpdateFailure', () async {
      final container = _container();
      addTearDown(container.dispose);

      final adapter = LlmAiUpdate(
        firebaseAi: null,
        memoryStore: container.read(memoryStoreProvider),
        appController: container.read(appControllerProvider.notifier),
        recentInteractionsLookup: (_) => const [],
        // All attachment names look like images but all paths are
        // null → preparer returns empty `images`, all in `nameOnly`.
        attachmentPreparer: (refs) async {
          return PreparedAttachments(
            images: const [],
            nameOnly: refs
                .map(
                  (r) => PreparedAttachment(
                    name: r.name,
                    softFailReason: AttachmentDegradeReason.fileNotFound,
                  ),
                )
                .toList(),
          );
        },
      );

      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      final memory = await container.read(memoryProvider('sarah').future);

      await expectLater(
        () => adapter.run(
          contact: sarah,
          userInput: '',
          currentMemory: memory,
          attachments: const [
            AttachmentRef(name: 'a.jpg', path: null),
            AttachmentRef(name: 'b.png', path: null),
          ],
        ),
        throwsA(
          isA<AiUpdateFailure>().having(
            (e) => e.message.toLowerCase(),
            'message',
            contains("attachments couldn't be read"),
          ),
        ),
      );
    });

    test(
      'user attached only non-images with empty input → no hard fail',
      () async {
        // Non-image attachments do not trigger the all-images-failed
        // hard fail. The adapter would proceed to the SDK call site;
        // we set firebaseAi: null so the run stops at the StateError
        // boundary, proving the hard fail did NOT fire here.
        final container = _container();
        addTearDown(container.dispose);

        final adapter = LlmAiUpdate(
          firebaseAi: null,
          memoryStore: container.read(memoryStoreProvider),
          appController: container.read(appControllerProvider.notifier),
          recentInteractionsLookup: (_) => const [],
        );

        final sarah = _connection(
          container.read(appControllerProvider),
          'sarah',
        );
        final memory = await container.read(memoryProvider('sarah').future);

        await expectLater(
          () => adapter.run(
            contact: sarah,
            userInput: '',
            currentMemory: memory,
            attachments: const [AttachmentRef(name: 'doc.pdf', path: null)],
          ),
          // The all-images-failed hard fail did not throw because no
          // image was intended; we land at the SDK guard instead.
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('LlmAiUpdate.commit — Pass 3 §Q4 contract parity', () {
    test('failOnSave throws and never advances state', () async {
      final store = InMemoryMemoryStore();
      final container = _container(store: store);
      addTearDown(container.dispose);
      final adapter = _adapter(container, failOnSave: true);

      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      // Direct construction; do not trigger memoryProvider's lazy
      // save path (see note in the run-failure test).
      final memory = MemoryDocument.empty(
        contactId: sarah.id,
        displayName: sarah.name,
        now: DateTime.utc(2026, 5, 27),
      );
      final result = AiUpdateResult(
        summary: 'mock',
        contactId: 'sarah',
        interactions: [
          CrmInteraction(
            id: 'fake-i1',
            contactId: 'sarah',
            type: InteractionType.interaction,
            title: 'Test',
            note: 'Test',
            date: DateTime.utc(2026, 5, 27),
            source: InteractionSource.aiSuggested,
          ),
        ],
        memoryDocument: memory.copyWith(
          summary: 'changed',
          lastUpdated: DateTime.utc(2026, 5, 27),
        ),
      );

      final interactionsBefore = container
          .read(appControllerProvider)
          .interactions
          .where((i) => i.contactId == sarah.id)
          .length;

      await expectLater(
        () => adapter.commit(result),
        throwsA(isA<AiUpdateFailure>()),
      );

      // Memory file untouched (failOnSave threw before save ran).
      expect(await store.load('sarah'), isNull);
      // AppController state unchanged.
      expect(
        container
            .read(appControllerProvider)
            .interactions
            .where((i) => i.contactId == sarah.id)
            .length,
        interactionsBefore,
      );
    });

    test('failOnApply rolls back the just-saved memory', () async {
      // PRD §Q4 / #046 invariant: if commit's state-apply step
      // throws after memory save succeeded, the memory file is
      // restored to its pre-run value (or deleted if no prior).
      final store = InMemoryMemoryStore();
      final priorMemory = MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah Johnson',
        lastUpdated: DateTime.utc(2026, 5, 19),
        summary: 'prior summary',
      );
      await store.save(priorMemory);

      final container = _container(store: store);
      addTearDown(container.dispose);
      final adapter = _adapter(container, failOnApply: true);

      final result = AiUpdateResult(
        summary: 'mock',
        contactId: 'sarah',
        interactions: [
          CrmInteraction(
            id: 'fake-i1',
            contactId: 'sarah',
            type: InteractionType.interaction,
            title: 'Test',
            note: 'Test',
            date: DateTime.utc(2026, 5, 27),
            source: InteractionSource.aiSuggested,
          ),
        ],
        memoryDocument: priorMemory.copyWith(
          summary: 'mid-flight summary that should be rolled back',
          lastUpdated: DateTime.utc(2026, 5, 27),
        ),
      );

      await expectLater(
        () => adapter.commit(result),
        throwsA(isA<AiUpdateFailure>()),
      );

      final restored = await store.load('sarah');
      expect(restored, isNotNull);
      expect(restored!.summary, 'prior summary');
    });

    test(
      'failOnApply with no prior memory deletes the just-written doc',
      () async {
        // When no prior memory existed (lazy creation case), the
        // rollback should delete the doc the failed commit just wrote.
        final store = InMemoryMemoryStore();
        final container = _container(store: store);
        addTearDown(container.dispose);
        final adapter = _adapter(container, failOnApply: true);

        final newMemory = MemoryDocument(
          contactId: 'sarah',
          displayName: 'Sarah Johnson',
          lastUpdated: DateTime.utc(2026, 5, 27),
          summary: 'first time saved',
        );
        final result = AiUpdateResult(
          summary: 'mock',
          contactId: 'sarah',
          interactions: [
            CrmInteraction(
              id: 'fake-i1',
              contactId: 'sarah',
              type: InteractionType.interaction,
              title: 'Test',
              note: 'Test',
              date: DateTime.utc(2026, 5, 27),
              source: InteractionSource.aiSuggested,
            ),
          ],
          memoryDocument: newMemory,
        );

        await expectLater(
          () => adapter.commit(result),
          throwsA(isA<AiUpdateFailure>()),
        );

        // Rollback deleted the just-written doc.
        expect(await store.load('sarah'), isNull);
      },
    );
  });

  group('LlmAiUpdate constants', () {
    test('default model matches PRD §Q2 / #076 verification', () {
      expect(kLlmAiUpdateDefaultModel, 'gemini-2.5-flash');
    });

    test('default timeout matches PRD §Q6 (20s)', () {
      expect(kLlmAiUpdateDefaultTimeout, const Duration(seconds: 20));
    });
  });

  group('LlmAiUpdate.run — cancelToken runtime contract '
      '(PRD §Q8 group 3)', () {
    test('cancelToken that completes before run finishes throws '
        'AiUpdateCancelled', () async {
      // Slow attachment preparer holds the run open; the cancel
      // token wins the race before the SDK call site is reached,
      // so we don't need a FirebaseAI handle to prove the contract.
      final container = _container();
      addTearDown(container.dispose);

      final cancel = Completer<void>();
      final adapter = LlmAiUpdate(
        firebaseAi: null,
        memoryStore: container.read(memoryStoreProvider),
        appController: container.read(appControllerProvider.notifier),
        recentInteractionsLookup: (_) => const [],
        // Preparer never completes — simulates a slow Gemini call.
        attachmentPreparer: (_) => Completer<PreparedAttachments>().future,
      );

      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      final memory = MemoryDocument.empty(
        contactId: sarah.id,
        displayName: sarah.name,
        now: DateTime.utc(2026, 5, 27),
      );

      final runFuture = adapter.run(
        contact: sarah,
        userInput: 'anything',
        currentMemory: memory,
        attachments: const [],
        cancelToken: cancel.future,
      );
      // Fire cancel after the microtask queue lets `run()` start.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      cancel.complete();

      await expectLater(runFuture, throwsA(isA<AiUpdateCancelled>()));
    });

    test('cancelToken that never completes does not affect normal '
        'run failure paths', () async {
      // Cancellation is not an error; if the token never fires,
      // the run's other failure modes still surface as expected.
      final container = _container();
      addTearDown(container.dispose);
      final adapter = _adapter(container, failOnNetwork: true);

      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      final memory = MemoryDocument.empty(
        contactId: sarah.id,
        displayName: sarah.name,
        now: DateTime.utc(2026, 5, 27),
      );

      // Token that never completes: the cancel race never fires.
      final neverCancel = Completer<void>().future;
      await expectLater(
        () => adapter.run(
          contact: sarah,
          userInput: 'anything',
          currentMemory: memory,
          attachments: const [],
          cancelToken: neverCancel,
        ),
        throwsA(isA<AiUpdateFailure>()),
      );
    });
  });

  group('LlmAiUpdate projection — PRD §Q4 / reviewer BLOCKER 3 '
      '(preferences + upcoming land in MemoryDocument)', () {
    test('preferencesToAdd merge into memory.preferences with '
        'case-insensitive dedup', () {
      final container = _container();
      addTearDown(container.dispose);
      final adapter = _adapter(container);

      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      final memory = MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah Johnson',
        lastUpdated: DateTime.utc(2026, 5, 19),
        preferences: 'Prefers oat milk',
      );
      final llmResult = LlmAiUpdateResponse(
        interactionType: InteractionType.preference,
        interactionTitle: 'Preference added',
        interactionNote: "Sarah doesn't drink alcohol.",
        memoryUpdate: LlmMemoryUpdate(
          newHistoryBullet: "- 2026-05-27 — Sarah doesn't drink alcohol.",
          preferencesToAdd: const [
            "doesn't drink alcohol",
            // Case-insensitive duplicate of the existing line.
            'PREFERS OAT MILK',
          ],
        ),
        interactionDepth: 50,
      );

      final result = debugProjectLlmResponseOntoAiUpdateResult(
        adapter: adapter,
        llmResult: llmResult,
        contact: sarah,
        currentMemory: memory,
        attachments: const [],
        now: DateTime.utc(2026, 5, 27),
      );

      final newMemory = result.memoryDocument!;
      // Existing line preserved verbatim; new line appended; case-
      // insensitive duplicate dropped.
      expect(newMemory.preferences, "Prefers oat milk\ndoesn't drink alcohol");
    });

    test(
      'topicSuggestions merge into memory for new and touched topics while preserving untouched groups',
      () {
        final container = _container();
        addTearDown(container.dispose);
        final adapter = _adapter(container);
        final sarah = _connection(
          container.read(appControllerProvider),
          'sarah',
        );
        final memory = MemoryDocument(
          contactId: 'sarah',
          displayName: 'Sarah Johnson',
          lastUpdated: DateTime.utc(2026, 5, 19),
          topics: const ['paris trip', 'pottery'],
          topicSuggestions: [
            TopicSuggestionGroup(
              topic: 'paris trip',
              lastMentionedAt: DateTime.utc(2026, 5, 1),
              mentionCount: 1,
              suggestions: const [
                TopicSuggestion(
                  kind: TopicSuggestionKind.ask,
                  text: 'Ask what part of Paris she is most excited for.',
                ),
              ],
            ),
            TopicSuggestionGroup(
              topic: 'pottery',
              lastMentionedAt: DateTime.utc(2026, 4, 1),
              mentionCount: 3,
              suggestions: const [
                TopicSuggestion(
                  kind: TopicSuggestionKind.remember,
                  text: 'Remember to ask about her latest pottery class.',
                ),
              ],
            ),
          ],
        );
        final llmResult = LlmAiUpdateResponse(
          interactionType: InteractionType.sharedActivity,
          interactionTitle: 'Trip planning',
          interactionNote: 'Sarah talked about Paris plans.',
          memoryUpdate: LlmMemoryUpdate(
            newHistoryBullet: '- 2026-06-04 — Sarah talked about Paris plans.',
            topicsToAdd: const ['currency'],
            topicSuggestions: const [
              LlmTopicSuggestionGroup(
                topic: 'paris trip',
                suggestions: [
                  LlmTopicSuggestion(
                    kind: LlmTopicSuggestionKind.ask,
                    text: 'Ask how the Paris plans are coming together.',
                    context: 'Since they talked about it last time.',
                  ),
                ],
              ),
              LlmTopicSuggestionGroup(
                topic: 'currency',
                expiresAt: '2026-07-01',
                suggestions: [
                  LlmTopicSuggestion(
                    kind: LlmTopicSuggestionKind.share,
                    text: 'Share a gentle travel-money tip if you spot one.',
                  ),
                ],
              ),
            ],
          ),
          interactionDepth: 50,
        );

        final result = debugProjectLlmResponseOntoAiUpdateResult(
          adapter: adapter,
          llmResult: llmResult,
          contact: sarah,
          currentMemory: memory,
          attachments: const [],
          now: DateTime.utc(2026, 6, 4),
        );

        final groups = result.memoryDocument!.topicSuggestions;
        final paris = groups.firstWhere((g) => g.topic == 'paris trip');
        expect(paris.lastMentionedAt, DateTime.utc(2026, 6, 4));
        expect(paris.mentionCount, 2);
        expect(
          paris.suggestions.single.text,
          'Ask how the Paris plans are coming together.',
        );
        expect(
          paris.suggestions.single.context,
          'Since they talked about it last time.',
        );

        final currency = groups.firstWhere((g) => g.topic == 'currency');
        expect(currency.lastMentionedAt, DateTime.utc(2026, 6, 4));
        expect(currency.mentionCount, 1);
        expect(currency.expiresAt, DateTime.utc(2026, 7, 1));
        expect(currency.suggestions.single.kind, TopicSuggestionKind.share);

        final pottery = groups.firstWhere((g) => g.topic == 'pottery');
        expect(pottery.mentionCount, 3);
        expect(
          pottery.suggestions.single.text,
          'Remember to ask about her latest pottery class.',
        );
      },
    );

    test(
      'empty touched topic suggestion group updates metadata without clearing existing suggestions',
      () {
        final container = _container();
        addTearDown(container.dispose);
        final adapter = _adapter(container);
        final sarah = _connection(
          container.read(appControllerProvider),
          'sarah',
        );
        final memory = MemoryDocument(
          contactId: 'sarah',
          displayName: 'Sarah Johnson',
          lastUpdated: DateTime.utc(2026, 5, 19),
          topics: const ['paris trip'],
          topicSuggestions: [
            TopicSuggestionGroup(
              topic: 'paris trip',
              lastMentionedAt: DateTime.utc(2026, 5, 1),
              mentionCount: 1,
              expiresAt: DateTime.utc(2026, 7, 1),
              suggestions: const [
                TopicSuggestion(
                  kind: TopicSuggestionKind.ask,
                  text: 'Ask what part of Paris she is most excited for.',
                ),
              ],
            ),
          ],
        );
        const llmResult = LlmAiUpdateResponse(
          interactionType: InteractionType.sharedActivity,
          interactionTitle: 'Trip planning',
          interactionNote: 'Sarah talked about Paris plans.',
          memoryUpdate: LlmMemoryUpdate(
            newHistoryBullet: '- 2026-06-04 — Sarah talked about Paris plans.',
            topicSuggestions: [
              LlmTopicSuggestionGroup(topic: 'paris trip', suggestions: []),
            ],
          ),
          interactionDepth: 50,
        );

        final result = debugProjectLlmResponseOntoAiUpdateResult(
          adapter: adapter,
          llmResult: llmResult,
          contact: sarah,
          currentMemory: memory,
          attachments: const [],
          now: DateTime.utc(2026, 6, 4),
        );

        final paris = result.memoryDocument!.topicSuggestions.single;
        expect(paris.lastMentionedAt, DateTime.utc(2026, 6, 4));
        expect(paris.mentionCount, 2);
        expect(paris.expiresAt, isNull);
        expect(
          paris.suggestions.single.text,
          'Ask what part of Paris she is most excited for.',
        );
      },
    );

    test('upcomingToAdd with ISO date lands as UpcomingEntry on '
        'memory.upcoming', () {
      final container = _container();
      addTearDown(container.dispose);
      final adapter = _adapter(container);
      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      final memory = MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah Johnson',
        lastUpdated: DateTime.utc(2026, 5, 19),
      );
      final llmResult = LlmAiUpdateResponse(
        interactionType: InteractionType.personalDetail,
        interactionTitle: 'Milestone captured',
        interactionNote: "Sarah's daughter starts kindergarten.",
        memoryUpdate: LlmMemoryUpdate(
          newHistoryBullet:
              "- 2026-05-27 — Sarah's daughter starts kindergarten in "
              'September.',
          upcomingToAdd: const [
            LlmUpcomingEntry(
              label: 'Kindergarten starts',
              kind: LlmUpcomingKind.milestone,
              dateIso: '2026-09-01',
            ),
          ],
        ),
        interactionDepth: 75,
      );

      final result = debugProjectLlmResponseOntoAiUpdateResult(
        adapter: adapter,
        llmResult: llmResult,
        contact: sarah,
        currentMemory: memory,
        attachments: const [],
        now: DateTime.utc(2026, 5, 27),
      );

      final upcoming = result.memoryDocument!.upcoming;
      expect(upcoming, hasLength(1));
      expect(upcoming.single.startDate, DateTime.utc(2026, 9, 1));
      expect(upcoming.single.description, 'Kindergarten starts');
    });

    test('upcomingToAdd with relativeWhen but no dateIso falls back '
        'to now + appended phrase', () {
      final container = _container();
      addTearDown(container.dispose);
      final adapter = _adapter(container);
      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      final memory = MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah Johnson',
        lastUpdated: DateTime.utc(2026, 5, 19),
      );
      final llmResult = LlmAiUpdateResponse(
        interactionType: InteractionType.sharedActivity,
        interactionTitle: 'Trip planning',
        interactionNote: 'Trip is loose.',
        memoryUpdate: LlmMemoryUpdate(
          newHistoryBullet: '- 2026-05-27 — Trip planning conversation.',
          upcomingToAdd: const [
            LlmUpcomingEntry(
              label: 'Europe trip',
              kind: LlmUpcomingKind.trip,
              relativeWhen: 'next month',
            ),
          ],
        ),
        interactionDepth: 50,
      );

      final now = DateTime.utc(2026, 5, 27);
      final result = debugProjectLlmResponseOntoAiUpdateResult(
        adapter: adapter,
        llmResult: llmResult,
        contact: sarah,
        currentMemory: memory,
        attachments: const [],
        now: now,
      );

      final upcoming = result.memoryDocument!.upcoming;
      expect(upcoming, hasLength(1));
      expect(upcoming.single.startDate, now);
      expect(upcoming.single.description, 'Europe trip (next month)');
    });

    test('summary stays unchanged when llmResult.memoryUpdate.summary '
        'is null', () {
      final container = _container();
      addTearDown(container.dispose);
      final adapter = _adapter(container);
      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      final memory = MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah Johnson',
        lastUpdated: DateTime.utc(2026, 5, 19),
        summary: 'original summary',
      );
      final llmResult = LlmAiUpdateResponse(
        interactionType: InteractionType.interaction,
        interactionTitle: 'Routine check-in',
        interactionNote: 'Routine.',
        memoryUpdate: LlmMemoryUpdate(
          summary: null,
          newHistoryBullet: '- 2026-05-27 — Routine.',
        ),
        interactionDepth: 25,
      );

      final result = debugProjectLlmResponseOntoAiUpdateResult(
        adapter: adapter,
        llmResult: llmResult,
        contact: sarah,
        currentMemory: memory,
        attachments: const [],
        now: DateTime.utc(2026, 5, 27),
      );

      expect(result.memoryDocument!.summary, 'original summary');
    });

    test('projection populates bondScoreDelta via the curve at low bond '
        '(#085 Slice 4b)', () {
      // Build a custom contact at bond=20 to hit the low-bond anchor.
      // Sarah seeds at 92 in AppState.seeded(); we override directly
      // rather than depending on the seed so the test pins the
      // formula — not the seed value.
      final container = _container();
      addTearDown(container.dispose);
      final adapter = _adapter(container);
      final memory = MemoryDocument(
        contactId: 'low-bond',
        displayName: 'Low Bond',
        lastUpdated: DateTime.utc(2026, 5, 19),
      );
      final lowBondContact = Connection(
        id: 'low-bond',
        name: 'Low Bond',
        email: 'lb@example.com',
        category: 'Friends',
        avatar: '👤',
        bondScore: 20,
        nextStep: '',
        lastContact: DateTime.utc(2026, 5, 1),
        notes: '',
        knownSince: DateTime.utc(2024, 1, 1),
        preferredChannels: const ['Text'],
      );
      final llmResult = LlmAiUpdateResponse(
        interactionType: InteractionType.sharedActivity,
        interactionTitle: 'Day-long trip',
        interactionNote: 'Spent the whole day together.',
        memoryUpdate: LlmMemoryUpdate(
          summary: 'Strong shared experience.',
          newHistoryBullet: '- 2026-05-27 — Day-long trip.',
        ),
        interactionDepth: 100,
      );

      final result = debugProjectLlmResponseOntoAiUpdateResult(
        adapter: adapter,
        llmResult: llmResult,
        contact: lowBondContact,
        currentMemory: memory,
        attachments: const [],
        now: DateTime.utc(2026, 5, 27),
      );

      // Anchor: depth=100, bond=20 → floor(100 × 80 / 160) = 50.
      expect(result.bondScoreDelta, 50);
    });

    test('projection populates bondScoreDelta via the curve at high bond '
        '(#085 Slice 4b)', () {
      final container = _container();
      addTearDown(container.dispose);
      final adapter = _adapter(container);
      final memory = MemoryDocument(
        contactId: 'high-bond',
        displayName: 'High Bond',
        lastUpdated: DateTime.utc(2026, 5, 19),
      );
      final highBondContact = Connection(
        id: 'high-bond',
        name: 'High Bond',
        email: 'hb@example.com',
        category: 'Friends',
        avatar: '👤',
        bondScore: 90,
        nextStep: '',
        lastContact: DateTime.utc(2026, 5, 1),
        notes: '',
        knownSince: DateTime.utc(2024, 1, 1),
        preferredChannels: const ['Text'],
      );
      final llmResult = LlmAiUpdateResponse(
        interactionType: InteractionType.sharedActivity,
        interactionTitle: 'Day-long trip',
        interactionNote: 'Spent the whole day together.',
        memoryUpdate: LlmMemoryUpdate(
          summary: 'Continued strong bond.',
          newHistoryBullet: '- 2026-05-27 — Day-long trip.',
        ),
        interactionDepth: 100,
      );

      final result = debugProjectLlmResponseOntoAiUpdateResult(
        adapter: adapter,
        llmResult: llmResult,
        contact: highBondContact,
        currentMemory: memory,
        attachments: const [],
        now: DateTime.utc(2026, 5, 27),
      );

      // Anchor: depth=100, bond=90 → floor(100 × 10 / 160) = 6.
      expect(result.bondScoreDelta, 6);
    });

    test('projection emits bondScoreDelta=0 when LLM judged depth=0 '
        '(#085 Slice 4b)', () {
      final container = _container();
      addTearDown(container.dispose);
      final adapter = _adapter(container);
      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      final memory = MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah Johnson',
        lastUpdated: DateTime.utc(2026, 5, 19),
      );
      final llmResult = LlmAiUpdateResponse(
        interactionType: InteractionType.interaction,
        interactionTitle: 'Hi',
        interactionNote: 'Brief hello.',
        memoryUpdate: LlmMemoryUpdate(
          summary: null,
          newHistoryBullet: '- 2026-05-27 — Hi.',
        ),
        interactionDepth: 0,
      );

      final result = debugProjectLlmResponseOntoAiUpdateResult(
        adapter: adapter,
        llmResult: llmResult,
        contact: sarah,
        currentMemory: memory,
        attachments: const [],
        now: DateTime.utc(2026, 5, 27),
      );

      expect(result.bondScoreDelta, 0);
    });
  });

  group('Bond Score curve (PRD §Q6 addendum / #085)', () {
    // Diminishing-returns formula: floor(depth × (100 − currentBond) / 160).
    // Anchored at the 2026-06-01 grilling decision: same input moves a
    // low-bond contact much more than a high-bond contact. The reference
    // table lives in docs/issues/085-apply-llm-bondscoredelta.md.

    test('bond=20, depth=100 → +50 (low-bond anchor)', () {
      expect(debugApplyBondScoreCurve(depth: 100, currentBond: 20), 50);
    });

    test('bond=90, depth=100 → +6 (high-bond anchor)', () {
      expect(debugApplyBondScoreCurve(depth: 100, currentBond: 90), 6);
    });

    test('bond=20, depth=0 → +0 (LLM judged trivial; no movement)', () {
      expect(debugApplyBondScoreCurve(depth: 0, currentBond: 20), 0);
    });

    test('bond=100, depth=anything → +0 (capped relationship)', () {
      expect(debugApplyBondScoreCurve(depth: 0, currentBond: 100), 0);
      expect(debugApplyBondScoreCurve(depth: 50, currentBond: 100), 0);
      expect(debugApplyBondScoreCurve(depth: 100, currentBond: 100), 0);
    });

    test('bond=50, depth=50 → +15 (middle cell, floor of 15.625)', () {
      // 50 × (100 − 50) / 160 = 2500 / 160 = 15.625 → floor = 15.
      // Note: the issue file's reference table shows +16 for this cell
      // because the table uses round() informally; the contract is
      // floor() per the formula in the PRD addendum.
      expect(debugApplyBondScoreCurve(depth: 50, currentBond: 50), 15);
    });

    test('bond=80, depth=10 → +1 (small input at high bond barely moves)', () {
      // 10 × 20 / 160 = 200 / 160 = 1.25 → floor = 1.
      expect(debugApplyBondScoreCurve(depth: 10, currentBond: 80), 1);
    });

    test('depth above 100 is clamped before applying the curve', () {
      // Schema validation should reject this upstream, but the helper
      // is defensive: a bad input never produces a bigger delta than
      // depth=100 would.
      expect(
        debugApplyBondScoreCurve(depth: 200, currentBond: 20),
        debugApplyBondScoreCurve(depth: 100, currentBond: 20),
      );
    });

    test('negative depth produces a negative delta (conflict/harmful interaction)', () {
      // Design decision: depth = -100 at bond=60 → -(100*60/160) = -37
      expect(debugApplyBondScoreCurve(depth: -100, currentBond: 60), -37);
      // depth = -50 at bond=60 → -(50*60/160) = -18
      expect(debugApplyBondScoreCurve(depth: -50, currentBond: 60), -18);
      // depth = -100 at bond=0 → 0 (nothing to lose)
      expect(debugApplyBondScoreCurve(depth: -100, currentBond: 0), 0);
      // depth = -25 at bond=80 → -(25*80/160) = -12
      expect(debugApplyBondScoreCurve(depth: -25, currentBond: 80), -12);
    });

    test('depth below -100 is clamped to -100 (symmetric with positive clamp)', () {
      expect(
        debugApplyBondScoreCurve(depth: -200, currentBond: 60),
        debugApplyBondScoreCurve(depth: -100, currentBond: 60),
      );
    });

    test('currentBond outside 0..100 is clamped before the curve runs', () {
      // Defensive: AppController already clamps post-write, but the
      // helper should not amplify a corrupted input. Below-zero bond
      // produces depth's full effect (treated as 0); above-100 produces
      // 0 (treated as 100).
      expect(
        debugApplyBondScoreCurve(depth: 100, currentBond: -10),
        debugApplyBondScoreCurve(depth: 100, currentBond: 0),
      );
      expect(debugApplyBondScoreCurve(depth: 100, currentBond: 150), 0);
    });
  });

  group('LlmAiUpdate relevance pre-classifier TDD', () {
    test('MockAiUpdate.failOnRelevanceCheck = true throws AiUpdateRejected', () async {
      final container = _container();
      addTearDown(container.dispose);
      final adapter = MockAiUpdate(
        memoryStore: container.read(memoryStoreProvider),
        appController: container.read(appControllerProvider.notifier),
        failOnRelevanceCheck: true,
      );

      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      final memory = await container.read(memoryProvider('sarah').future);

      await expectLater(
        () => adapter.run(
          contact: sarah,
          userInput: 'anything',
          currentMemory: memory,
          attachments: const [],
        ),
        throwsA(
          isA<AiUpdateRejected>().having(
            (e) => e.reason,
            'reason',
            contains('relevance rejection'),
          ),
        ),
      );
    });

    test('relevance classifier pass path proceeds to main Gemini call and triggers onClassifierPassed', () async {
      final container = _container();
      addTearDown(container.dispose);

      var classifierPassedCalled = false;
      var callCount = 0;

      final adapter = LlmAiUpdate(
        firebaseAi: null,
        memoryStore: container.read(memoryStoreProvider),
        appController: container.read(appControllerProvider.notifier),
        recentInteractionsLookup: (_) => const [],
        geminiGenerateContent: ({required dynamic modelName, required dynamic systemPrompt, required dynamic responseSchema, required dynamic contents, required dynamic timeout}) async {
          callCount++;
          if (callCount == 1) {
            return '{"isRelevant": true, "reason": "ok"}';
          }
          return '{"interactionType": "interaction", "interactionTitle": "Routine conversation", "interactionNote": "Talked about weather", "interactionDepth": 25, "memoryUpdate": {"newHistoryBullet": "- 2026-06-14 \u2014 Talked about weather."}}';
        },
        onClassifierPassed: () {
          classifierPassedCalled = true;
        },
      );

      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      final memory = await container.read(memoryProvider('sarah').future);

      final result = await adapter.run(
        contact: sarah,
        userInput: 'good input',
        currentMemory: memory,
        attachments: const [],
      );

      expect(result.summary, contains('AI updated context'));
      expect(classifierPassedCalled, isTrue);
      expect(callCount, 2);
    });

    test('relevance classifier fail path throws AiUpdateRejected and does not call main Gemini', () async {
      final container = _container();
      addTearDown(container.dispose);

      var classifierPassedCalled = false;
      var callCount = 0;

      final adapter = LlmAiUpdate(
        firebaseAi: null,
        memoryStore: container.read(memoryStoreProvider),
        appController: container.read(appControllerProvider.notifier),
        recentInteractionsLookup: (_) => const [],
        geminiGenerateContent: ({required dynamic modelName, required dynamic systemPrompt, required dynamic responseSchema, required dynamic contents, required dynamic timeout}) async {
          callCount++;
          if (callCount == 1) {
            return '{"isRelevant": false, "reason": "off topic completely"}';
          }
          return '{}';
        },
        onClassifierPassed: () {
          classifierPassedCalled = true;
        },
      );

      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      final memory = await container.read(memoryProvider('sarah').future);

      await expectLater(
        () => adapter.run(
          contact: sarah,
          userInput: 'spam or off-topic input',
          currentMemory: memory,
          attachments: const [],
        ),
        throwsA(
          isA<AiUpdateRejected>().having(
            (e) => e.reason,
            'reason',
            'off topic completely',
          ),
        ),
      );

      expect(classifierPassedCalled, isFalse);
      expect(callCount, 1);
    });

    test('relevance classifier timeout (5s) fails open, calling main Gemini', () async {
      final container = _container();
      addTearDown(container.dispose);

      var classifierPassedCalled = false;
      var callCount = 0;

      final adapter = LlmAiUpdate(
        firebaseAi: null,
        memoryStore: container.read(memoryStoreProvider),
        appController: container.read(appControllerProvider.notifier),
        recentInteractionsLookup: (_) => const [],
        geminiGenerateContent: ({required dynamic modelName, required dynamic systemPrompt, required dynamic responseSchema, required dynamic contents, required dynamic timeout}) async {
          callCount++;
          if (callCount == 1) {
            // Delay 6s — longer than the 5s classifier timeout enforced
            // by .timeout() at the call site — so the timeout fires.
            await Future<void>.delayed(const Duration(seconds: 6));
            return '{"isRelevant": false, "reason": "not relevant but timed out"}';
          }
          return '{"interactionType": "interaction", "interactionTitle": "Proceeded after timeout", "interactionNote": "Proceeded", "interactionDepth": 25, "memoryUpdate": {"newHistoryBullet": "- 2026-06-14 \u2014 Proceeded after timeout."}}';
        },
        onClassifierPassed: () {
          classifierPassedCalled = true;
        },
      );

      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      final memory = await container.read(memoryProvider('sarah').future);

      final result = await adapter.run(
        contact: sarah,
        userInput: 'timed out input',
        currentMemory: memory,
        attachments: const [],
      );

      expect(result.summary, contains('AI updated context'));
      expect(classifierPassedCalled, isFalse);
      expect(callCount, 2);
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('relevance classifier exception fails open, calling main Gemini', () async {
      final container = _container();
      addTearDown(container.dispose);

      var classifierPassedCalled = false;
      var callCount = 0;

      final adapter = LlmAiUpdate(
        firebaseAi: null,
        memoryStore: container.read(memoryStoreProvider),
        appController: container.read(appControllerProvider.notifier),
        recentInteractionsLookup: (_) => const [],
        geminiGenerateContent: ({required dynamic modelName, required dynamic systemPrompt, required dynamic responseSchema, required dynamic contents, required dynamic timeout}) async {
          callCount++;
          if (callCount == 1) {
            throw StateError('Classifier crashed');
          }
          return '{"interactionType": "interaction", "interactionTitle": "Proceeded after exception", "interactionNote": "Proceeded", "interactionDepth": 25, "memoryUpdate": {"newHistoryBullet": "- 2026-06-14 \u2014 Proceeded after exception."}}';
        },
        onClassifierPassed: () {
          classifierPassedCalled = true;
        },
      );

      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      final memory = await container.read(memoryProvider('sarah').future);

      final result = await adapter.run(
        contact: sarah,
        userInput: 'exception input',
        currentMemory: memory,
        attachments: const [],
      );

      expect(result.summary, contains('AI updated context'));
      expect(classifierPassedCalled, isFalse);
      expect(callCount, 2);
    });

    test('relevance classifier cancellation throws AiUpdateCancelled', () async {
      final container = _container();
      addTearDown(container.dispose);

      final cancel = Completer<void>();

      final adapter = LlmAiUpdate(
        firebaseAi: null,
        memoryStore: container.read(memoryStoreProvider),
        appController: container.read(appControllerProvider.notifier),
        recentInteractionsLookup: (_) => const [],
        geminiGenerateContent: ({required dynamic modelName, required dynamic systemPrompt, required dynamic responseSchema, required dynamic contents, required dynamic timeout}) async {
          // Never-completing — so the cancel token wins the race.
          await Completer<void>().future;
          return '{"isRelevant": true}';
        },
      );

      final sarah = _connection(container.read(appControllerProvider), 'sarah');
      final memory = await container.read(memoryProvider('sarah').future);

      final runFuture = adapter.run(
        contact: sarah,
        userInput: 'anything',
        currentMemory: memory,
        attachments: const [],
        cancelToken: cancel.future,
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      cancel.complete();

      await expectLater(runFuture, throwsA(isA<AiUpdateCancelled>()));
    });
  });
}
