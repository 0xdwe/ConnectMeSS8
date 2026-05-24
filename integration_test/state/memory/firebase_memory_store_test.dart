/// Adapter tests for `FirebaseMemoryStore` (Pass 4.2, #057).
///
/// Lives under `integration_test/` because the adapter calls into
/// `cloud_firestore` and `firebase_auth`, both of which require a
/// real Flutter engine to load their plugin channels. Run via:
///
///     firebase emulators:exec --only firestore,auth \
///       --project connect-me-rules-test \
///       "flutter test integration_test -d macos"
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:connect_me/src/state/firebase_providers.dart';
import 'package:connect_me/src/state/memory/firebase_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';

import '../../firebase_test_setup.dart';

/// Convenience: build a [MemoryDocument] with a known shape.
MemoryDocument _doc({
  required String contactId,
  String displayName = 'Sample',
  String summary = 'A short summary.',
  String history = '',
  List<String> topics = const ['coffee', 'travel'],
}) {
  return MemoryDocument(
    contactId: contactId,
    displayName: displayName,
    lastUpdated: DateTime.utc(2026, 5, 24, 12, 0, 0),
    version: 1,
    summary: summary,
    history: history,
    preferences: '',
    topics: topics,
    upcoming: const [],
  );
}

/// Build a `## History` body with [n] bullets, each padded to make the
/// rendered doc large. Used to drive the cap/trim tests.
String _historyWithBullets(int n, {int paddingPerBullet = 2048}) {
  final pad = 'x' * paddingPerBullet;
  final bullets = List.generate(n, (i) => '- bullet-$i $pad');
  return bullets.join('\n');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore firestore;

  setUpAll(() async {
    await setUpEmulators();
    firestore = FirebaseFirestore.instance;
  });

  setUp(() async {
    await tearDownEmulators();
    final cred = await FirebaseAuth.instance.signInAnonymously();
    expect(cred.user, isNotNull, reason: 'anonymous sign-in must succeed');
  });

  String currentUid() {
    final user = FirebaseAuth.instance.currentUser;
    expect(user, isNotNull);
    return user!.uid;
  }

  test('load on missing contact returns null', () async {
    final store = FirebaseMemoryStore(firestore: firestore, uid: currentUid());
    expect(await store.load('does-not-exist'), isNull);
  });

  test('round-trip: save then load returns the same document', () async {
    final store = FirebaseMemoryStore(firestore: firestore, uid: currentUid());
    final input = _doc(
      contactId: 'sarah-c',
      displayName: 'Sarah Chen',
      summary: 'Worked on the migration project together.',
      history: '- coffee on tuesday',
      topics: const ['coffee', 'job-hunt', 'family'],
    );

    await store.save(input);
    final loaded = await store.load('sarah-c');

    expect(loaded, isNotNull);
    expect(loaded!.contactId, input.contactId);
    expect(loaded.displayName, input.displayName);
    expect(loaded.summary, input.summary);
    expect(loaded.history, input.history);
    expect(loaded.topics, input.topics);
    // Total round-trip via render() — the canonical equality boundary
    // for MemoryDocument across persistence layers.
    expect(loaded.render(), input.render());
  });

  test('listAll returns every saved doc keyed by contactId; empty when none',
      () async {
    final store = FirebaseMemoryStore(firestore: firestore, uid: currentUid());
    expect(await store.listAll(), isEmpty);

    await store.save(_doc(contactId: 'a', displayName: 'A'));
    await store.save(_doc(contactId: 'b', displayName: 'B'));

    final all = await store.listAll();
    expect(all.keys, unorderedEquals({'a', 'b'}));
    expect(all['a']!.displayName, 'A');
    expect(all['b']!.displayName, 'B');
  });

  test('delete removes the doc; subsequent load returns null', () async {
    final store = FirebaseMemoryStore(firestore: firestore, uid: currentUid());
    await store.save(_doc(contactId: 'mike'));
    expect(await store.load('mike'), isNotNull);

    await store.delete('mike');

    expect(await store.load('mike'), isNull);
    expect(await store.listAll(), isEmpty);
  });

  test('delete on missing doc is a no-op (no exception)', () async {
    final store = FirebaseMemoryStore(firestore: firestore, uid: currentUid());
    // Must not throw.
    await store.delete('never-existed');
    expect(await store.listAll(), isEmpty);
  });

  test('save writes exactly {markdown, updatedAt, schemaVersion: 1}',
      () async {
    final uid = currentUid();
    final store = FirebaseMemoryStore(firestore: firestore, uid: uid);
    await store.save(_doc(contactId: 'c1'));

    final raw = await firestore
        .collection('users')
        .doc(uid)
        .collection('memories')
        .doc('c1')
        .get();

    expect(raw.exists, isTrue);
    final data = raw.data()!;
    expect(
      data.keys,
      unorderedEquals({'markdown', 'updatedAt', 'schemaVersion'}),
    );
    expect(data['schemaVersion'], 1);
    expect(data['markdown'], isA<String>());
    // serverTimestamp materializes as a Timestamp once Firestore
    // commits — the emulator stamps it synchronously inside set().
    expect(data['updatedAt'], isA<Timestamp>());
  });

  test('save trims oversized history bullets and succeeds', () async {
    final store = FirebaseMemoryStore(firestore: firestore, uid: currentUid());
    // Render size with 40 padded bullets is well over 64KB; trim
    // drops the oldest until it fits.
    final oversized = _doc(
      contactId: 'big-history',
      history: _historyWithBullets(40),
    );

    final originalRendered = oversized.render();
    expect(originalRendered.length, greaterThan(64 * 1024));

    await store.save(oversized);

    final loaded = await store.load('big-history');
    expect(loaded, isNotNull);
    final loadedRendered = loaded!.render();
    // Trimmed copy must fit under the 64KB cap and be strictly
    // shorter than the input.
    expect(loadedRendered.length, lessThanOrEqualTo(64 * 1024));
    expect(loadedRendered.length, lessThan(originalRendered.length));
    // Some bullets survived (we only drop the oldest until fit), so
    // at least one bullet from the tail is still present.
    expect(loaded.history, contains('bullet-39'));
  });

  test('save throws MemoryCapExceededException when no history to trim',
      () async {
    final store = FirebaseMemoryStore(firestore: firestore, uid: currentUid());
    // Pathologically large summary, zero history bullets to drop.
    final pathological = _doc(
      contactId: 'huge-summary',
      summary: 'x' * (70 * 1024),
      history: '',
      topics: const [],
    );

    await expectLater(
      store.save(pathological),
      throwsA(isA<MemoryCapExceededException>()),
    );
  });

  test('two stores for two UIDs are isolated', () async {
    // Save under user A.
    final uidA = currentUid();
    final storeA = FirebaseMemoryStore(firestore: firestore, uid: uidA);
    await storeA.save(_doc(contactId: 'only-a', displayName: 'Only A'));
    expect((await storeA.listAll()).keys, contains('only-a'));

    // Sign out, sign in as a different anonymous user, build store B
    // bound to the new UID.
    await FirebaseAuth.instance.signOut();
    final credB = await FirebaseAuth.instance.signInAnonymously();
    final uidB = credB.user!.uid;
    expect(uidB, isNot(uidA));

    final storeB = FirebaseMemoryStore(firestore: firestore, uid: uidB);
    expect(await storeB.listAll(), isEmpty);
    expect(await storeB.load('only-a'), isNull);
  });

  test("user B cannot read user A's memory (rules-enforced isolation)",
      () async {
    // Save under user A.
    final uidA = currentUid();
    final storeA = FirebaseMemoryStore(firestore: firestore, uid: uidA);
    await storeA.save(_doc(contactId: 'private', displayName: 'A private'));

    // Switch to user B.
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();

    // Build a store bound to *user A's* UID but operated by user B.
    // The rules require `request.auth.uid == uid` on the path, so
    // user B's load attempt is denied. The Firestore SDK surfaces
    // permission-denied as a FirebaseException.
    final spoofStore = FirebaseMemoryStore(firestore: firestore, uid: uidA);
    await expectLater(
      spoofStore.load('private'),
      throwsA(isA<FirebaseException>().having(
        (e) => e.code,
        'code',
        'permission-denied',
      )),
    );
  });

  test(
      'memoryStoreProvider rebuilds for a new user and the new store '
      'sees an empty collection (Pass 4.2 #058)',
      () async {
    // Sign in as user A through the real (emulator) FirebaseAuth and
    // build a ProviderContainer. memoryStoreProvider should hand out
    // a UID-bound FirebaseMemoryStore for user A; saving a doc and
    // re-listing through the provider should observe it.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final userAUid = currentUid();
    final storeA = container.read(memoryStoreProvider);
    expect(storeA, isA<FirebaseMemoryStore>(),
        reason: 'signed-in memoryStoreProvider must return the '
            'Firestore-backed adapter.');

    await storeA.save(_doc(contactId: 'a-only', displayName: 'A only'));
    expect((await storeA.listAll()).keys, contains('a-only'));

    // Switch to user B by signing out + back in anonymously. This
    // emits on `authStateChanges`, which fires the listener inside
    // `currentUserProvider` and invalidates it — the next read of
    // memoryStoreProvider rebuilds with the new UID.
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();
    final userBUid = currentUid();
    expect(userBUid, isNot(equals(userAUid)),
        reason: 'anonymous sign-in must produce a fresh UID.');

    // Pump a microtask so the StreamSubscription callback runs and
    // the provider invalidation is observed.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final storeB = container.read(memoryStoreProvider);
    expect(storeB, isA<FirebaseMemoryStore>());
    expect(identical(storeA, storeB), isFalse,
        reason: 'memoryStoreProvider must rebuild when the auth user '
            'changes; user B must not share user A\'s store instance.');

    expect(await storeB.listAll(), isEmpty,
        reason: 'user B starts with an empty memories collection; '
            'user A\'s data must not leak into user B\'s session.');
  });
}
