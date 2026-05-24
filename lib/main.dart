import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'src/app/connect_me_app.dart';
import 'src/state/firebase_providers.dart';

void main() async {
  // Firebase init before the first frame so any provider that touches
  // FirebaseAuth on read does not race the SDK. See Pass 4.1 (#052).
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Configure Firestore offline persistence before any provider can
  // resolve `firestoreProvider`. The SDK throws if `settings` is
  // assigned after the first read/write, so this call sits between
  // `initializeApp` and `runApp`. See Pass 4.2 (#060 / PRD Q4).
  enableFirestoreOfflinePersistence(FirebaseFirestore.instance);
  runApp(const ProviderScope(child: ConnectMeApp()));
}
