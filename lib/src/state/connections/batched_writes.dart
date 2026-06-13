import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/social_models.dart';
import 'connection_store.dart';
import 'event_store.dart';
import 'firebase_connection_store.dart';
import 'firebase_event_store.dart';
import 'firebase_interaction_store.dart';
import 'interaction_store.dart';

/// Multi-store atomic write coordinator (Pass 4.5 #070, PRD §Q4).
///
/// AppController has two operations that mutate more than one
/// Firestore collection in the same logical action:
///
///   1. [commitDeleteConnection] — removes a connection plus every
///      interaction and event tied to that contact, plus the
///      contact's memory document.
///   2. [commitAiUpdate] — persists a new interaction AND bumps the
///      connection's bondScore + lastContact in one go.
///
/// Both must be all-or-nothing: a partial failure mid-cascade
/// leaves Firestore in a torn state (an event pointing at a
/// deleted connection, or a bondScore bumped but the matching
/// interaction never written). Firestore's [WriteBatch] commits
/// atomically across documents in the same project — every write
/// in the batch lands or none of them do — so this coordinator
/// composes the batch and commits once.
///
/// **Production wiring.** AppController reads
/// [batchedWritesProvider]. Production returns a
/// [FirebaseBatchedWrites] bound to the active [FirebaseFirestore].
/// Tests override the provider with [InMemoryBatchedWrites] (or a
/// `failOnCommit` variant) to drive the rollback path without an
/// emulator.
///
/// **Why not pass the batch around to the stores?** The store
/// adapters expose load/save/delete; threading a batch through them
/// would either leak Firestore's [WriteBatch] type into the store
/// interface (poisoning the headless adapter) or require every
/// adapter to grow a parallel `addToBatch(WriteBatch)` API. The
/// coordinator owns the encode + the batch directly because the
/// document layout (path + shape) already lives in the store
/// statics ([FirebaseConnectionStore.encode],
/// [FirebaseInteractionStore.encode],
/// [FirebaseEventStore.encode]).
abstract interface class BatchedWrites {
  /// Atomically delete a connection and its dependent records.
  ///
  /// Writes:
  ///   * Delete `users/{uid}/connections/{contactId}`
  ///   * Delete each `users/{uid}/interactions/{id}` whose
  ///     `contactId == contactId`.
  ///   * Delete each `users/{uid}/events/{id}` whose `contactId
  ///     == contactId`.
  ///
  /// The memory cascade is NOT part of this batch because
  /// `users/{uid}/memories/{contactId}` is owned by [MemoryStore],
  /// which has its own write contract from Pass 4.2. AppController
  /// fires the memory delete after a successful batch commit
  /// (best-effort, matching the prior `deleteConnection`
  /// fire-and-forget shape).
  Future<void> commitDeleteConnection({
    required String contactId,
    required Iterable<CrmInteraction> interactions,
    required Iterable<PlannerEvent> events,
  });

  /// Atomically save a new interaction and update a connection's
  /// bondScore + lastContact + nextStep.
  ///
  /// Writes:
  ///   * Set `users/{uid}/interactions/{interaction.id}` to the
  ///     full interaction document.
  ///   * Set `users/{uid}/connections/{updatedConnection.id}` to
  ///     the full connection document (overwrite, not merge — the
  ///     rules require a closed shape).
  Future<void> commitAiUpdate({
    required CrmInteraction interaction,
    required Connection updatedConnection,
  });

  /// Atomically delete a set of sample connections plus every
  /// dependent interaction and event tied to those contacts.
  /// Used by onboarding's "Start fresh" path so the user does not
  /// observe partial removal if any individual cascade fails.
  ///
  /// Writes (one [WriteBatch]):
  ///   * Delete each `users/{uid}/connections/{connection.id}` in
  ///     [connections].
  ///   * Delete every `users/{uid}/interactions/{id}` whose
  ///     `contactId` matches any connection in [connections].
  ///   * Delete every `users/{uid}/events/{id}` whose `contactId`
  ///     matches any connection in [connections].
  ///
  /// Memory cascade is OUTSIDE the batch (same reasoning as
  /// [commitDeleteConnection]); AppController fires per-id memory
  /// deletes post-commit, best-effort.
  ///
  /// Throws [ArgumentError] if the combined write count exceeds
  /// Firestore's 500-write batch limit.
  Future<void> commitRemoveSampleConnections({
    required Iterable<Connection> connections,
    required Iterable<CrmInteraction> interactions,
    required Iterable<PlannerEvent> events,
  });
}

/// Production [BatchedWrites] backed by Firestore [WriteBatch].
class FirebaseBatchedWrites implements BatchedWrites {
  FirebaseBatchedWrites({
    required FirebaseFirestore firestore,
    required String uid,
  }) : _firestore = firestore,
       _uid = uid;

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> _collection(String name) =>
      _firestore.collection('users').doc(_uid).collection(name);

  @override
  Future<void> commitDeleteConnection({
    required String contactId,
    required Iterable<CrmInteraction> interactions,
    required Iterable<PlannerEvent> events,
  }) async {
    final batch = _firestore.batch();
    batch.delete(_collection('connections').doc(contactId));
    for (final interaction in interactions) {
      if (interaction.contactId != contactId) continue;
      batch.delete(_collection('interactions').doc(interaction.id));
    }
    for (final event in events) {
      if (event.contactId != contactId) continue;
      batch.delete(_collection('events').doc(event.id));
    }
    await batch.commit();
  }

  @override
  Future<void> commitAiUpdate({
    required CrmInteraction interaction,
    required Connection updatedConnection,
  }) async {
    final batch = _firestore.batch();
    batch.set(
      _collection('interactions').doc(interaction.id),
      FirebaseInteractionStore.encode(interaction),
    );
    batch.set(
      _collection('connections').doc(updatedConnection.id),
      FirebaseConnectionStore.encode(updatedConnection),
    );
    await batch.commit();
  }

  static const int _firestoreBatchLimit = 500;

  @override
  Future<void> commitRemoveSampleConnections({
    required Iterable<Connection> connections,
    required Iterable<CrmInteraction> interactions,
    required Iterable<PlannerEvent> events,
  }) async {
    final connectionList = connections.toList(growable: false);
    if (connectionList.isEmpty) return;
    final ids = connectionList.map((c) => c.id).toSet();
    final scopedInteractions = interactions
        .where((i) => ids.contains(i.contactId))
        .toList(growable: false);
    final scopedEvents = events
        .where((e) => e.contactId != null && ids.contains(e.contactId!))
        .toList(growable: false);
    final total =
        connectionList.length + scopedInteractions.length + scopedEvents.length;
    if (total > _firestoreBatchLimit) {
      throw ArgumentError(
        'commitRemoveSampleConnections would exceed Firestore\'s '
        '$_firestoreBatchLimit-write batch limit '
        '(${connectionList.length} connections + '
        '${scopedInteractions.length} interactions + '
        '${scopedEvents.length} events = $total writes). '
        'Split the input or chunk the call.',
      );
    }
    final batch = _firestore.batch();
    for (final connection in connectionList) {
      batch.delete(_collection('connections').doc(connection.id));
    }
    for (final interaction in scopedInteractions) {
      batch.delete(_collection('interactions').doc(interaction.id));
    }
    for (final event in scopedEvents) {
      batch.delete(_collection('events').doc(event.id));
    }
    await batch.commit();
  }
}

/// In-process [BatchedWrites] that delegates to in-memory store
/// fakes. Used in headless tests to verify the cascade math
/// (which interactions / events get deleted, what the AI Update
/// writes look like) without an emulator.
///
/// `failOnCommit: true` simulates a Firestore commit failure: the
/// methods throw [StateError] without mutating the underlying
/// stores. This drives the AppController rollback contract under
/// test.
class InMemoryBatchedWrites implements BatchedWrites {
  InMemoryBatchedWrites({
    required this.connectionStore,
    required this.interactionStore,
    required this.eventStore,
    this.failOnCommit = false,
  });

  final ConnectionStore connectionStore;
  final InteractionStore interactionStore;
  final EventStore eventStore;
  final bool failOnCommit;

  @override
  Future<void> commitDeleteConnection({
    required String contactId,
    required Iterable<CrmInteraction> interactions,
    required Iterable<PlannerEvent> events,
  }) async {
    if (failOnCommit) {
      throw StateError('test-injected batch commit failure');
    }
    await connectionStore.delete(contactId);
    for (final interaction in interactions) {
      if (interaction.contactId != contactId) continue;
      await interactionStore.delete(interaction.id);
    }
    for (final event in events) {
      if (event.contactId != contactId) continue;
      await eventStore.delete(event.id);
    }
  }

  @override
  Future<void> commitAiUpdate({
    required CrmInteraction interaction,
    required Connection updatedConnection,
  }) async {
    if (failOnCommit) {
      throw StateError('test-injected batch commit failure');
    }
    await interactionStore.save(interaction);
    await connectionStore.save(updatedConnection);
  }

  @override
  Future<void> commitRemoveSampleConnections({
    required Iterable<Connection> connections,
    required Iterable<CrmInteraction> interactions,
    required Iterable<PlannerEvent> events,
  }) async {
    if (failOnCommit) {
      throw StateError('test-injected batch commit failure');
    }
    final connectionList = connections.toList(growable: false);
    if (connectionList.isEmpty) return;
    final ids = connectionList.map((c) => c.id).toSet();
    for (final connection in connectionList) {
      await connectionStore.delete(connection.id);
    }
    for (final interaction in interactions) {
      if (!ids.contains(interaction.contactId)) continue;
      await interactionStore.delete(interaction.id);
    }
    for (final event in events) {
      if (event.contactId == null || !ids.contains(event.contactId!)) continue;
      await eventStore.delete(event.id);
    }
  }
}
