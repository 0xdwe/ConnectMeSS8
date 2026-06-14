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
import 'package:connect_me/src/state/notifications/notification_gateway.dart';
import 'package:connect_me/src/state/notifications/notification_providers.dart';
import 'package:connect_me/src/state/notifications/notification_token_store.dart';
import 'dart:io';
import 'package:connect_me/src/state/user_profile/user_profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

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
List<dynamic> headlessStoreOverrides({
  NotificationGateway? notificationGateway,
  NotificationTokenStore? notificationTokenStore,
  GoogleSignInService? googleSignInService,
}) {
  final connections = InMemoryConnectionStore();
  connections.seedSync(SeederSampleSource.connections());

  final interactions = InMemoryInteractionStore();
  interactions.seedSync(SeederSampleSource.interactions());

  final events = InMemoryEventStore();
  events.seedSync(SeederSampleSource.events());

  final userDoc = InMemoryUserDocStore();
  final batched = InMemoryBatchedWrites(
    connectionStore: connections,
    interactionStore: interactions,
    eventStore: events,
  );
  return <dynamic>[
    // Pass 4.3 #081: aiUpdateProvider now constructs LlmAiUpdate for
    // signed-in users, which reaches firebaseAiProvider. The real
    // factory boots the SDK against FirebaseApp.instance which is
    // not initialized in headless tests; override to null so the
    // adapter is constructed with `firebaseAi: null`. Tests that
    // exercise an AI run override `aiUpdateProvider` directly with
    // a Mock and never reach this slot.
    firebaseAiProvider.overrideWithValue(null),
    googleSignInServiceProvider.overrideWithValue(
      googleSignInService ?? NoOpGoogleSignInService(),
    ),
    notificationGatewayProvider.overrideWithValue(
      notificationGateway ?? InMemoryNotificationGateway(),
    ),
    notificationTokenStoreProvider.overrideWithValue(
      notificationTokenStore ?? InMemoryNotificationTokenStore(),
    ),
    connectionStoreProvider.overrideWithValue(connections),
    interactionStoreProvider.overrideWithValue(interactions),
    eventStoreProvider.overrideWithValue(events),
    userDocStoreProvider.overrideWithValue(userDoc),
    batchedWritesProvider.overrideWithValue(batched),
    userProfileServiceProvider.overrideWith(
      (ref) => NoOpUserProfileService(ref.watch(firebaseAuthProvider)),
    ),
  ];
}

class NoOpUserProfileService implements UserProfileService {
  NoOpUserProfileService(this._auth);
  final FirebaseAuth _auth;

  @override
  AccountProfile? currentProfile() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return AccountProfile.fromAuthValues(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  @override
  Future<void> updateDisplayName(String displayName) async {}

  @override
  Future<void> uploadAvatarAndUpdatePhotoUrl(File imageFile) async {}

  @override
  Future<void> removeAvatar() async {}
}

class NoOpGoogleSignInService implements GoogleSignInService {
  @override
  Future<UserCredential?> signIn() async => null;
}

List<dynamic> signedOutDemoOverrides({
  String uid = 'demo-uid',
  NotificationGateway? notificationGateway,
  NotificationTokenStore? notificationTokenStore,
  GoogleSignInService? googleSignInService,
}) {
  return <dynamic>[
    firebaseAuthProvider.overrideWithValue(
      MockFirebaseAuth(
        mockUser: MockUser(
          uid: uid,
          isAnonymous: false,
          email: 'demo@example.com',
          displayName: 'Demo',
        ),
      ),
    ),
    ...headlessStoreOverrides(
      notificationGateway: notificationGateway,
      notificationTokenStore: notificationTokenStore,
      googleSignInService: googleSignInService,
    ),
  ];
}

List<dynamic> signedInDemoOverrides({
  String uid = 'demo-uid',
  NotificationGateway? notificationGateway,
  NotificationTokenStore? notificationTokenStore,
  GoogleSignInService? googleSignInService,
}) {
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
    ...headlessStoreOverrides(
      notificationGateway: notificationGateway,
      notificationTokenStore: notificationTokenStore,
      googleSignInService: googleSignInService,
    ),
  ];
}
