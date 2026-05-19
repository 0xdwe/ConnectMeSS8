import 'memory_document.dart';
import 'memory_store.dart';

/// In-process [MemoryStore] backed by a plain [Map]. Used in tests and
/// as the default in this Pass 3 walking-skeleton slice; #041 swaps the
/// production override to a file-backed adapter.
class InMemoryMemoryStore implements MemoryStore {
  final Map<String, MemoryDocument> _store = {};

  @override
  Future<MemoryDocument?> load(String contactId) async {
    return _store[contactId];
  }

  @override
  Future<void> save(MemoryDocument doc) async {
    _store[doc.contactId] = doc;
  }

  @override
  Future<void> delete(String contactId) async {
    _store.remove(contactId);
  }

  @override
  Future<Map<String, MemoryDocument>> listAll() async {
    return Map.unmodifiable(Map<String, MemoryDocument>.from(_store));
  }
}
