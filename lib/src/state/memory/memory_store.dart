import 'memory_document.dart';

/// Async persistence boundary for per-contact memory documents.
///
/// Two adapters land in Pass 3: an in-memory store for tests (and as
/// the default while #041 brings file persistence online), and a future
/// file-backed store. The interface stays async so swapping in either
/// adapter — or a Firebase-backed one in Pass 4+ — does not force a
/// sync→async re-shape at every call site.
abstract interface class MemoryStore {
  /// Returns the stored document for `contactId`, or null on miss.
  Future<MemoryDocument?> load(String contactId);

  /// Persists `doc`, keyed by `doc.contactId`. Overwrites any existing
  /// document for that id.
  Future<void> save(MemoryDocument doc);

  /// Removes the document for `contactId`. No-op when missing.
  Future<void> delete(String contactId);

  /// Returns a snapshot of every stored document, keyed by `contactId`.
  Future<Map<String, MemoryDocument>> listAll();
}
