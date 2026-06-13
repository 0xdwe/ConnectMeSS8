import 'package:connect_me/src/state/notifications/firebase_notification_token_store.dart';
import 'package:connect_me/src/state/notifications/notification_token_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'in-memory token store registers and removes the current token',
    () async {
      final store = InMemoryNotificationTokenStore();

      await store.register(
        token: 'token-a',
        platform: 'android',
        timeZone: 'Asia/Taipei',
      );
      expect(store.registrations.keys, ['token-a']);
      expect(store.registrations['token-a']!.timeZone, 'Asia/Taipei');

      await store.remove('token-a');
      expect(store.registrations, isEmpty);
    },
  );

  test('Firebase token document IDs are stable SHA-256 hashes', () {
    expect(
      FirebaseNotificationTokenStore.documentIdFor('same-token'),
      FirebaseNotificationTokenStore.documentIdFor('same-token'),
    );
    expect(
      FirebaseNotificationTokenStore.documentIdFor('same-token'),
      isNot(FirebaseNotificationTokenStore.documentIdFor('other-token')),
    );
    expect(
      FirebaseNotificationTokenStore.documentIdFor('same-token'),
      hasLength(64),
    );
  });
}
