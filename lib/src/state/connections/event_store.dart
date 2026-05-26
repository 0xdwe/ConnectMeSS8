import '../../models/social_models.dart';

/// Async persistence boundary for [PlannerEvent] documents
/// (Pass 4.5 #068).
///
/// Mirrors [ConnectionStore] from #064 / #065 and
/// [InteractionStore] from #067. Two adapters land in Pass 4.5: an
/// in-memory adapter for tests and override-driven widget tests,
/// and a Firestore-backed adapter bound to one UID reading from
/// `users/{uid}/events/{eventId}`.
///
/// The interface adds a [snapshot] stream and a synchronous
/// [snapshotSync] mirror getter on top of load / save / delete /
/// listAll, matching the snapshot-listener contract Pass 4.5 §Q6
/// adopted in #065.
abstract interface class EventStore {
  /// Returns the stored event for `eventId`, or null on miss.
  Future<PlannerEvent?> load(String eventId);

  /// Persists `event`, keyed by `event.id`. Overwrites any existing
  /// entry for that id.
  Future<void> save(PlannerEvent event);

  /// Removes the event for `eventId`. No-op when missing.
  Future<void> delete(String eventId);

  /// Returns a snapshot of every stored event, keyed by id.
  Future<Map<String, PlannerEvent>> listAll();

  /// Broadcast stream of the latest `Map<String, PlannerEvent>`
  /// snapshot.
  ///
  /// Adapters emit on save, delete, and on cross-instance updates.
  /// Subscribers should treat the emitted map as immutable.
  Stream<Map<String, PlannerEvent>> snapshot();

  /// Synchronous read of the most recent snapshot.
  ///
  /// Returns null until the first snapshot has emitted; an empty
  /// map for the signed-out sentinel and for signed-in-but-empty
  /// stores after their first emission; the current map otherwise.
  Map<String, PlannerEvent>? snapshotSync();

  /// Releases any resources held by this store. Idempotent.
  Future<void> dispose();
}
