import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../models/social_models.dart';
import 'interaction_store.dart';

/// In-process [InteractionStore] backed by a plain [Map]. Used in
/// tests and as the override target for headless widget tests; the
/// Firestore-backed adapter is [FirebaseInteractionStore].
///
/// Mirrors [InMemoryConnectionStore]'s shape exactly — the snapshot
/// contract is identical so the same patterns light up for the
/// snapshot listener (PRD §Q6) when the production adapter is
/// wired in.
class InMemoryInteractionStore implements InteractionStore {
  final Map<String, CrmInteraction> _store = {};
  final StreamController<Map<String, CrmInteraction>> _controller =
      StreamController<Map<String, CrmInteraction>>.broadcast();
  Map<String, CrmInteraction>? _mirror;

  @override
  Future<CrmInteraction?> load(String interactionId) async {
    return _store[interactionId];
  }

  @override
  Future<void> save(CrmInteraction interaction) async {
    _store[interaction.id] = interaction;
    _publish();
  }

  @override
  Future<void> delete(String interactionId) async {
    _store.remove(interactionId);
    _publish();
  }

  @override
  Future<Map<String, CrmInteraction>> listAll() async {
    return Map.unmodifiable(Map<String, CrmInteraction>.from(_store));
  }

  @override
  Stream<Map<String, CrmInteraction>> snapshot() {
    // Broadcast streams do not buffer for late subscribers. Wrap
    // with a controller that replays the current mirror on subscribe
    // so callers see a deterministic first event without having to
    // combine listAll() and the stream themselves.
    late StreamController<Map<String, CrmInteraction>> controller;
    StreamSubscription<Map<String, CrmInteraction>>? sub;
    controller = StreamController<Map<String, CrmInteraction>>(
      onListen: () {
        final current = _mirror;
        if (current != null) controller.add(current);
        sub = _controller.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () async {
        await sub?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  @override
  Map<String, CrmInteraction>? snapshotSync() => _mirror;

  /// Empties the store and broadcasts an empty snapshot. Helpful in
  /// tests; not part of the [InteractionStore] contract.
  Future<void> clear() async {
    _store.clear();
    _publish();
  }

  /// Test-only synchronous seeding hatch. See
  /// [InMemoryConnectionStore.seedSync] for the rationale; this is
  /// the same pattern for interactions.
  @visibleForTesting
  void seedSync(Iterable<CrmInteraction> interactions) {
    for (final interaction in interactions) {
      _store[interaction.id] = interaction;
    }
  }

  void _publish() {
    final snapshot = Map<String, CrmInteraction>.unmodifiable(
      Map<String, CrmInteraction>.from(_store),
    );
    _mirror = snapshot;
    _controller.add(snapshot);
  }

  /// Closes the underlying stream controller. Called by the
  /// auth-aware provider's `onDispose` when the store is being torn
  /// down, e.g. on sign-out or auth swap. Idempotent.
  @override
  Future<void> dispose() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
