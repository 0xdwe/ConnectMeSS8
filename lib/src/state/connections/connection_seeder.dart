import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/social_models.dart';
import '../app_state.dart';
import 'firebase_connection_store.dart';
import 'firebase_event_store.dart';
import 'firebase_interaction_store.dart';

/// Pass 4.5 first-launch seeder. The user picks the choice once at
/// signup (#074); this service writes the corresponding documents
/// + sentinels exactly once per UID.
///
/// Vocabulary note: PRD §Q7 distinguishes this from Pass 4.2's
/// `DiskToFirestoreMigration`. The Pass 4.2 migration was a real
/// disk → cloud copy of [FileMemoryStore] documents that existed on
/// the user's device. Pass 4.5's connection / interaction / event
/// data was never on disk — it was always RAM, seeded from
/// constants in [AppState.seeded]. So this is a one-shot seeder, not
/// a migration. Class names and tests reflect that.
enum SeederChoice { samples, fresh }

/// Outcome of a single [ConnectionSeeder.run] call.
class SeederResult {
  const SeederResult({
    required this.didSeed,
    required this.didNoOp,
    required this.connectionsWritten,
    required this.interactionsWritten,
    required this.eventsWritten,
  });

  /// True if at least one document was written this run. Always
  /// true for a first-time `samples` choice on a fresh UID. False
  /// for `fresh` (sentinel-only) and for any idempotent re-run.
  final bool didSeed;

  /// True if every sentinel was already set when [run] was called,
  /// so this run wrote nothing at all. Mutually exclusive with
  /// [didSeed].
  final bool didNoOp;

  final int connectionsWritten;
  final int interactionsWritten;
  final int eventsWritten;

  static const SeederResult noOp = SeederResult(
    didSeed: false,
    didNoOp: true,
    connectionsWritten: 0,
    interactionsWritten: 0,
    eventsWritten: 0,
  );
}

/// Sentinel field names written on `users/{uid}` after each
/// collection's seeding finishes. Five separate timestamps mirror
/// the Pass 4.2 #059 `migratedFromDiskAt` shape and avoid
/// Map-shape validation in the rules.
class SeederSentinels {
  const SeederSentinels._();

  static const String connections = 'connectionsSeededAt';
  static const String interactions = 'interactionsSeededAt';
  static const String events = 'eventsSeededAt';
  static const String categories = 'categoriesSeededAt';
  static const String eventTypes = 'eventTypesSeededAt';

  static const List<String> all = <String>[
    connections,
    interactions,
    events,
    categories,
    eventTypes,
  ];
}

/// Plan computed from the current `users/{uid}` document state. Pure
/// data — no Firestore handle attached — so the planning logic can
/// be unit-tested headlessly without an emulator. The Firebase-bound
/// [ConnectionSeeder] consumes this plan and turns it into actual
/// batched writes.
class SeederPlan {
  const SeederPlan({
    required this.choice,
    required this.connections,
    required this.interactions,
    required this.events,
    required this.categories,
    required this.eventTypes,
    required this.connectionsSentinel,
    required this.interactionsSentinel,
    required this.eventsSentinel,
  });

  final SeederChoice choice;

  /// True if the connections collection should be seeded with
  /// samples this run.
  final bool connections;

  /// True if the interactions collection should be seeded with
  /// samples this run.
  final bool interactions;

  /// True if the events collection should be seeded with samples
  /// this run.
  final bool events;

  /// True if the user-doc `categories` field should be written
  /// this run. Always true on first run regardless of [choice]
  /// (PRD §Q12 — useful for fresh-start users too).
  final bool categories;

  /// True if the user-doc `eventTypes` field should be written
  /// this run.
  final bool eventTypes;

  /// True if the `connectionsSeededAt` sentinel should be written.
  /// Distinct from [connections] because the `fresh` branch sets
  /// the sentinel without writing samples — so the next launch
  /// short-circuits.
  final bool connectionsSentinel;

  /// True if the `interactionsSeededAt` sentinel should be written.
  final bool interactionsSentinel;

  /// True if the `eventsSeededAt` sentinel should be written.
  final bool eventsSentinel;

  /// True if every step is a no-op (sentinels for all five
  /// targets are already set).
  bool get isNoOp =>
      !connections &&
      !interactions &&
      !events &&
      !categories &&
      !eventTypes &&
      !connectionsSentinel &&
      !interactionsSentinel &&
      !eventsSentinel;
}

/// Computes the [SeederPlan] from the user-doc snapshot's existing
/// sentinel set and the user's [SeederChoice].
///
/// Plan rules:
///   * For each collection, the sample-write boolean is true ONLY
///     when the sentinel is unset AND the choice picks samples for
///     that collection. `fresh` writes empty collections, so its
///     plan booleans for connections/interactions/events are false.
///   * Each collection's sentinel-write boolean is true when the
///     sentinel is unset, regardless of choice. This is what makes
///     `fresh` sentinel-only without re-writing already-set
///     sentinels in a partial-state recovery.
///   * categories + eventTypes are seeded on first run regardless
///     of choice (PRD §Q12). Their sentinel write is fused with the
///     list write.
SeederPlan computePlan({
  required SeederChoice choice,
  required Set<String> existingSentinels,
}) {
  bool needs(String key) => !existingSentinels.contains(key);
  return SeederPlan(
    choice: choice,
    connections:
        choice == SeederChoice.samples && needs(SeederSentinels.connections),
    interactions:
        choice == SeederChoice.samples && needs(SeederSentinels.interactions),
    events: choice == SeederChoice.samples && needs(SeederSentinels.events),
    categories: needs(SeederSentinels.categories),
    eventTypes: needs(SeederSentinels.eventTypes),
    connectionsSentinel: needs(SeederSentinels.connections),
    interactionsSentinel: needs(SeederSentinels.interactions),
    eventsSentinel: needs(SeederSentinels.events),
  );
}

/// Source of truth for the seeded sample data. The Pass 3 / Pass
/// 4.x convention has been to keep one canonical seed in
/// [AppState.seeded], so [ConnectionSeeder] reads from there
/// instead of duplicating the seed list inline.
class SeederSampleSource {
  const SeederSampleSource._();

  static List<Connection> connections() => AppState.seeded().connections;
  static List<CrmInteraction> interactions() => AppState.seeded().interactions;
  static List<PlannerEvent> events() => AppState.seeded().events;

  static List<String> categories() => AppState.seeded().categories;
  static List<String> eventTypes() => AppState.seeded().eventTypes;
}

/// Writes connection / interaction / event sample documents and
/// sentinel timestamps on `users/{uid}` exactly once per UID
/// (Pass 4.5 #069).
///
/// **Atomicity.** Each branch uses a Firestore [WriteBatch] so the
/// sentinel write and the sample writes commit together. If the
/// commit fails, neither lands and the next launch sees an unset
/// sentinel and re-runs.
///
/// **Idempotency.** [run] reads the user doc first, computes a
/// [SeederPlan] over the existing sentinel set, and short-circuits
/// when every sentinel is already set. Partial-state recovery is
/// handled because the plan computes per-sentinel
/// (e.g. categoriesSeededAt is set but connectionsSeededAt is
/// unset → only the connections branch runs).
///
/// **No production trigger here.** This service is callable but no
/// production path calls it yet. The auto-trigger lands in #074
/// with the onboarding modal, so the choice can be persisted before
/// the seeder runs.
class ConnectionSeeder {
  ConnectionSeeder({required FirebaseFirestore firestore, required String uid})
    : _firestore = firestore,
      _uid = uid;

  final FirebaseFirestore _firestore;
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _userDocRef =>
      _firestore.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> _collection(String path) =>
      _userDocRef.collection(path);

  /// Read the current set of sentinels on `users/{uid}`.
  ///
  /// Returns the empty set when the user doc does not exist yet.
  /// Each sentinel is included only if its value is a [Timestamp];
  /// any other type is ignored (treated as unset) so a corrupt
  /// document does not block re-seeding.
  Future<Set<String>> _readExistingSentinels() async {
    final snap = await _userDocRef.get();
    if (!snap.exists) return <String>{};
    final data = snap.data();
    if (data == null) return <String>{};
    final out = <String>{};
    for (final key in SeederSentinels.all) {
      if (data[key] is Timestamp) out.add(key);
    }
    return out;
  }

  /// Run the seeder for [choice]. Idempotent — re-running with the
  /// same UID is a no-op once the sentinels are set.
  Future<SeederResult> run({required SeederChoice choice}) async {
    final existing = await _readExistingSentinels();
    final plan = computePlan(choice: choice, existingSentinels: existing);
    if (plan.isNoOp) {
      return SeederResult.noOp;
    }

    final batch = _firestore.batch();
    var connectionsWritten = 0;
    var interactionsWritten = 0;
    var eventsWritten = 0;

    if (plan.connections) {
      for (final c in SeederSampleSource.connections()) {
        batch.set(
          _collection('connections').doc(c.id),
          FirebaseConnectionStore.encode(c),
        );
        connectionsWritten++;
      }
    }

    if (plan.interactions) {
      for (final i in SeederSampleSource.interactions()) {
        batch.set(
          _collection('interactions').doc(i.id),
          FirebaseInteractionStore.encode(i),
        );
        interactionsWritten++;
      }
    }

    if (plan.events) {
      for (final e in SeederSampleSource.events()) {
        batch.set(
          _collection('events').doc(e.id),
          FirebaseEventStore.encode(e),
        );
        eventsWritten++;
      }
    }

    // User-doc sentinels. The sentinel-write booleans are distinct
    // from the sample-write booleans: `fresh` writes a
    // connectionsSeededAt sentinel without writing sample
    // connections (so the next launch short-circuits), but in a
    // partial-state recovery where the sentinel is already set, we
    // never re-write it. The previously valid timestamp survives.
    final userDocPatch = <String, dynamic>{};
    if (plan.connectionsSentinel) {
      userDocPatch[SeederSentinels.connections] = FieldValue.serverTimestamp();
    }
    if (plan.interactionsSentinel) {
      userDocPatch[SeederSentinels.interactions] = FieldValue.serverTimestamp();
    }
    if (plan.eventsSentinel) {
      userDocPatch[SeederSentinels.events] = FieldValue.serverTimestamp();
    }
    if (plan.categories) {
      userDocPatch['categories'] = SeederSampleSource.categories();
      userDocPatch[SeederSentinels.categories] = FieldValue.serverTimestamp();
    }
    if (plan.eventTypes) {
      userDocPatch['eventTypes'] = SeederSampleSource.eventTypes();
      userDocPatch[SeederSentinels.eventTypes] = FieldValue.serverTimestamp();
    }

    if (userDocPatch.isNotEmpty) {
      // Use set+merge so the user doc is created if absent and
      // existing fields (e.g. migratedFromDiskAt from #059) are
      // preserved.
      batch.set(_userDocRef, userDocPatch, SetOptions(merge: true));
    }

    await batch.commit();

    return SeederResult(
      didSeed: connectionsWritten + interactionsWritten + eventsWritten > 0,
      didNoOp: false,
      connectionsWritten: connectionsWritten,
      interactionsWritten: interactionsWritten,
      eventsWritten: eventsWritten,
    );
  }
}
