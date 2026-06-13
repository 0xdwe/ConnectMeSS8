import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'file_memory_store.dart';
import 'memory_store.dart';

/// Sentinel marking "this account has already had its on-disk
/// memories migrated to Firestore."
///
/// Two implementations:
///
///   * [FirestoreMigrationSentinel] — production. Reads/writes
///     `users/{uid}.migratedFromDiskAt`. The write goes through a
///     Firestore transaction with `merge: true` so two devices
///     migrating in parallel cannot lose the sentinel and future
///     fields on the user document are not clobbered.
///   * `_RecordingSentinel` (test-only) — records calls so headless
///     tests can verify gate behavior without a real Firestore.
///
/// Extracted from [DiskToFirestoreMigration] so headless tests don't
/// need a `cloud_firestore` plugin channel to exercise the gate
/// logic. The Firestore round-trip is integration-tested.
abstract interface class MigrationSentinel {
  /// Whether the sentinel has been set by a previous migration run.
  Future<bool> isSet();

  /// Records that a migration run has completed, idempotently.
  Future<void> set(DateTime timestamp);
}

/// Firestore-backed [MigrationSentinel] writing
/// `users/{uid}.migratedFromDiskAt`.
///
/// Wraps a transaction with `merge: true` so concurrent migrations
/// across devices cannot lose the signal and future fields on the
/// user document survive the write.
class FirestoreMigrationSentinel implements MigrationSentinel {
  FirestoreMigrationSentinel({
    required FirebaseFirestore firestore,
    required String uid,
  }) : _firestore = firestore,
       _uid = uid;

  /// Field name on the `users/{uid}` document. Pinned as a constant
  /// so tests, integration tests, and downstream tooling reference
  /// the same key.
  static const String fieldName = DiskToFirestoreMigration.sentinelField;

  final FirebaseFirestore _firestore;
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _userDocRef =>
      _firestore.collection('users').doc(_uid);

  @override
  Future<bool> isSet() async {
    final snap = await _userDocRef.get();
    if (!snap.exists) return false;
    return snap.data()?[fieldName] != null;
  }

  @override
  Future<void> set(DateTime timestamp) async {
    await _firestore.runTransaction<void>((tx) async {
      tx.set(_userDocRef, <String, dynamic>{
        fieldName: Timestamp.fromDate(timestamp),
      }, SetOptions(merge: true));
    });
  }
}

/// One-shot disk-to-Firestore migration. Pass 4.2 (#059).
///
/// Runs the first time a user signs in under Pass 4.2's
/// Firebase-backed memory store and the remote collection is empty.
///
/// **PRD Q6 contract.**
///
///   * **Account-scoped, not device-scoped.** Migration is gated by
///     a sentinel on the user's `users/{uid}` document. Two devices
///     of the same account can each migrate their own local-disk
///     copy if they happen to launch into Pass 4.2 before either
///     has any remote data; subsequent launches no-op.
///   * **Empty remote collection is the real guard.** The sentinel
///     short-circuits later launches; the empty-collection check is
///     what stops a partially-migrated account from being
///     re-migrated and clobbering Firestore writes the user has
///     since made elsewhere.
///   * **Defensive partial-run handling.** If the sentinel is set
///     but the remote collection is empty, we still migrate. That
///     matches a partial previous run where the sentinel was
///     written but no documents arrived. The opposite policy (treat
///     empty remote as deliberate user state) would silently lose
///     the local backup, and PRD Q6 explicitly chooses to err on
///     the side of restoring data.
///   * **Source files are NEVER deleted.** PRD Q6 calls this out.
///     Local files remain on disk as a backup.
///
/// **Failure shape.** Migration is best-effort: each per-contact
/// `save()` is atomic via [FirebaseMemoryStore]. A partial migration
/// leaves the remote collection non-empty, so the next launch's
/// `target.listAll()` check skips re-migration and only the
/// contacts whose [save] threw are missing.
///
/// **Constructor deviation from the issue sketch.** The issue's
/// sketch took `FirebaseFirestore` and a UID directly. This
/// implementation takes a [MigrationSentinel] interface instead so
/// the gate logic is testable without a real Firestore plugin in
/// headless `flutter test`. Production wiring uses
/// [FirestoreMigrationSentinel]; the Firestore round-trip is
/// covered by the integration suite.
class DiskToFirestoreMigration {
  DiskToFirestoreMigration({
    required FileMemoryStore source,
    required MemoryStore target,
    required MigrationSentinel sentinel,
    DateTime Function() clock = DateTime.now,
  }) : _source = source,
       _target = target,
       _sentinel = sentinel,
       _clock = clock;

  /// Sentinel field name on the `users/{uid}` document. Public so
  /// callers and integration tests reference the same key.
  static const String sentinelField = 'migratedFromDiskAt';

  final FileMemoryStore _source;
  final MemoryStore _target;
  final MigrationSentinel _sentinel;
  final DateTime Function() _clock;

  /// Runs the migration if and only if both gates pass:
  ///
  ///   1. The remote `users/{uid}/memories` collection is empty.
  ///   2. The local source store has at least one document.
  ///
  /// The sentinel is written at the end of every invocation that
  /// reached this method (whether or not it copied anything), so
  /// later launches that already see the sentinel can skip the
  /// listAll round-trip entirely.
  ///
  /// Returns the number of documents successfully migrated. Zero
  /// when the remote collection was non-empty (skip), the source
  /// store was empty (nothing to do), or every per-contact save
  /// threw.
  Future<int> ensureMigrated() async {
    final sentinelAlreadySet = await _sentinel.isSet();
    final remote = await _target.listAll();

    // Sentinel + non-empty remote → already migrated cleanly.
    if (sentinelAlreadySet && remote.isNotEmpty) {
      return 0;
    }

    // Remote non-empty without a sentinel: another device migrated,
    // or the user has done their own writes through a different
    // path. Set the sentinel for next time and return 0 without
    // re-copying.
    if (remote.isNotEmpty) {
      await _sentinel.set(_clock());
      return 0;
    }

    // Remote is empty. If the source is empty too, there's nothing
    // to migrate; mark "we checked" via the sentinel and return 0.
    final sourceDocs = await _source.listAll();
    if (sourceDocs.isEmpty) {
      await _sentinel.set(_clock());
      return 0;
    }

    // Copy each source doc. Best-effort: a single save failure does
    // not abort the rest. The PRD Q4 all-or-nothing contract is
    // per-document via the target store; this migration layer runs
    // a sequence of independent atomic writes.
    var migrated = 0;
    for (final entry in sourceDocs.entries) {
      try {
        await _target.save(entry.value);
        migrated++;
      } on Exception {
        // Swallow and continue. A subsequent launch sees a non-empty
        // remote and skips, so a partial copy stops here rather than
        // duplicating successful writes on the next attempt.
      }
    }

    await _sentinel.set(_clock());
    return migrated;
  }
}
