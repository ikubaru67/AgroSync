import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../providers.dart';

class PeringatanScreen extends ConsumerStatefulWidget {
  const PeringatanScreen({super.key});
  @override
  ConsumerState<PeringatanScreen> createState() => _PeringatanState();
}

class _PeringatanState extends ConsumerState<PeringatanScreen> {
  int _seenAtOpen = 0;
  Severity? _filter;

  @override
  void initState() {
    super.initState();
    _markSeen();
  }

  /// Simpan titik "terakhir dilihat" sebelum diperbarui, agar penanda "Baru" tetap tampil di layar ini.
  Future<void> _markSeen() async {
    final uid = ref.read(authUserProvider).valueOrNull?.uid;
    if (uid == null) return;
    final seen = await ref.read(alertSeenProvider.future);
    if (!mounted) return;
    setState(() => _seenAtOpen = seen);
    await ref.read(alertRepoProvider).markSeen(uid, DateTime.now().millisecondsSinceEpoch);
  }

  String _key(AlertItem a) => switch (a.sensor ?? a.jenis) {
        'ph' => 'ph',
        'ec' => 'ec',
        'levelAir' || 'level' => 'level',
        'suhu' => 'suhu',
        'kelembapan' => 'hum',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final alerts = ref.watch(alertsLiveProvider);
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Pusat Peringatan'), backgroundColor: AppColors.bg, surfaceTintColor: Colors.transparent),
      body: alerts.when(
        loading: () => ListView(padding: const EdgeInsets.all(20), children: const [SkeletonBox(height: 110), SizedBox(height: 12), SkeletonBox(height: 110)]),
        error: (_, __) => ErrorState(onRetry: () => ref.invalidate(alertsLiveProvider)),
        data: (all) {
          final list = all.where((a) => _filter == null || a.tingkat == _filter).toList();
          return ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
            Text('Peringatan tetap tersimpan di sini walau notifikasi di ponsel sudah terhapus.', style: t.bodySmall),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (final (label, value) in <(String, Severity?)>[('Semua', null), ('Bahaya', Severity.bahaya), ('Waspada', Severity.waspada)])
                ChoiceChip(
                  label: Text(label),
                  selected: _filter == value,
                  showCheckmark: false,
                  labelStyle: t.titleSmall!.copyWith(color: _filter == value ? Colors.white : AppColors.ink),
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.line, width: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  onSelected: (_) => setState(() => _filter = value),
                ),
            ]),
            const SizedBox(height: 12),
            if (list.isEmpty) const EmptyState(icon: Icons.notifications_off_rounded, title: 'Tidak ada peringatan', text: 'Kondisi kebun Anda aman.'),
            for (final a in list) ...[
              _AlertTile(a: a, fresh: a.waktu > _seenAtOpen, now: now, onTap: () {
                final k = _key(a);
                k.isEmpty ? context.go('/beranda') : context.push('/sensor/$k');
              }),
              const SizedBox(height: 12),
            ],
          ]);
        },
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.a, required this.fresh, required this.now, required this.onTap});
  final AlertItem a;
  final bool fresh;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final st = styleOf(levelOf(a.tingkat));
    final day = dayLabel(a.waktu, now);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Material(
        color: st.bg,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 10, color: st.dot),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    IconBadge(st.icon, bg: st.dot, fg: st.dotFg, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(severityLabel(a.tingkat).toUpperCase(), style: t.titleSmall!.copyWith(color: st.ink, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                          const Spacer(),
                          if (fresh) const Pill('Baru', bg: AppColors.ink, fg: Colors.white),
                        ]),
                        const SizedBox(height: 2),
                        Text('${a.pesan ?? a.jenis}${a.nilai == null ? '' : ' (${a.nilai})'}', style: t.titleMedium),
                        Text(day == 'Hari ini' ? 'Pukul ${hhmm(a.waktu)}' : '$day, ${hhmm(a.waktu)}', style: t.bodySmall),
                        const SizedBox(height: 4),
                        Text('Ketuk untuk melihat saran', style: t.bodySmall!.copyWith(color: st.ink, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
