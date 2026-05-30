import 'package:connect_me/src/ai/llm_ai_update.dart';
import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/firebase_providers.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_overrides.dart';

/// Tests for `aiUpdateProvider` (Pass 4.3 #081).
///
/// These are pure Dart provider-shape tests. They do NOT call into
/// the Firebase AI Logic SDK — that lives behind the integration-
/// test substrate in `integration_test/` (see #082). A real
/// `FirebaseAI` handle is never constructed; the signed-in case
/// asserts that the provider returned the [LlmAiUpdate] adapter
/// shape but does not call `run()`, which would require a working
/// SDK or a heavy fake.
///
/// The signed-out case asserts the [_SignedOutAiUpdate] sentinel
/// throws StateError on every call, mirroring the existing
/// `_SignedOutMemoryStore` contract from Pass 4.2 #058.
void main() {
  group('aiUpdateProvider — signed out', () {
    test('returns a sentinel that throws StateError on run()', () async {
      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
      ]);
      addTearDown(container.dispose);

      final ai = container.read(aiUpdateProvider);

      // Sentinel type is private; assert behaviour rather than type.
      await expectLater(
        ai.run(
          contact: Connection(
            id: 'sarah',
            name: 'Sarah',
            email: 'sarah@example.com',
            category: 'Friends',
            avatar: '👩',
            bondScore: 50,
            nextStep: '',
            lastContact: DateTime.utc(2026, 5, 1),
            notes: '',
            knownSince: DateTime.utc(2024, 1, 1),
            preferredChannels: const ['email'],
          ),
          userInput: 'hi',
          currentMemory: MemoryDocument(
            contactId: 'sarah',
            displayName: 'Sarah',
            lastUpdated: DateTime.utc(2026, 5, 30),
          ),
          attachments: const [],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('returns a sentinel that throws StateError on commit()', () async {
      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
      ]);
      addTearDown(container.dispose);

      final ai = container.read(aiUpdateProvider);

      await expectLater(
        ai.commit(const AiUpdateResult(
          summary: 's',
          contactId: 'sarah',
          interactions: [],
        )),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('aiUpdateProvider — signed in', () {
    test('returns an LlmAiUpdate when a user is signed in', () {
      // signedInDemoOverrides() supplies a signed-in MockFirebaseAuth
      // plus the Pass 4.5 store overrides AppController needs, AND
      // (post-#081) the firebaseAiProvider null override. We do NOT
      // override `aiUpdateProvider` itself — the production factory
      // must select LlmAiUpdate based on the signed-in user.
      final container = ProviderContainer(overrides: [
        ...signedInDemoOverrides(),
        memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
      ]);
      addTearDown(container.dispose);

      final ai = container.read(aiUpdateProvider);

      expect(ai, isA<LlmAiUpdate>());
    });

    test('LlmAiUpdate instance carries the active memoryStoreProvider', () {
      final memoryStore = InMemoryMemoryStore();
      final container = ProviderContainer(overrides: [
        ...signedInDemoOverrides(),
        memoryStoreProvider.overrideWithValue(memoryStore),
      ]);
      addTearDown(container.dispose);

      final ai = container.read(aiUpdateProvider) as LlmAiUpdate;

      // The store must be the override we supplied — auth swap
      // and store swap both have to flow through.
      expect(identical(ai.memoryStore, memoryStore), isTrue);
    });
  });
}
