class NotificationTokenRegistration {
  const NotificationTokenRegistration({
    required this.token,
    required this.platform,
    required this.timeZone,
  });

  final String token;
  final String platform;
  final String timeZone;
}

abstract interface class NotificationTokenStore {
  Future<void> register({
    required String token,
    required String platform,
    required String timeZone,
  });

  Future<void> remove(String token);
}

class InMemoryNotificationTokenStore implements NotificationTokenStore {
  final Map<String, NotificationTokenRegistration> registrations =
      <String, NotificationTokenRegistration>{};

  @override
  Future<void> register({
    required String token,
    required String platform,
    required String timeZone,
  }) async {
    registrations[token] = NotificationTokenRegistration(
      token: token,
      platform: platform,
      timeZone: timeZone,
    );
  }

  @override
  Future<void> remove(String token) async {
    registrations.remove(token);
  }
}
