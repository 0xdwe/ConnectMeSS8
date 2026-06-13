import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/memory_topic_enricher.dart';
import '../../models/social_models.dart';
import '../app_state.dart';
import '../firebase_providers.dart';
import 'memory_document.dart';
import 'memory_providers.dart';
import 'memory_store.dart';

/// Sentinel marking "this account has completed memory topic backfill."
abstract interface class BackfillSentinel {
  /// Whether the sentinel has been set.
  Future<bool> isSet();

  /// Records that the backfill has completed.
  Future<void> set(DateTime timestamp);
}

/// Firestore-backed [BackfillSentinel] writing
/// `users/{uid}.topicSuggestionsBackfillV1CompletedAt`.
class FirestoreBackfillSentinel implements BackfillSentinel {
  FirestoreBackfillSentinel({
    required FirebaseFirestore firestore,
    required String uid,
  }) : _firestore = firestore,
       _uid = uid;

  static const String fieldName = 'topicSuggestionsBackfillV1CompletedAt';

  final FirebaseFirestore _firestore;
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _userDocRef =>
      _firestore.collection('users').doc(_uid);

  @override
  Future<bool> isSet() async {
    final snap = await _userDocRef.get();
    if (!snap.exists) return false;
    return snap.data()?[fieldName] != null;
  }

  @override
  Future<void> set(DateTime timestamp) async {
    await _firestore.runTransaction<void>((tx) async {
      tx.set(_userDocRef, <String, dynamic>{
        fieldName: Timestamp.fromDate(timestamp),
      }, SetOptions(merge: true));
    });
  }
}

/// silent background memory topic backfill orchestrator.
class MemoryTopicBackfillRunner {
  MemoryTopicBackfillRunner({
    required this.store,
    required this.enricher,
    required this.sentinel,
    required this.appState,
    required this.clock,
    this.onMemoryWritten,
  });

  final MemoryStore store;
  final MemoryTopicEnricher enricher;
  final BackfillSentinel sentinel;
  final AppState appState;
  final DateTime Function() clock;
  final void Function()? onMemoryWritten;

  Future<void> runBackfill() async {
    if (await sentinel.isSet()) {
      return;
    }

    final connections = appState.connections;
    if (connections.isEmpty) {
      await sentinel.set(clock());
      return;
    }

    var allSucceededOrSkipped = true;

    for (final contact in connections) {
      final currentMemory =
          await store.load(contact.id) ??
          MemoryDocument.empty(
            contactId: contact.id,
            displayName: contact.name,
            now: clock(),
          );

      // Eligibility: lacks prepared Topic Suggestions
      if (_hasPreparedSuggestions(currentMemory)) {
        continue;
      }

      // Recent interactions cap (10)
      final recentInteractions =
          appState.interactions
              .where((i) => i.contactId == contact.id)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
      final limitedInteractions = recentInteractions.take(10).toList();

      // Skip check: no useful memory text and no recent interactions
      final hasUsefulMemory =
          currentMemory.summary.trim().isNotEmpty ||
          currentMemory.history.trim().isNotEmpty ||
          currentMemory.preferences.trim().isNotEmpty;
      if (!hasUsefulMemory && limitedInteractions.isEmpty) {
        continue;
      }

      try {
        final enriched = await enricher.enrich(
          contact: contact,
          currentMemory: currentMemory,
          recentInteractions: limitedInteractions,
        );

        await store.save(enriched);
        onMemoryWritten?.call();
      } catch (e) {
        allSucceededOrSkipped = false;
        // Silent best effort: continue loop
      }
    }

    if (allSucceededOrSkipped) {
      await sentinel.set(clock());
    }
  }

  bool _hasPreparedSuggestions(MemoryDocument doc) {
    for (final group in doc.topicSuggestions) {
      if (group.suggestions.isNotEmpty) return true;
    }
    return false;
  }
}

/// Provider for the [MemoryTopicEnricher].
final memoryTopicEnricherProvider = Provider<MemoryTopicEnricher>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return _FakeOrThrowMemoryTopicEnricher();
  }
  final firebaseAi = ref.watch(firebaseAiProvider);
  return LlmMemoryTopicEnricher(
    firebaseAi: firebaseAi,
    clock: ref.read(clockProvider),
  );
});

class _FakeOrThrowMemoryTopicEnricher implements MemoryTopicEnricher {
  @override
  Future<MemoryDocument> enrich({
    required Connection contact,
    required MemoryDocument currentMemory,
    required List<CrmInteraction> recentInteractions,
  }) {
    throw StateError('Enricher is not available while signed out.');
  }
}

/// Provider that triggers the background backfill runner.
final memoryTopicBackfillProvider = FutureProvider<void>((ref) async {
  await ref.watch(memorySeedingProvider.future);

  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return;
  }

  final store = ref.watch(memoryStoreProvider);
  // Replicate check to avoid throwing on the signed-out store sentinel
  if (store.runtimeType.toString() == '_SignedOutMemoryStore') {
    return;
  }

  final firestore = ref.watch(firestoreProvider);
  final sentinel = FirestoreBackfillSentinel(
    firestore: firestore,
    uid: user.uid,
  );
  final enricher = ref.watch(memoryTopicEnricherProvider);
  final appState = ref.read(appControllerProvider);
  final clock = ref.read(clockProvider);

  final runner = MemoryTopicBackfillRunner(
    store: store,
    enricher: enricher,
    sentinel: sentinel,
    appState: appState,
    clock: clock,
    onMemoryWritten: () {
      ref.read(memoryEpochProvider.notifier).bump(clock());
    },
  );

  unawaited(runner.runBackfill());
});
