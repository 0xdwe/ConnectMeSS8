import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../models/social_models.dart';
import 'event_store.dart';

/// In-process [EventStore] backed by a plain [Map]. Used in tests
/// and as the override target for headless widget tests; the
/// Firestore-backed adapter is [FirebaseEventStore].
///
/// Mirrors [InMemoryConnectionStore] and [InMemoryInteractionStore]
/// shape exactly.
class InMemoryEventStore implements EventStore {
  final Map<String, PlannerEvent> _store = {};
  final StreamController<Map<String, PlannerEvent>> _controller =
      StreamController<Map<String, PlannerEvent>>.broadcast();
  Map<String, PlannerEvent>? _mirror;

  @override
  Future<PlannerEvent?> load(String eventId) async {
    return _store[eventId];
  }

  @override
  Future<void> save(PlannerEvent event) async {
    _store[event.id] = event;
    _publish();
  }

  @override
  Future<void> delete(String eventId) async {
    _store.remove(eventId);
    _publish();
  }

  @override
  Future<Map<String, PlannerEvent>> listAll() async {
    return Map.unmodifiable(Map<String, PlannerEvent>.from(_store));
  }

  @override
  Stream<Map<String, PlannerEvent>> snapshot() {
    late StreamController<Map<String, PlannerEvent>> controller;
    StreamSubscription<Map<String, PlannerEvent>>? sub;
    controller = StreamController<Map<String, PlannerEvent>>(
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
  Map<String, PlannerEvent>? snapshotSync() => _mirror;

  /// Empties the store and broadcasts an empty snapshot. Helpful in
  /// tests; not part of the [EventStore] contract.
  Future<void> clear() async {
    _store.clear();
    _publish();
  }

  /// Test-only synchronous seeding hatch. See
  /// [InMemoryConnectionStore.seedSync] for the rationale; this is
  /// the same pattern for events.
  @visibleForTesting
  void seedSync(Iterable<PlannerEvent> events) {
    for (final event in events) {
      _store[event.id] = event;
    }
  }

  void _publish() {
    final snapshot = Map<String, PlannerEvent>.unmodifiable(
      Map<String, PlannerEvent>.from(_store),
    );
    _mirror = snapshot;
    _controller.add(snapshot);
  }

  @override
  Future<void> dispose() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
