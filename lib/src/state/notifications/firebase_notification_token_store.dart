import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import 'notification_token_store.dart';

class FirebaseNotificationTokenStore implements NotificationTokenStore {
  FirebaseNotificationTokenStore({
    required FirebaseFirestore firestore,
    required String uid,
  }) : _firestore = firestore,
       _uid = uid;

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _tokens =>
      _firestore.collection('users').doc(_uid).collection('notificationTokens');

  static String documentIdFor(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  @override
  Future<void> register({
    required String token,
    required String platform,
    required String timeZone,
  }) async {
    await _tokens.doc(documentIdFor(token)).set(<String, dynamic>{
      'token': token,
      'platform': platform,
      'timeZone': timeZone,
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    });
  }

  @override
  Future<void> remove(String token) =>
      _tokens.doc(documentIdFor(token)).delete();
}
