import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../providers.dart';

const _tabs = ['/beranda', '/tanaman', '/kontrol', '/riwayat'];

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t        = Theme.of(context).textTheme;
    final unread   = ref.watch(unreadAlertsProvider);
    final deviceId = ref.watch(deviceIdProvider);
    final dummy    = ref.watch(dummyBackendProvider) != null;
    final offline  = ref.watch(isOfflineProvider);
    final index    = math.max(0, _tabs.indexWhere(location.startsWith));
    final wide     = MediaQuery.sizeOf(context).width >= kTablet;

    final appBar = AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withAlpha(20),
      elevation: 0.5,
      toolbarHeight: 68,
      titleSpacing: 20,
      title: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(80), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: const Icon(Icons.eco_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('AgroSync', style: t.titleLarge),
            Row(children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: offline ? AppColors.warn : AppColors.ok,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${deviceId ?? 'Perangkat'}${dummy ? ' · dummy' : ''}',
                  style: t.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ]),
        ),
      ]),
      actions: [
        // bell with badge
        Stack(
          children: [
            IconButton(
              tooltip: 'Pusat peringatan',
              onPressed: () => context.push('/peringatan'),
              icon: const Icon(Icons.notifications_rounded, size: 26),
            ),
            if (unread > 0)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  width: 18, height: 18,
                  decoration: const BoxDecoration(color: AppColors.critInk, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
        IconButton.filledTonal(
          tooltip: 'Profil dan pengaturan',
          style: IconButton.styleFrom(backgroundColor: AppColors.okBg, foregroundColor: AppColors.primary),
          onPressed: () => context.push('/pengaturan'),
          icon: const Icon(Icons.person_rounded),
        ),
        const SizedBox(width: 12),
      ],
    );

    return Scaffold(
      appBar: appBar,
      body: wide
          ? Row(children: [
              Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: Colors.white,
                  navigationRailTheme: const NavigationRailThemeData(
                    backgroundColor: Colors.white,
                    indicatorColor: AppColors.okBg,
                    selectedIconTheme: const IconThemeData(color: AppColors.primary, size: 26),
                    unselectedIconTheme: const IconThemeData(color: AppColors.muted, size: 24),
                    selectedLabelTextStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14),
                    unselectedLabelTextStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
                    useIndicator: true,
                  ),
                ),
                child: NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (i) => context.go(_tabs[i]),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: Text('Beranda')),
                    NavigationRailDestination(icon: Icon(Icons.eco_outlined), selectedIcon: Icon(Icons.eco_rounded), label: Text('Tanaman')),
                    NavigationRailDestination(icon: Icon(Icons.touch_app_outlined), selectedIcon: Icon(Icons.touch_app_rounded), label: Text('Kontrol')),
                    NavigationRailDestination(icon: Icon(Icons.history_rounded), selectedIcon: Icon(Icons.history_rounded), label: Text('Riwayat')),
                  ],
                ),
              ),
              Container(width: 1, color: AppColors.line),
              Expanded(child: child),
            ])
          : child,
      bottomNavigationBar: wide ? null : _BottomBar(index: index, onSelected: (i) => context.go(_tabs[i])),
    );
  }
}

/// Navigation bar bawah, dipakai hanya ketika layar sempit (ponsel portrait).
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onSelected});
  final int index;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.line.withAlpha(180), width: 1)),
      boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 12, offset: const Offset(0, -2))],
    ),
    child: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: onSelected,
      height: 76,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Beranda',
        ),
        NavigationDestination(
          icon: Icon(Icons.eco_outlined),
          selectedIcon: Icon(Icons.eco_rounded),
          label: 'Tanaman',
        ),
        NavigationDestination(
          icon: Icon(Icons.touch_app_outlined),
          selectedIcon: Icon(Icons.touch_app_rounded),
          label: 'Kontrol',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_rounded),
          selectedIcon: Icon(Icons.history_rounded),
          label: 'Riwayat',
        ),
      ],
    ),
  );
}
