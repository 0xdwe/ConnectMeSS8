import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'src/app/connect_me_app.dart';

void main() async {
  // Firebase init before the first frame so any provider that touches
  // FirebaseAuth on read does not race the SDK. See Pass 4.1 (#052).
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: ConnectMeApp()));
}
