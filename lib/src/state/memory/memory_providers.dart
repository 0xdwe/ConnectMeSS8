import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_update.dart';
import '../../ai/llm_ai_update.dart';
import '../../models/social_models.dart';
import '../app_state.dart';
import '../firebase_providers.dart';
import '../recommendation_engine.dart';
import 'disk_to_firestore_migration.dart';
import 'file_memory_store.dart';
import 'firebase_memory_store.dart';
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

final memoryEpochProvider = NotifierProvider<MemoryEpochNotifier, DateTime?>(
  MemoryEpochNotifier.new,
);

/// Active [MemoryStore] for the running app (Pass 4.2, #058).
///
/// Watches `currentUserProvider`. When a user is signed in, returns
/// a `FirebaseMemoryStore` bound to that UID and the active
/// `firestoreProvider`. When signed out (or while the auth stream is
/// still loading), returns a [_SignedOutMemoryStore] sentinel whose
/// every operation throws so accidental signed-out reads fail loudly
/// in dev rather than silently appearing to work against an empty
/// store.
///
/// Auth changes rebuild this provider, which in turn invalidates
/// every downstream memory consumer ([memoryProvider],
/// [memoryTopicsProvider], [recommendationsProvider], and the
/// seeding bootstrap below). The previous user's store instance is
/// discarded; a brand-new `FirebaseMemoryStore` is constructed for
/// the next user. There is no path by which a signed-in store
/// instance can outlive its UID.
///
/// Tests override this provider with `InMemoryMemoryStore` (or a
/// pre-populated `FirebaseMemoryStore`) directly, in which case the
/// auth-aware logic is bypassed entirely — the override always wins.
/// The 14 widget tests already follow this pattern.
final memoryStoreProvider = Provider<MemoryStore>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const _SignedOutMemoryStore();
  }
  final firestore = ref.watch(firestoreProvider);
  return FirebaseMemoryStore(firestore: firestore, uid: user.uid);
});

/// Sentinel returned by [memoryStoreProvider] while signed out
/// (Pass 4.2, #058). Every method throws [StateError] so a
/// signed-out read surfaces immediately instead of silently
/// returning empty data.
///
/// Production code paths that touch memory live behind the
/// authenticated app shell, so this should never be hit in the
/// running app. The sentinel exists for tests, for ordering bugs
/// during sign-out, and as a defensive guard.
class _SignedOutMemoryStore implements MemoryStore {
  const _SignedOutMemoryStore();

  static const String _msg = 'Memory is not available while signed out.';

  @override
  Future<MemoryDocument?> load(String contactId) =>
      Future.error(StateError(_msg));

  @override
  Future<void> save(MemoryDocument doc) => Future.error(StateError(_msg));

  @override
  Future<void> delete(String contactId) => Future.error(StateError(_msg));

  @override
  Future<Map<String, MemoryDocument>> listAll() =>
      Future.error(StateError(_msg));
}

/// Unified [AiUpdate] adapter (PRD Pass 4.3 §Q9 / #081).
///
/// Production now binds [LlmAiUpdate] for signed-in users (the
/// real Gemini-backed adapter). [MockAiUpdate] remains as a
/// deterministic test fixture; tests reach for it by overriding
/// this provider directly with a `MockAiUpdate(...)` instance.
///
/// Signed-out users hit the [_SignedOutAiUpdate] sentinel whose
/// every call throws [StateError]. This mirrors the
/// [_SignedOutMemoryStore] guard from Pass 4.2 #058 — the AI
/// Update flow lives behind the authenticated app shell, so this
/// branch should never be reached in production. The sentinel
/// exists for tests, for ordering bugs around sign-out, and as a
/// defensive guard.
///
/// `recentInteractionsLookup` reads from the live
/// [AppController.state.interactions] filtered by contactId,
/// most-recent-first, capped at
/// [_aiUpdateRecentInteractionsCap]. The cap keeps prompt size
/// bounded for deep-history contacts; #078 builds the prompt
/// section, this is just the source.
///
/// `onMemoryWritten` continues to bump [memoryEpochProvider] so
/// `recommendationsProvider` sees the memory-change half of the
/// PRD Q2 dual invalidation. Both adapters honor the hook.
final aiUpdateProvider = Provider<AiUpdate>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const _SignedOutAiUpdate();
  }
  final memoryStore = ref.watch(memoryStoreProvider);
  final firebaseAi = ref.watch(firebaseAiProvider);
  final appController = ref.read(appControllerProvider.notifier);
  return LlmAiUpdate(
    firebaseAi: firebaseAi,
    memoryStore: memoryStore,
    appController: appController,
    recentInteractionsLookup: (contactId) {
      // Most-recent-first slice of [AppState.interactions] bounded
      // at the cap below. AppController stores interactions in
      // insertion order; we sort by date desc to be explicit and
      // robust to future changes in storage order.
      final all =
          ref
              .read(appControllerProvider)
              .interactions
              .where((i) => i.contactId == contactId)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
      if (all.length > _aiUpdateRecentInteractionsCap) {
        return all.sublist(0, _aiUpdateRecentInteractionsCap);
      }
      return all;
    },
    onMemoryWritten: () {
      final clock = ref.read(clockProvider);
      ref.read(memoryEpochProvider.notifier).bump(clock());
    },
  );
});

/// Cap on how many recent CrmInteractions ride along in the LLM
/// prompt (PRD §Q5 prompt-size budget). Tens of recent updates
/// already saturate Gemini's context with the existing memory
/// markdown; this is the practical horizon for prompt freshness.
const int _aiUpdateRecentInteractionsCap = 10;

/// Sentinel returned by [aiUpdateProvider] while signed out
/// (Pass 4.3 #081). Every method throws [StateError] so a signed-
/// out AI Update attempt surfaces immediately instead of silently
/// hitting the SDK or running the Mock.
class _SignedOutAiUpdate implements AiUpdate {
  const _SignedOutAiUpdate();

  static const String _msg = 'AI Update is not available while signed out.';

  @override
  Future<AiUpdateResult> run({
    required Connection contact,
    required String userInput,
    required MemoryDocument currentMemory,
    required List<AttachmentRef> attachments,
    Future<void>? cancelToken,
    Future<void> Function()? onClassifierPassed,
  }) => Future.error(StateError(_msg));

  @override
  Future<void> commit(AiUpdateResult result) => Future.error(StateError(_msg));
}

/// Freshness window for the [recommendationsProvider] cache (PRD Q2).
///
/// Named so the 2h–24h tuning range called out in the PRD is a
/// one-line edit. Six hours is the starting knob.
const Duration recommendationsFreshness = Duration(hours: 6);

/// Internal cache tuple for [RecommendationsNotifier].
///
/// Holds the engine output alongside the wall-clock time at which it
/// was computed, plus identity-comparable references to the dep
/// slices the engine consumed. The notifier checks all five
/// invariants (time, memory epoch, store identity, connections
/// identity, interactions identity) to decide between serving the
/// cache or recomputing.
class _RecommendationsCache {
  const _RecommendationsCache({
    required this.computedAt,
    required this.list,
    required this.store,
    required this.connections,
    required this.interactions,
  });
  final DateTime computedAt;
  final List<Recommendation> list;
  final MemoryStore store;
  final List<Connection> connections;
  final List<CrmInteraction> interactions;
}

/// Maintenance Need recommendations with PRD Q2 dual invalidation:
/// recompute when **either** any memory has been saved
/// since `computedAt` (signalled via [memoryEpochProvider]) **or**
/// `now - computedAt > recommendationsFreshness`. Otherwise serve
/// the cached list.
///
/// Connection / interaction state changes also rebuild the provider
/// (via the `select` watches), and the cache invariant compares dep
/// references by identity — a new connections list (e.g. after
/// `addConnection`) skips the cache. Memory document changes are
/// signalled via [memoryEpochProvider]; when the cache is stale or
/// invalidated, the provider reloads [MemoryStore.listAll()] before
/// ranking.
///
/// Per PRD Q2 there is no background scheduler. The freshness check
/// runs on each read; a passive app whose state never changes
/// continues to serve the cache until the next read after the 6h
/// boundary, at which point the next read reloads memories and
/// recomputes.
class _RecommendationsCacheHolder {
  _RecommendationsCache? cache;
}

/// Module-level memory of the last recommendation list returned.
/// Survives Provider disposal during GoRouter navigation so
/// completion detection always has a previous list to diff against.
List<Recommendation>? lastRecommendationList;

final _recommendationsCacheProvider = Provider<_RecommendationsCacheHolder>(
  (_) => _RecommendationsCacheHolder(),
);

final recommendationsProvider = FutureProvider<List<Recommendation>>((
  ref,
) async {
  final holder = ref.watch(_recommendationsCacheProvider);
  final store = ref.watch(memoryStoreProvider);
  final connections = ref.watch(
    appControllerProvider.select((state) => state.connections),
  );
  final interactions = ref.watch(
    appControllerProvider.select((state) => state.interactions),
  );
  final memoryEpoch = ref.watch(memoryEpochProvider);
  final clock = ref.read(clockProvider);
  final now = clock();

  final cache = holder.cache;
  final isFresh =
      cache != null &&
      now.difference(cache.computedAt) < recommendationsFreshness &&
      (memoryEpoch == null || !memoryEpoch.isAfter(cache.computedAt)) &&
      identical(cache.store, store) &&
      identical(cache.connections, connections) &&
      identical(cache.interactions, interactions);

  if (isFresh) {
    return cache.list;
  }

  Map<String, MemoryDocument> memories;
  try {
    memories = await store.listAll();
  } catch (_) {
    memories = const {};
  }

  final list = rankRecommendations(
    connections: connections,
    interactions: interactions,
    memories: memories,
    now: now,
    previousList: lastRecommendationList,
    previousCacheTime:
        holder.cache?.computedAt ??
        now.subtract(recommendationsFreshness),
  );
  holder.cache = _RecommendationsCache(
    computedAt: now,
    list: list,
    store: store,
    connections: connections,
    interactions: interactions,
  );
  lastRecommendationList = list;
  return list;
});

/// Per-contact list of conversation topics (family by `contactId`).
///
/// Derived from [memoryProvider]: returns `MemoryDocument.topics` when
/// the doc resolves with topics, or an empty list otherwise. The
/// empty-list signal lets callers fall back to category defaults via
/// `topicsForContact` without binding this provider to widget code.
final memoryTopicsProvider = Provider.family<List<String>, String>((
  ref,
  contactId,
) {
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
final memoryProvider = FutureProvider.family<MemoryDocument, String>((
  ref,
  contactId,
) async {
  final store = ref.watch(memoryStoreProvider);
  ref.watch(memoryEpochProvider); // Trigger automatic reload when memory epoch changes

  final loaded = await store.load(contactId);
  if (loaded != null) return loaded;

  final connection = _findConnection(
    ref.read(appControllerProvider).connections,
    contactId,
  );
  final empty = MemoryDocument.empty(
    contactId: contactId,
    displayName: connection?.name ?? contactId,
  );
  await store.save(empty);
  return empty;
});

/// One-shot disk-to-Firestore migration on first authenticated
/// observe (Pass 4.2 #059, PRD Q6).
///
/// No-ops while signed out, when the sentinel is already set against
/// a non-empty remote, or when there are no local source files. By
/// the time this provider's future resolves, [memorySeedingProvider]
/// is safe to read: any local-disk markdown has either been migrated
/// into the user's Firestore collection or proven unrecoverable.
///
/// Why a fresh `FileMemoryStore` is constructed here instead of
/// reading [memoryStoreProvider]: the provider returns the
/// _target_ store (Firestore-backed once a user is signed in). The
/// migration source is the legacy on-disk markdown adapter and must
/// always be `FileMemoryStore`, regardless of what production
/// memory writes go through today.
///
/// Returns the count of documents successfully migrated. Tests can
/// `await container.read(diskToFirestoreMigrationProvider.future)`
/// to drive the migration deterministically.
final diskToFirestoreMigrationProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;

  final store = ref.watch(memoryStoreProvider);
  if (store is _SignedOutMemoryStore) return 0;
  // Migration only makes sense when the target is the Firestore
  // adapter. Tests that override `memoryStoreProvider` with
  // `InMemoryMemoryStore` skip migration entirely — they're not
  // exercising the disk→Firestore boundary.
  if (store is! FirebaseMemoryStore) return 0;

  final firestore = ref.watch(firestoreProvider);
  final migration = DiskToFirestoreMigration(
    source: FileMemoryStore(),
    target: store,
    sentinel: FirestoreMigrationSentinel(firestore: firestore, uid: user.uid),
  );
  return migration.ensureMigrated();
});

/// One-shot bootstrap that runs the seed migration on first observe.
///
/// Filesystem-inferred state per PRD Q9: if the store is empty AND
/// there is at least one connection, write one [MemoryDocument] per
/// existing connection populated from the connection's seed `notes`
/// (becomes `summary`) and a small category-derived starter topics
/// list. If the store is non-empty, do nothing — the seed has already
/// run, or a test has pre-populated it.
///
/// **Auth-aware (Pass 4.2, #058).** No-ops while signed out. With
/// the [memoryStoreProvider] now scoped per Firebase UID, seeding
/// runs after the first sign-in for an account whose Firestore
/// memories collection is empty. The behavioral change from Pass 3
/// is intentional: in Pass 3 the seed ran at install time against a
/// device-local store; in Pass 4.2 the seed follows the user, not
/// the install.
///
/// **Migration takes priority over re-seeding (Pass 4.2, #059).**
/// We `await` the disk-to-Firestore migration first. If the user has
/// existing on-device markdown memories, those are restored into the
/// remote collection. The non-empty-listAll guard below then sees
/// the migrated docs and skips re-seeding, so a returning user is
/// never given fresh seed docs on top of their actual history.
final memorySeedingProvider = FutureProvider<void>((ref) async {
  // Bail out before touching the store if no user is signed in. The
  // sentinel store would throw on `listAll`, but bailing here avoids
  // even constructing the call.
  final user = ref.watch(currentUserProvider);
  if (user == null) return;

  final store = ref.watch(memoryStoreProvider);
  // Defense-in-depth: if a test (or some race) leaves the sentinel in
  // place despite a signed-in user, skip seeding rather than throw.
  if (store is _SignedOutMemoryStore) return;

  // Migration first. The non-empty listAll guard below makes this
  // safe to skip if the store override doesn't go through Firestore
  // — `diskToFirestoreMigrationProvider` itself returns 0 in that
  // case so widget tests that override `memoryStoreProvider` are
  // unaffected.
  await ref.watch(diskToFirestoreMigrationProvider.future);

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
