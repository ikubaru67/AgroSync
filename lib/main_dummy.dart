// Titik masuk flavor DUMMY: tanpa Firebase, seluruh layar MVP berjalan dengan data palsu.
// Jalankan: flutter run -t lib/main_dummy.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/dummy/dummy_backend.dart';
import 'providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final b = DummyBackend();
  runApp(ProviderScope(
    overrides: [
      dummyBackendProvider.overrideWithValue(b),
      authRepoProvider.overrideWithValue(b),
      notifRepoProvider.overrideWithValue(b),
      deviceRepoProvider.overrideWithValue(b),
      commandRepoProvider.overrideWithValue(b),
      logRepoProvider.overrideWithValue(b),
      alertRepoProvider.overrideWithValue(b),
      plantRepoProvider.overrideWithValue(b),
    ],
    child: const AgroSyncApp(),
  ));
}
