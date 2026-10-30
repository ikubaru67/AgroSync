// Titik masuk flavor FIREBASE. Butuh android/app/google-services.json dari
// project Firebase uji (lihat README). Jalankan: flutter run -t lib/main_firebase.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/firebase/firebase_repositories.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(ProviderScope(
    overrides: [
      authRepoProvider.overrideWithValue(FirebaseAuthRepository()),
      notifRepoProvider.overrideWithValue(FirebaseNotificationRepository()),
      deviceRepoProvider.overrideWithValue(FirebaseDeviceRepository()),
      commandRepoProvider.overrideWithValue(FirebaseCommandRepository()),
      logRepoProvider.overrideWithValue(FirebaseLogRepository()),
      alertRepoProvider.overrideWithValue(FirebaseAlertRepository()),
      plantRepoProvider.overrideWithValue(FirebasePlantRepository()),
    ],
    child: const AgroSyncApp(),
  ));
}
