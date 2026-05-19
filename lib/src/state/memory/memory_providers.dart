import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_update.dart';
import '../../models/social_models.dart';
import '../app_state.dart';
import '../recommendation_engine.dart';
import 'file_memory_store.dart';
import 'memory_document.dart';
import 'memory_store.dart';

/// Test-injectable wall clock. Production returns [DateTime.now];
/// tests override with a fake that advances on demand to drive the
/// 6h freshness boundary in [recommendationsProvider] without
/// actually waiting on a real timer.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Monotonic timestamp that ticks forward every time any memory file
/// is saved. Read by [recommendationsProvider] to detect the
/// memory-change half of the PRD Q2 dual invalidation.
///
/// Null at startup; bumped to `clock()` after every successful
/// `MemoryStore.save` from [MockAiUpdate.commit] (wired through the
/// `onMemoryWritten` callback on [aiUpdateProvider]).
///
/// Uses a [Notifier] rather than the legacy `StateProvider` because
/// only `Notifier`-family providers are exported from the modern
/// flutter_riverpod surface this project uses.
class MemoryEpochNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  /// Bump the epoch to [now]. Listeners (notably
  /// [RecommendationsNotifier]) rebuild on the next read.
  void bump(DateTime now) => state = now;
}

final memoryEpochProvider =
    NotifierProvider<MemoryEpochNotifier, DateTime?>(MemoryEpochNotifier.new);

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
///
/// The `onMemoryWritten` callback bumps [memoryEpochProvider] after a
/// successful save so [recommendationsProvider] sees the
/// memory-change half of the PRD Q2 invalidation on the very next
/// read.
final aiUpdateProvider = Provider<AiUpdate>((ref) {
  return MockAiUpdate(
    memoryStore: ref.watch(memoryStoreProvider),
    appController: ref.read(appControllerProvider.notifier),
    onMemoryWritten: () {
      final clock = ref.read(clockProvider);
      ref.read(memoryEpochProvider.notifier).bump(clock());
    },
  );
});

/// Freshness window for the [recommendationsProvider] cache (PRD Q2).
///
/// Named so the 2h–24h tuning range called out in the PRD is a
/// one-line edit. Six hours is the starting knob.
const Duration recommendationsFreshness = Duration(hours: 6);

/// Internal cache tuple for [RecommendationsNotifier].
///
/// Holds the engine output alongside the wall-clock time at which it
/// was computed, plus identity-comparable references to the dep
/// slices the engine consumed. The notifier checks all four
/// invariants (time, memory epoch, connections identity,
/// interactions identity) to decide between serving the cache or
/// recomputing.
class _RecommendationsCache {
  const _RecommendationsCache({
    required this.computedAt,
    required this.list,
    required this.connections,
    required this.interactions,
  });
  final DateTime computedAt;
  final List<Recommendation> list;
  final List<Connection> connections;
  final List<CrmInteraction> interactions;
}

/// Bond-tier-weighted recency recommendations with PRD Q2 dual
/// invalidation: recompute when **either** any memory has been saved
/// since `computedAt` (signalled via [memoryEpochProvider]) **or**
/// `now - computedAt > recommendationsFreshness`. Otherwise serve
/// the cached list.
///
/// Connection / interaction state changes also rebuild the notifier
/// (via the `select` watches), and the cache invariant compares dep
/// references by identity — a new connections list (e.g. after
/// `addConnection`) skips the cache. Memory changes do not flow
/// through `select` (the engine does not yet read memories), so
/// [memoryEpochProvider] is the explicit signal from
/// [MockAiUpdate.commit].
///
/// Per PRD Q2 there is no background scheduler. The freshness check
/// runs on each read; a passive app whose state never changes
/// continues to serve the cache until the next read after the 6h
/// boundary, at which point the next read recomputes.
class RecommendationsNotifier extends Notifier<List<Recommendation>> {
  _RecommendationsCache? _cache;

  @override
  List<Recommendation> build() {
    final connections = ref.watch(
      appControllerProvider.select((state) => state.connections),
    );
    final interactions = ref.watch(
      appControllerProvider.select((state) => state.interactions),
    );
    final memoryEpoch = ref.watch(memoryEpochProvider);
    final clock = ref.read(clockProvider);
    final now = clock();

    final cache = _cache;
    final isFresh = cache != null &&
        now.difference(cache.computedAt) < recommendationsFreshness &&
        (memoryEpoch == null || !memoryEpoch.isAfter(cache.computedAt)) &&
        identical(cache.connections, connections) &&
        identical(cache.interactions, interactions);

    if (isFresh) {
      return cache.list;
    }

    final list = rankRecommendations(
      connections: connections,
      interactions: interactions,
      memories: const {},
      now: now,
    );
    _cache = _RecommendationsCache(
      computedAt: now,
      list: list,
      connections: connections,
      interactions: interactions,
    );
    return list;
  }
}

final recommendationsProvider =
    NotifierProvider<RecommendationsNotifier, List<Recommendation>>(
  RecommendationsNotifier.new,
);

/// Per-contact list of conversation topics (family by `contactId`).
///
/// Derived from [memoryProvider]: returns `MemoryDocument.topics` when
/// the doc resolves with topics, or an empty list otherwise. The
/// empty-list signal lets callers fall back to category defaults via
/// `topicsForContact` without binding this provider to widget code.
final memoryTopicsProvider =
    Provider.family<List<String>, String>((ref, contactId) {
  final memory = ref.watch(memoryProvider(contactId));
  return memory.maybeWhen(
    data: (doc) => doc.topics,
    orElse: () => const <String>[],
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
