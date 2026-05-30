import 'dart:async';

import 'package:connect_me/src/ai/ai_update.dart';
import 'package:connect_me/src/ai/attachment_preparer.dart';
import 'package:connect_me/src/ai/llm_ai_update.dart';
import 'package:connect_me/src/ai/llm_ai_update_response.dart';
import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/app_state.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
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
  return ProviderContainer(overrides: [
    ...signedInDemoOverrides(),
    memoryStoreProvider.overrideWithValue(memoryStore),
  ]);
}

LlmAiUpdate _adapter(
  ProviderContainer container, {
  bool failOnNetwork = false,
  bool failOnQuota = false,
  bool failOnContentPolicy = false,
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
    cancelMidRun: cancelMidRun,
    failOnSave: failOnSave,
    failOnApply: failOnApply,
  );
}

Connection _connection(AppState state, String id) =>
    state.connections.firstWhere((c) => c.id == id);

void main() {
  group('LlmAiUpdate.run — failure-path injection', () {
    test('cancelMidRun throws AiUpdateCancelled before any SDK call',
        () async {
      final container = _container();
      addTearDown(container.dispose);
      final adapter = _adapter(container, cancelMidRun: true);

      final sarah =
          _connection(container.read(appControllerProvider), 'sarah');
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

    test('failOnNetwork throws AiUpdateFailure with retry-friendly copy',
        () async {
      final container = _container();
      addTearDown(container.dispose);
      final adapter = _adapter(container, failOnNetwork: true);
      final sarah =
          _connection(container.read(appControllerProvider), 'sarah');
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
    });

    test('failOnQuota throws AiUpdateFailure with capacity copy',
        () async {
      final container = _container();
      addTearDown(container.dispose);
      final adapter = _adapter(container, failOnQuota: true);
      final sarah =
          _connection(container.read(appControllerProvider), 'sarah');
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

    test(
        'failOnContentPolicy throws AiUpdateFailure with rephrase '
        'copy', () async {
      final container = _container();
      addTearDown(container.dispose);
      final adapter = _adapter(container, failOnContentPolicy: true);
      final sarah =
          _connection(container.read(appControllerProvider), 'sarah');
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

      final sarah =
          _connection(container.read(appControllerProvider), 'sarah');
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
      final interactionsBefore =
          container.read(appControllerProvider).interactions.length;

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

  group(
      'LlmAiUpdate.run — all-images-failed-AND-no-text composite '
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
                .map((r) => PreparedAttachment(
                      name: r.name,
                      softFailReason:
                          AttachmentDegradeReason.fileNotFound,
                    ))
                .toList(),
          );
        },
      );

      final sarah =
          _connection(container.read(appControllerProvider), 'sarah');
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

    test('user attached only non-images with empty input → no hard fail',
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

      final sarah =
          _connection(container.read(appControllerProvider), 'sarah');
      final memory = await container.read(memoryProvider('sarah').future);

      await expectLater(
        () => adapter.run(
          contact: sarah,
          userInput: '',
          currentMemory: memory,
          attachments: const [
            AttachmentRef(name: 'doc.pdf', path: null),
          ],
        ),
        // The all-images-failed hard fail did not throw because no
        // image was intended; we land at the SDK guard instead.
        throwsA(isA<StateError>()),
      );
    });
  });

  group('LlmAiUpdate.commit — Pass 3 §Q4 contract parity', () {
    test('failOnSave throws and never advances state', () async {
      final store = InMemoryMemoryStore();
      final container = _container(store: store);
      addTearDown(container.dispose);
      final adapter = _adapter(container, failOnSave: true);

      final sarah =
          _connection(container.read(appControllerProvider), 'sarah');
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

    test('failOnApply with no prior memory deletes the just-written doc',
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
    });
  });

  group('LlmAiUpdate constants', () {
    test('default model matches PRD §Q2 / #076 verification', () {
      expect(kLlmAiUpdateDefaultModel, 'gemini-3.1-flash-lite');
    });

    test('default timeout matches PRD §Q6 (20s)', () {
      expect(kLlmAiUpdateDefaultTimeout, const Duration(seconds: 20));
    });
  });

  group(
      'LlmAiUpdate.run — cancelToken runtime contract '
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
        appController:
            container.read(appControllerProvider.notifier),
        recentInteractionsLookup: (_) => const [],
        // Preparer never completes — simulates a slow Gemini call.
        attachmentPreparer: (_) => Completer<PreparedAttachments>().future,
      );

      final sarah =
          _connection(container.read(appControllerProvider), 'sarah');
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

      final sarah =
          _connection(container.read(appControllerProvider), 'sarah');
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

  group(
      'LlmAiUpdate projection — PRD §Q4 / reviewer BLOCKER 3 '
      '(preferences + upcoming land in MemoryDocument)', () {
    test('preferencesToAdd merge into memory.preferences with '
        'case-insensitive dedup', () {
      final container = _container();
      addTearDown(container.dispose);
      final adapter = _adapter(container);

      final sarah =
          _connection(container.read(appControllerProvider), 'sarah');
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
          newHistoryBullet:
              "- 2026-05-27 — Sarah doesn't drink alcohol.",
          preferencesToAdd: const [
            "doesn't drink alcohol",
            // Case-insensitive duplicate of the existing line.
            'PREFERS OAT MILK',
          ],
        ),
        bondScoreDelta: 1,
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
      expect(
        newMemory.preferences,
        "Prefers oat milk\ndoesn't drink alcohol",
      );
    });

    test('upcomingToAdd with ISO date lands as UpcomingEntry on '
        'memory.upcoming', () {
      final container = _container();
      addTearDown(container.dispose);
      final adapter = _adapter(container);
      final sarah =
          _connection(container.read(appControllerProvider), 'sarah');
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
        bondScoreDelta: 3,
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
      final sarah =
          _connection(container.read(appControllerProvider), 'sarah');
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
          newHistoryBullet:
              '- 2026-05-27 — Trip planning conversation.',
          upcomingToAdd: const [
            LlmUpcomingEntry(
              label: 'Europe trip',
              kind: LlmUpcomingKind.trip,
              relativeWhen: 'next month',
            ),
          ],
        ),
        bondScoreDelta: 2,
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
      expect(upcoming.single.description,
          'Europe trip (next month)');
    });

    test('summary stays unchanged when llmResult.memoryUpdate.summary '
        'is null', () {
      final container = _container();
      addTearDown(container.dispose);
      final adapter = _adapter(container);
      final sarah =
          _connection(container.read(appControllerProvider), 'sarah');
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
        bondScoreDelta: 1,
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
  });
}
