import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';
import '../firebase_providers.dart';
import 'firebase_notification_token_store.dart';
import 'flutter_notification_gateway.dart';
import 'notification_coordinator.dart';
import 'notification_gateway.dart';
import 'notification_preferences_controller.dart';
import 'notification_token_store.dart';

final notificationGatewayProvider = Provider<NotificationGateway>(
  (ref) => FlutterNotificationGateway(),
);

final notificationTokenStoreProvider = Provider<NotificationTokenStore>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return InMemoryNotificationTokenStore();
  return FirebaseNotificationTokenStore(
    firestore: ref.watch(firestoreProvider),
    uid: user.uid,
  );
});

final notificationPermissionProvider =
    NotifierProvider<
      NotificationPermissionController,
      NotificationPermissionState
    >(NotificationPermissionController.new);

class NotificationPermissionController
    extends Notifier<NotificationPermissionState> {
  @override
  NotificationPermissionState build() {
    ref.watch(notificationGatewayProvider);
    Future<void>.microtask(refresh);
    return NotificationPermissionState.unknown;
  }

  Future<void> refresh() async {
    final gateway = ref.read(notificationGatewayProvider);
    await gateway.initialize();
    state = await gateway.permissionStatus();
  }

  Future<NotificationPermissionState> request() async {
    final gateway = ref.read(notificationGatewayProvider);
    await gateway.initialize();
    final result = await gateway.requestPermission();
    state = result;
    return result;
  }

  Future<void> openSystemSettings() =>
      ref.read(notificationGatewayProvider).openSystemSettings();
}

final notificationCoordinatorProvider = Provider<NotificationCoordinator>(
  (ref) => NotificationCoordinator(
    gateway: ref.watch(notificationGatewayProvider),
    tokenStore: ref.watch(notificationTokenStoreProvider),
    platform: _platformName(),
  ),
);

final notificationSyncProvider = FutureProvider<void>((ref) async {
  if (ref.watch(currentUserProvider) == null) return;
  final preferences = ref.watch(notificationPreferencesProvider);
  final events = ref.watch(
    appControllerProvider.select((state) => state.events),
  );
  final permission = ref.watch(notificationPermissionProvider);
  final result = await ref
      .watch(notificationCoordinatorProvider)
      .sync(preferences: preferences, events: events, permission: permission);
  if (preferences.timeZone != result.timeZone) {
    await ref
        .read(notificationPreferencesProvider.notifier)
        .setTimeZone(result.timeZone);
  }
});

final notificationLifecycleProvider = Provider<void>((ref) {
  final gateway = ref.watch(notificationGatewayProvider);
  final coordinator = ref.watch(notificationCoordinatorProvider);

  final tokenSubscription = gateway.pushTokenRefreshes().listen((token) {
    final preferences = ref.read(notificationPreferencesProvider);
    final permission = ref.read(notificationPermissionProvider);
    unawaited(
      coordinator
          .registerRefreshedToken(
            token: token,
            preferences: preferences,
            permission: permission,
            timeZone: preferences.timeZone,
          )
          .catchError((_) {}),
    );
  });
  final foregroundSubscription = gateway.foregroundNotifications().listen((
    notification,
  ) {
    final preferences = ref.read(notificationPreferencesProvider);
    if (!preferences.enabled) return;
    unawaited(gateway.showForeground(notification).catchError((_) {}));
  });

  ref.onDispose(() {
    tokenSubscription.cancel();
    foregroundSubscription.cancel();
  });
});

String _platformName() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'android',
  };
}
