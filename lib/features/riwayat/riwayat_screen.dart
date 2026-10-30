import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/pump_info.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../providers.dart';

const _pageSize = 20;

class RiwayatScreen extends ConsumerStatefulWidget {
  const RiwayatScreen({super.key});
  @override
  ConsumerState<RiwayatScreen> createState() => _RiwayatState();
}

class _RiwayatState extends ConsumerState<RiwayatScreen> {
  final List<WateringLogEntry> _older = [];
  bool _loadingMore = false, _exhausted = false;

  Future<void> _more(List<WateringLogEntry> all) async {
    final id = ref.read(deviceIdProvider);
    if (id == null || all.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final r = await ref.read(logRepoProvider).fetchBefore(id, all.last.waktu, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _older.addAll(r);
        if (r.length < _pageSize) _exhausted = true;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Riwayat gagal dimuat. Coba lagi.')));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _detail(WateringLogEntry e) {
    final now = DateTime.now();
    final rows = <(String, String)>[
      ('Pompa', pumpInfo(e.pompa).name),
      ('Mulai', '${hhmm(e.waktu)}, ${dayLabel(e.waktu, now)}'),
      if (e.durasiDetik != null) ('Selesai', hhmm(e.waktu + e.durasiDetik! * 1000)),
      if (e.durasiDetik != null) ('Lama menyala', durLabel(e.durasiDetik!)),
      if (e.dosisMl != null) ('Dosis', '${e.dosisMl!.round()} ml'),
      ('Dipicu oleh', pemicuLabel(e.pemicu)),
      ('pH saat itu', fmtNum(e.phSaat)),
      ('EC saat itu', e.ecSaat == null ? '-' : '${fmtNum(e.ecSaat)} mS/cm'),
      if (e.perintahId != null) ('Kode perintah', e.perintahId!),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Detail Penyiraman', style: t.titleLarge),
            const SizedBox(height: 12),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(r.$1, style: t.bodyLarge!.copyWith(color: AppColors.muted)),
                  Flexible(child: Text(r.$2, style: t.bodyLarge!.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.end)),
                ]),
              ),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final latest = ref.watch(latestLogProvider);
    return latest.when(
      loading: () => ListView(padding: const EdgeInsets.all(20), children: const [SkeletonBox(height: 72), SizedBox(height: 8), SkeletonBox(height: 72), SizedBox(height: 8), SkeletonBox(height: 72)]),
      error: (_, __) => ErrorState(onRetry: () => ref.invalidate(latestLogProvider)),
      data: (first) {
        final ids = first.map((e) => e.id).toSet();
        final all = [...first, ..._older.where((e) => !ids.contains(e.id))];
        if (all.isEmpty) {
          return ListView(children: [
            const PageTitle('Riwayat', sub: 'Semua pompa yang pernah menyala'),
            const EmptyState(icon: Icons.history_rounded, title: 'Belum ada riwayat penyiraman', text: 'Riwayat akan muncul di sini setelah pompa pertama kali menyala.'),
          ]);
        }
        final now = DateTime.now();
        final children = <Widget>[const PageTitle('Riwayat', sub: 'Semua pompa yang pernah menyala')];
        String? lastDay;
        for (final e in all) {
          final d = dayLabel(e.waktu, now);
          if (d != lastDay) {
            lastDay = d;
            children.add(Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 6), child: Text(d, style: t.titleMedium!.copyWith(color: AppColors.muted))));
          }
          final info = pumpInfo(e.pompa);
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: AppCard(
              onTap: () => _detail(e),
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                IconBadge(info.icon, size: 44, round: false),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${info.name} menyala', style: t.titleMedium),
                    Text('${hhmm(e.waktu)}${e.durasiDetik == null ? '' : ' · ${durLabel(e.durasiDetik!)}'}${e.dosisMl == null ? '' : ' · ${e.dosisMl!.round()} ml'}', style: t.bodySmall),
                  ]),
                ),
                const SizedBox(width: 8),
                Pill(pemicuLabel(e.pemicu),
                    bg: e.pemicu == Pemicu.manual ? AppColors.infoBg : e.pemicu == Pemicu.jadwal ? AppColors.warnBg : AppColors.okBg,
                    fg: e.pemicu == Pemicu.manual ? AppColors.infoInk : e.pemicu == Pemicu.jadwal ? AppColors.warnInk : AppColors.okInk,
                    icon: pemicuIcon(e.pemicu)),
              ]),
            ),
          ));
        }
        final canMore = !_exhausted && all.length >= _pageSize;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(children: [
            Text('Menampilkan ${all.length} catatan', style: t.bodySmall),
            if (canMore) ...[
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _loadingMore ? null : () => _more(all), child: Text(_loadingMore ? 'Memuat...' : 'Muat $_pageSize catatan berikutnya'))),
            ],
          ]),
        ));
        return ListView(children: children);
      },
    );
  }
}
