import '../../models/social_models.dart';

/// Async persistence boundary for [Connection] documents (Pass 4.5).
///
/// Mirrors the [MemoryStore] seam from Pass 3 / Pass 4.2. Two
/// adapters land in Pass 4.5: an in-memory adapter for tests and
/// override-driven widget tests, and a Firestore-backed adapter
/// (#065) bound to one UID and reading from
/// `users/{uid}/connections/{contactId}`.
///
/// The interface adds a [snapshot] stream and a synchronous
/// [snapshotSync] mirror getter on top of the load / save / delete /
/// listAll surface, so the snapshot-listener pattern Pass 4.5 Q6
/// adopts has a clean contract from day one. Adapters that do not
/// stream natively — like [InMemoryConnectionStore] — still expose
/// the same surface by broadcasting a fresh map on every mutation.
abstract interface class ConnectionStore {
  /// Returns the stored connection for `contactId`, or null on miss.
  Future<Connection?> load(String contactId);

  /// Persists `connection`, keyed by `connection.id`. Overwrites any
  /// existing entry for that id.
  Future<void> save(Connection connection);

  /// Removes the connection for `contactId`. No-op when missing.
  Future<void> delete(String contactId);

  /// Returns a snapshot of every stored connection, keyed by id.
  Future<Map<String, Connection>> listAll();

  /// Broadcast stream of the latest `Map<String, Connection>` snapshot.
  ///
  /// Adapters emit on save, delete, and on cross-instance updates.
  /// Subscribers should treat the emitted map as immutable. Closes
  /// with the store's lifetime — for the auth-aware provider, that
  /// means until sign-out tears the store down via `onDispose`.
  Stream<Map<String, Connection>> snapshot();

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
  Map<String, Connection>? snapshotSync();

  /// Releases any resources held by this store.
  ///
  /// Called once by `connectionStoreProvider.onDispose` when the
  /// auth UID changes (sign-out, swap-to-different-user, app
  /// teardown). Implementations close any open broadcast
  /// controllers and Firestore snapshot subscriptions. Idempotent —
  /// calling more than once must not throw.
  Future<void> dispose();
}
