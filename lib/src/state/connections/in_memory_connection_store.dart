import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../models/social_models.dart';
import 'connection_store.dart';

/// In-process [ConnectionStore] backed by a plain [Map]. Used in
/// tests and as the override target for headless widget tests; the
/// Firestore-backed adapter lands in #065.
///
/// Mutations broadcast a fresh unmodifiable snapshot on the
/// [snapshot] stream so widgets and providers can subscribe to the
/// same shape they will see from [FirebaseConnectionStore]. The
/// stream is broadcast — multiple listeners are supported, and the
/// store does not buffer events for late subscribers; instead, the
/// current mirror is replayed on first subscribe (after at least
/// one mutation) so callers do not need to combine an initial
/// `listAll()` with the stream.
class InMemoryConnectionStore implements ConnectionStore {
  final Map<String, Connection> _store = {};
  final StreamController<Map<String, Connection>> _controller =
      StreamController<Map<String, Connection>>.broadcast();
  Map<String, Connection>? _mirror;

  @override
  Future<Connection?> load(String contactId) async {
    return _store[contactId];
  }

  @override
  Future<void> save(Connection connection) async {
    _store[connection.id] = connection;
    _publish();
  }

  @override
  Future<void> delete(String contactId) async {
    _store.remove(contactId);
    _publish();
  }

  @override
  Future<Map<String, Connection>> listAll() async {
    return Map.unmodifiable(Map<String, Connection>.from(_store));
  }

  @override
  Stream<Map<String, Connection>> snapshot() {
    // Broadcast streams do not buffer for late subscribers. Wrap with
    // a controller that replays the current mirror on subscribe so
    // callers see a deterministic first event without having to
    // combine listAll() and the stream themselves.
    late StreamController<Map<String, Connection>> controller;
    StreamSubscription<Map<String, Connection>>? sub;
    controller = StreamController<Map<String, Connection>>(
      onListen: () {
        final current = _mirror;
        if (current != null) controller.add(current);
        sub = _controller.stream.listen(controller.add,
            onError: controller.addError, onDone: controller.close);
      },
      onCancel: () async {
        await sub?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  @override
  Map<String, Connection>? snapshotSync() => _mirror;

  /// Empties the store and broadcasts an empty snapshot. Helpful in
  /// tests; not part of the [ConnectionStore] contract.
  Future<void> clear() async {
    _store.clear();
    _publish();
  }

  /// Test-only synchronous seeding hatch.
  ///
  /// Populates the underlying map without setting [snapshotSync]'s
  /// mirror, so subsequent subscribers to [snapshot] do NOT receive
  /// a replay event. This is what makes the hatch safe to call
  /// from `signedInDemoOverrides()` during `ProviderContainer`
  /// setup: AppController's snapshot subscription will not fire an
  /// initial event that mutates `state.connections` mid-load and
  /// invalidates downstream FutureProviders (the regression on
  /// PR #1 / commit 3412a76 that affected
  /// `test/state/memory/`).
  ///
  /// Tests that need `state.connections` populated rely on
  /// `AppState.seeded()` — the controller's initial build value —
  /// which already carries the same sample contacts. Tests that
  /// need the store's mirror populated (e.g. cross-instance write
  /// scenarios) should call [save] directly and `await` it.
  ///
  /// Not part of the [ConnectionStore] interface.
  @visibleForTesting
  void seedSync(Iterable<Connection> connections) {
    for (final connection in connections) {
      _store[connection.id] = connection;
    }
  }

  void _publish() {
    final snapshot = Map<String, Connection>.unmodifiable(
      Map<String, Connection>.from(_store),
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
