import '../app_state.dart';

/// Snapshot of the user-doc fields AppController cares about.
///
/// PRD §Q12: `categories` and `eventTypes` are user data, not app
/// preferences. They live as list fields on `users/{uid}` and travel
/// with the auth account. Sentinels (`*SeededAt`) are not exposed on
/// this snapshot — those are owned by the seeder (#069) and read
/// directly from the user doc when it runs.
class UserDocSnapshot {
  const UserDocSnapshot({
    required this.categories,
    required this.eventTypes,
  });

  final List<String> categories;
  final List<String> eventTypes;

  /// Empty snapshot used as the initial value for an unseeded user
  /// or for the signed-out sentinel. AppController falls back to the
  /// seed defaults when this is the active snapshot, so a pre-seeder
  /// frame on a fresh sign-in does not blank out the UI's category
  /// pickers.
  static const UserDocSnapshot empty = UserDocSnapshot(
    categories: <String>[],
    eventTypes: <String>[],
  );

  bool get isEmpty => categories.isEmpty && eventTypes.isEmpty;
}

/// Async persistence boundary for the per-user document fields
/// AppController needs (Pass 4.5 #070, PRD §Q12).
///
/// Mirrors [ConnectionStore] / [InteractionStore] / [EventStore]
/// from #064 / #067 / #068. Two adapters: an in-memory adapter for
/// tests and override-driven widget tests, and a Firestore-backed
/// adapter that reads / writes `users/{uid}` document fields.
///
/// Why a dedicated store: these two lists are not their own
/// subcollection (PRD §Q12 — they are tiny and fit inline on the
/// user doc). The adapter exists to keep the same snapshot-listener
/// shape as the other stores so AppController has a uniform
/// `watch + listen + dispose` lifecycle for everything it depends
/// on.
abstract interface class UserDocStore {
  /// Persist a new categories list. Replaces the current value.
  Future<void> saveCategories(List<String> categories);

  /// Persist a new event-types list. Replaces the current value.
  Future<void> saveEventTypes(List<String> eventTypes);

  /// Broadcast stream of the latest [UserDocSnapshot]. Adapters emit
  /// on save and on cross-instance updates (e.g. another device).
  /// Subscribers should treat the emitted snapshot as immutable.
  Stream<UserDocSnapshot> snapshot();

  /// Synchronous read of the most recent snapshot. Returns null
  /// until the first emission, then the current snapshot for the
  /// lifetime of the adapter.
  UserDocSnapshot? snapshotSync();

  /// Releases any resources held by this store. Idempotent.
  Future<void> dispose();
}

/// Default seed values. Reused by the in-memory adapter and by the
/// AppController initial-state hydration when no snapshot has fired
/// yet. Kept here so the seam owns the fallback rather than letting
/// every caller read [AppState.seeded] for the same constants.
class UserDocDefaults {
  const UserDocDefaults._();

  static List<String> categories() => AppState.seeded().categories;
  static List<String> eventTypes() => AppState.seeded().eventTypes;
}
