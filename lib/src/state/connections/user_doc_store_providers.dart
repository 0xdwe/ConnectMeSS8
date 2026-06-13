import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase_providers.dart';
import '../notifications/notification_preferences.dart';
import 'firebase_user_doc_store.dart';
import 'user_doc_store.dart';

/// Active [UserDocStore] for the running app (Pass 4.5 #070).
///
/// Watches `currentUserProvider`. While signed out (or while the
/// auth stream is still loading), returns a
/// [_SignedOutUserDocStore] sentinel whose async surface throws so
/// accidental signed-out reads fail loudly. The signed-in path
/// returns a [FirebaseUserDocStore] bound to the current
/// `user.uid` and the active `firestoreProvider`.
///
/// Auth changes rebuild this provider, which discards the previous
/// user's store identity. The provider's `onDispose` calls
/// `store.dispose()` so the [FirebaseUserDocStore]'s snapshot
/// listener is torn down before the next user's store is
/// constructed.
final userDocStoreProvider = Provider<UserDocStore>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const _SignedOutUserDocStore();
  }
  final firestore = ref.watch(firestoreProvider);
  final store = FirebaseUserDocStore(firestore: firestore, uid: user.uid);
  ref.onDispose(store.dispose);
  return store;
});

/// Sentinel returned by [userDocStoreProvider] while signed out.
///
/// Async writes throw [StateError] so a signed-out save surfaces
/// immediately. The [snapshot] stream is intentionally calm — it
/// emits a single empty snapshot and completes — so widgets that
/// watch user-doc state during a sign-out frame render a defaulted
/// state instead of crashing.
class _SignedOutUserDocStore implements UserDocStore {
  const _SignedOutUserDocStore();

  static const String _msg =
      'User-doc fields are not available while signed out.';

  @override
  Future<void> saveCategories(List<String> categories) =>
      Future.error(StateError(_msg));

  @override
  Future<void> saveEventTypes(List<String> eventTypes) =>
      Future.error(StateError(_msg));

  @override
  Future<void> saveNotificationPreferences(
    NotificationPreferences preferences,
  ) => Future.error(StateError(_msg));

  @override
  Stream<UserDocSnapshot> snapshot() =>
      Stream<UserDocSnapshot>.value(UserDocSnapshot.empty);

  @override
  UserDocSnapshot? snapshotSync() => UserDocSnapshot.empty;

  @override
  Future<void> dispose() async {}
}
