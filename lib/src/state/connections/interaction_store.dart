import '../../models/social_models.dart';

/// Async persistence boundary for [CrmInteraction] documents
/// (Pass 4.5 #067).
///
/// Mirrors [ConnectionStore] from #064 / #065. Two adapters land in
/// Pass 4.5: an in-memory adapter for tests and override-driven
/// widget tests, and a Firestore-backed adapter bound to one UID
/// reading from `users/{uid}/interactions/{interactionId}`.
///
/// The interface adds a [snapshot] stream and a synchronous
/// [snapshotSync] mirror getter on top of load / save / delete /
/// listAll, matching the snapshot-listener contract Pass 4.5 §Q6
/// adopted in #065. Adapters that do not stream natively — like
/// [InMemoryInteractionStore] — still expose the same surface by
/// broadcasting a fresh map on every mutation.
abstract interface class InteractionStore {
  /// Returns the stored interaction for `interactionId`, or null on
  /// miss.
  Future<CrmInteraction?> load(String interactionId);

  /// Persists `interaction`, keyed by `interaction.id`. Overwrites
  /// any existing entry for that id.
  Future<void> save(CrmInteraction interaction);

  /// Removes the interaction for `interactionId`. No-op when missing.
  Future<void> delete(String interactionId);

  /// Returns a snapshot of every stored interaction, keyed by id.
  Future<Map<String, CrmInteraction>> listAll();

  /// Broadcast stream of the latest `Map<String, CrmInteraction>`
  /// snapshot.
  ///
  /// Adapters emit on save, delete, and on cross-instance updates.
  /// Subscribers should treat the emitted map as immutable. Closes
  /// with the store's lifetime — for the auth-aware provider, that
  /// means until sign-out tears the store down via `onDispose`.
  Stream<Map<String, CrmInteraction>> snapshot();

  /// Synchronous read of the most recent snapshot.
  ///
  /// Returns:
  ///   - `null` if no snapshot has been emitted yet (e.g. a freshly
  ///     constructed adapter before the first save or before the
  ///     Firestore listener resolves).
  ///   - An empty map (`{}`) for the signed-out sentinel and for
  ///     signed-in-but-empty stores after their first emission.
  ///   - The current map otherwise.
  ///
  /// Callers that need to distinguish "loading" from "signed-out"
  /// should read `currentUserProvider` alongside this getter.
  Map<String, CrmInteraction>? snapshotSync();

  /// Releases any resources held by this store.
  ///
  /// Called once by `interactionStoreProvider.onDispose` when the
  /// auth UID changes (sign-out, swap-to-different-user, app
  /// teardown). Implementations close any open broadcast
  /// controllers and Firestore snapshot subscriptions. Idempotent —
  /// calling more than once must not throw.
  Future<void> dispose();
}
