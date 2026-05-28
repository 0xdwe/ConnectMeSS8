import 'package:connect_me/src/state/connections/batched_writes.dart';
import 'package:connect_me/src/state/connections/batched_writes_providers.dart';
import 'package:connect_me/src/state/connections/connection_providers.dart';
import 'package:connect_me/src/state/connections/event_providers.dart';
import 'package:connect_me/src/state/connections/in_memory_connection_store.dart';
import 'package:connect_me/src/state/connections/in_memory_event_store.dart';
import 'package:connect_me/src/state/connections/in_memory_interaction_store.dart';
import 'package:connect_me/src/state/connections/in_memory_user_doc_store.dart';
import 'package:connect_me/src/state/connections/interaction_providers.dart';
import 'package:connect_me/src/state/connections/connection_seeder.dart';
import 'package:connect_me/src/state/connections/user_doc_store_providers.dart';
import 'package:connect_me/src/state/firebase_providers.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Standard signed-in [firebaseAuthProvider] override plus Pass 4.5
/// store overrides for headless `flutter test`.
///
/// Pass 4.2 (#058) made `memoryStoreProvider`, `memorySeedingProvider`,
/// and any provider that reaches through them auth-aware. Pass 4.5
/// (#070) extends that to `connectionStoreProvider`,
/// `interactionStoreProvider`, `eventStoreProvider`,
/// `userDocStoreProvider`, and `batchedWritesProvider` — all read by
/// AppController. Tests that don't care about persistence still need
/// every one of those overridden, or the signed-in default branch
/// reaches for `FirebaseFirestore.instance` and crashes (no
/// `Firebase.initializeApp` in headless tests).
///
/// Usage:
/// ```
/// ProviderContainer(overrides: [
///   ...signedInDemoOverrides(),
///   memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
/// ]);
/// ```
///
/// The return type is `dynamic`-cast inferred via `<Object>[...]`
/// because Riverpod 3's `Override` type is not part of the
/// `flutter_riverpod` public surface; spreading the list into
/// `ProviderContainer(overrides: [...])` works either way and
/// avoids an extra import path.
List<dynamic> signedInDemoOverrides({String uid = 'demo-uid'}) {
  final connections = InMemoryConnectionStore();
  for (final c in SeederSampleSource.connections()) {
    connections.save(c);
  }

  final interactions = InMemoryInteractionStore();
  for (final i in SeederSampleSource.interactions()) {
    interactions.save(i);
  }

  final events = InMemoryEventStore();
  for (final e in SeederSampleSource.events()) {
    events.save(e);
  }

  final userDoc = InMemoryUserDocStore();
  final batched = InMemoryBatchedWrites(
    connectionStore: connections,
    interactionStore: interactions,
    eventStore: events,
  );
  return <dynamic>[
    firebaseAuthProvider.overrideWithValue(
      MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(
          uid: uid,
          isAnonymous: false,
          email: 'demo@example.com',
          displayName: 'Demo',
        ),
      ),
    ),
    connectionStoreProvider.overrideWithValue(connections),
    interactionStoreProvider.overrideWithValue(interactions),
    eventStoreProvider.overrideWithValue(events),
    userDocStoreProvider.overrideWithValue(userDoc),
    batchedWritesProvider.overrideWithValue(batched),
  ];
}
