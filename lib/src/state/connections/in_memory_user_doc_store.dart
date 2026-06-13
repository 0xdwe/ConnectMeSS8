import 'dart:async';

import '../notifications/notification_preferences.dart';
import 'user_doc_store.dart';

/// In-process [UserDocStore] backed by plain fields. Used in tests
/// and as the override target for headless widget tests; the
/// Firestore-backed adapter is in [FirebaseUserDocStore].
///
/// Mutations broadcast a fresh [UserDocSnapshot] on the [snapshot]
/// stream so widgets and providers can subscribe to the same shape
/// they will see from Firestore. The stream is broadcast — multiple
/// listeners are supported, and the current snapshot is replayed on
/// first subscribe so callers do not need to combine an initial
/// read with the stream.
class InMemoryUserDocStore implements UserDocStore {
  InMemoryUserDocStore({
    List<String>? categories,
    List<String>? eventTypes,
    NotificationPreferences notificationPreferences =
        const NotificationPreferences.defaults(),
  }) {
    _categories = List<String>.unmodifiable(
      categories ?? UserDocDefaults.categories(),
    );
    _eventTypes = List<String>.unmodifiable(
      eventTypes ?? UserDocDefaults.eventTypes(),
    );
    _notificationPreferences = notificationPreferences;
    _publish();
  }

  late List<String> _categories;
  late List<String> _eventTypes;
  late NotificationPreferences _notificationPreferences;
  final StreamController<UserDocSnapshot> _controller =
      StreamController<UserDocSnapshot>.broadcast();
  UserDocSnapshot? _mirror;

  @override
  Future<void> saveCategories(List<String> categories) async {
    _categories = List<String>.unmodifiable(categories);
    _publish();
  }

  @override
  Future<void> saveEventTypes(List<String> eventTypes) async {
    _eventTypes = List<String>.unmodifiable(eventTypes);
    _publish();
  }

  @override
  Future<void> saveNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    _notificationPreferences = preferences;
    _publish();
  }

  @override
  Stream<UserDocSnapshot> snapshot() {
    late StreamController<UserDocSnapshot> controller;
    StreamSubscription<UserDocSnapshot>? sub;
    controller = StreamController<UserDocSnapshot>(
      onListen: () {
        final current = _mirror;
        if (current != null) controller.add(current);
        sub = _controller.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () async {
        await sub?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  @override
  UserDocSnapshot? snapshotSync() => _mirror;

  void _publish() {
    final snap = UserDocSnapshot(
      categories: _categories,
      eventTypes: _eventTypes,
      notificationPreferences: _notificationPreferences,
    );
    _mirror = snap;
    if (!_controller.isClosed) _controller.add(snap);
  }

  @override
  Future<void> dispose() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
