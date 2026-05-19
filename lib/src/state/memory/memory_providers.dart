import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_update.dart';
import '../../models/social_models.dart';
import '../app_state.dart';
import 'file_memory_store.dart';
import 'memory_document.dart';
import 'memory_store.dart';

/// Active [MemoryStore] for the running app. Production returns the
/// file-backed adapter writing to `<app_documents>/memories/` per
/// PRD Q6. Tests override it with `InMemoryMemoryStore` (or a
/// `FileMemoryStore` rooted at a temp directory) to install a
/// pre-populated store or skip seeding.
final memoryStoreProvider = Provider<MemoryStore>(
  (ref) => FileMemoryStore(),
);

/// Unified [AiUpdate] adapter (PRD Q1).
///
/// Production returns a [MockAiUpdate] wired to the active store and
/// the live [AppController]. Tests override either this provider
/// directly (to install a stub) or [memoryStoreProvider] alone (since
/// the production adapter reads whatever store override is in place).
///
/// `ref.read` for the controller — the adapter just needs a handle and
/// does not need to react to AppState changes. `ref.watch` for the
/// store so swapping the store override in tests takes effect.
final aiUpdateProvider = Provider<AiUpdate>((ref) {
  return MockAiUpdate(
    memoryStore: ref.watch(memoryStoreProvider),
    appController: ref.read(appControllerProvider.notifier),
  );
});

/// Per-contact [MemoryDocument] (family by `contactId`).
///
/// Lazy-creates an empty document via the store when none exists, so
/// connections added between Pass 2 and Pass 3 — or any contact missed
/// by the seed migration — get a sensible empty memory on first
/// observe rather than null.
final memoryProvider =
    FutureProvider.family<MemoryDocument, String>((ref, contactId) async {
  final store = ref.watch(memoryStoreProvider);
  final connections = ref.watch(
    appControllerProvider.select((state) => state.connections),
  );

  final loaded = await store.load(contactId);
  if (loaded != null) return loaded;

  final connection = _findConnection(connections, contactId);
  final empty = MemoryDocument.empty(
    contactId: contactId,
    displayName: connection?.name ?? contactId,
  );
  await store.save(empty);
  return empty;
});

/// One-shot bootstrap that runs the seed migration on first observe.
///
/// Filesystem-inferred state per PRD Q9: if the store is empty AND
/// there is at least one connection, write one [MemoryDocument] per
/// existing connection populated from the connection's seed `notes`
/// (becomes `summary`) and a small category-derived starter topics
/// list. If the store is non-empty, do nothing — the seed has already
/// run, or a test has pre-populated it.
final memorySeedingProvider = FutureProvider<void>((ref) async {
  final store = ref.watch(memoryStoreProvider);
  final connections = ref.watch(
    appControllerProvider.select((state) => state.connections),
  );

  final existing = await store.listAll();
  if (existing.isNotEmpty) return;
  if (connections.isEmpty) return;

  final now = DateTime.now();
  for (final connection in connections) {
    final doc = MemoryDocument(
      contactId: connection.id,
      displayName: connection.name,
      lastUpdated: now,
      version: 1,
      summary: connection.notes,
      topics: _starterTopicsFor(connection.category),
    );
    await store.save(doc);
  }
});

Connection? _findConnection(List<Connection> connections, String contactId) {
  for (final connection in connections) {
    if (connection.id == contactId) return connection;
  }
  return null;
}

/// Tiny category → starter topics map. Lower-case for matching, kept
/// intentionally small; the real topic engine lands in #043.
List<String> _starterTopicsFor(String category) {
  switch (category) {
    case 'Family':
      return const ['family'];
    case 'Friends':
      return const ['friends'];
    case 'Work':
      return const ['work'];
    case 'College':
      return const ['college'];
    case 'High School':
      return const ['high school'];
    default:
      return const [];
  }
}
