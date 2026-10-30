import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_screens.dart';
import '../features/dashboard/beranda_screen.dart';
import '../features/dashboard/sensor_detail_screen.dart';
import '../features/dashboard/shell.dart';
import '../features/kontrol/kontrol_screen.dart';
import '../features/pengaturan/pengaturan_screen.dart';
import '../features/peringatan/peringatan_screen.dart';
import '../features/riwayat/riwayat_screen.dart';
import '../features/tanaman/tanaman_screen.dart';
import '../providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authUserProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (loc == '/splash') return null; // splash memutuskan sendiri setelah cek sesi
      final auth = ref.read(authUserProvider);
      if (auth.isLoading) return '/splash';
      if (auth.valueOrNull == null) return loc == '/login' ? null : '/login'; // tanpa sesi tidak ada layar data
      if (loc == '/login') {
        return ref.read(notifPermProvider) == NotifPermission.unknown ? '/izin' : '/beranda';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/izin', builder: (_, __) => const PermissionScreen()),
      ShellRoute(
        builder: (_, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/beranda', builder: (_, __) => const BerandaScreen()),
          GoRoute(path: '/tanaman', builder: (_, __) => const TanamanScreen()),
          GoRoute(path: '/kontrol', builder: (_, __) => const KontrolScreen()),
          GoRoute(path: '/riwayat', builder: (_, __) => const RiwayatScreen()),
        ],
      ),
      GoRoute(path: '/sensor/:key', builder: (_, s) => SensorDetailScreen(sensorKey: s.pathParameters['key'] ?? 'ph')),
      GoRoute(path: '/peringatan', builder: (_, __) => const PeringatanScreen()),
      GoRoute(path: '/pengaturan', builder: (_, __) => const PengaturanScreen()),
    ],
  );
});
