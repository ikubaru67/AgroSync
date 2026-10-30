import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/pump_info.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../providers.dart';

/// Pilihan durasi preset (detik). Durasi bebas sengaja tidak ada (dokumen 6.4).
const durations = [10, 30, 60, 300];

class KontrolScreen extends ConsumerStatefulWidget {
  const KontrolScreen({super.key});
  @override
  ConsumerState<KontrolScreen> createState() => _KontrolState();
}

class _KontrolState extends ConsumerState<KontrolScreen> {
  String? _sel;
  int _dur = 60;

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _changeMode(OperatingMode to) async {
    final manual = to == OperatingMode.manual;
    final ok = await confirmDialog(
      context,
      title: manual ? 'Pindah ke mode Manual?' : 'Kembali ke mode Otomatis?',
      body: manual
          ? 'Sistem berhenti mengatur pompa sendiri. Anda harus memantau pH, nutrisi, dan air secara langsung.'
          : 'Sistem akan kembali mengatur pompa sesuai kondisi kebun.',
      confirmLabel: manual ? 'Ya, pindah ke Manual' : 'Ya, otomatiskan',
      danger: manual,
    );
    if (!ok) return;
    try {
      await ref.read(commandProvider.notifier).sendMode(to);
    } catch (_) {
      _snack('Perintah gagal dikirim. Periksa koneksi internet.');
    }
  }

  Future<void> _start(String id) async {
    final info = pumpInfo(id);
    final ok = await confirmDialog(
      context,
      title: 'Nyalakan ${info.name}?',
      body: 'Pompa akan menyala selama ${durLabel(_dur)}, lalu berhenti sendiri. Anda bisa menghentikannya kapan saja.',
      confirmLabel: 'Ya, nyalakan',
    );
    if (!ok) return;
    setState(() => _sel = null);
    try {
      await ref.read(commandProvider.notifier).sendPump(id, on: true, durasiDetik: _dur);
    } catch (_) {
      _snack('Perintah gagal dikirim. Periksa koneksi internet.');
    }
  }

  Future<void> _stop(String id) async {
    try {
      await ref.read(commandProvider.notifier).sendPump(id, on: false);
    } catch (_) {
      _snack('Perintah gagal dikirim. Periksa koneksi internet.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final offline = ref.watch(isOfflineProvider);
    final cmd = ref.watch(commandProvider);
    final pumps = ref.watch(pumpsProvider);
    final cfg = ref.watch(settingsProvider);
    final updatedAt = ref.watch(sensorProvider).valueOrNull?.updatedAt;

    final mode = cfg.valueOrNull?.mode ?? OperatingMode.unknown;
    final manual = mode == OperatingMode.manual;
    final modePending = cmd != null && cmd.tipe == 'mode' && cmd.isActive;
    final pumpBusy = cmd != null && cmd.tipe == 'pompa' && cmd.isActive;
    final locked = offline;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Kontrol', style: t.headlineMedium)),
        if (offline) ...[
          OfflineBanner(updatedAt: updatedAt, now: now, compact: true),
          const SizedBox(height: 4),
          Text('Kontrol manual dimatikan sampai data kembali terbaru.', style: t.bodySmall),
          const SizedBox(height: 12),
        ],
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mode', style: t.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<OperatingMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: OperatingMode.otomatis, icon: Icon(Icons.autorenew_rounded), label: Text('Otomatis')),
                  ButtonSegment(value: OperatingMode.manual, icon: Icon(Icons.touch_app_rounded), label: Text('Manual')),
                ],
                selected: {mode == OperatingMode.unknown ? OperatingMode.otomatis : mode},
                onSelectionChanged: (locked || modePending || !cfg.hasValue)
                    ? null
                    : (s) {
                        if (s.first != mode) _changeMode(s.first);
                      },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              modePending
                  ? 'Menunggu konfirmasi dari sistem...'
                  : manual
                      ? 'Anda yang mengatur pompa. Pilih pompa di bawah.'
                      : 'Sistem mengatur semua pompa sendiri. Pindah ke Manual bila perlu bertindak sendiri.',
              style: t.bodyLarge!.copyWith(color: AppColors.muted),
            ),
            if (modePending) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator(minHeight: 6, borderRadius: BorderRadius.all(Radius.circular(3)))),
          ]),
        ),
        const SizedBox(height: 12),
        if (!manual && !locked)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const Icon(Icons.info_rounded, color: AppColors.infoInk),
              const SizedBox(width: 8),
              Expanded(child: Text('Tombol pompa dimatikan selama mode Otomatis. Pindah ke Manual untuk menyalakannya sendiri.', style: t.bodyLarge!.copyWith(color: AppColors.infoInk))),
            ]),
          ),
        if (cmd != null) ...[const SizedBox(height: 12), _CommandCard(cmd: cmd, onRetry: () {
          if (cmd.tipe == 'mode') {
            ref.read(commandProvider.notifier).sendMode(cmd.nilai == 'manual' ? OperatingMode.manual : OperatingMode.otomatis);
          } else {
            ref.read(commandProvider.notifier).sendPump(cmd.target, on: cmd.nilai == 'nyala', durasiDetik: cmd.durasiDetik ?? 0);
          }
        })],
        const SizedBox(height: 12),
        pumps.when(
          loading: () => const SkeletonBox(height: 200),
          error: (_, __) => ErrorState(onRetry: () => ref.invalidate(pumpsProvider)),
          data: (list) => list.isEmpty
              ? const EmptyState(icon: Icons.power_off_rounded, title: 'Belum ada data pompa', text: 'Daftar pompa akan muncul dari perangkat Anda.')
              : Column(children: [
                  for (final p in list) ...[
                    _PumpCard(
                      p: p, now: now, selected: _sel == p.id && manual && !p.on, dur: _dur,
                      canTap: manual && !locked && !p.on && !pumpBusy, canStop: !locked,
                      onTap: () => setState(() => _sel = _sel == p.id ? null : p.id),
                      onDur: (d) => setState(() => _dur = d),
                      onStart: () => _start(p.id),
                      onStop: () => _stop(p.id),
                      dimmed: (!manual || locked) && !p.on,
                    ),
                    const SizedBox(height: 12),
                  ],
                ]),
        ),
      ],
    );
  }
}

class _PumpCard extends StatelessWidget {
  const _PumpCard({required this.p, required this.now, required this.selected, required this.dur, required this.canTap, required this.canStop, required this.onTap, required this.onDur, required this.onStart, required this.onStop, required this.dimmed});
  final PumpState p;
  final DateTime now;
  final bool selected, canTap, canStop, dimmed;
  final int dur;
  final VoidCallback onTap, onStart, onStop;
  final ValueChanged<int> onDur;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final info = pumpInfo(p.id);
    final left = p.endsAt == null ? 0 : ((p.endsAt! - now.millisecondsSinceEpoch) / 1000).ceil().clamp(0, 86400).toInt();
    return Opacity(
      opacity: dimmed ? 0.7 : 1,
      child: AppCard(
        padding: EdgeInsets.zero,
        borderColor: selected ? AppColors.primary : AppColors.line,
        borderWidth: selected ? 2 : 1,
        child: Column(children: [
          InkWell(
            onTap: canTap ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                IconBadge(info.icon, bg: p.on ? AppColors.primary : AppColors.line, fg: p.on ? Colors.white : AppColors.muted, size: 48, round: false),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(info.name, style: t.titleMedium),
                    Text(info.desc, style: t.bodySmall),
                    Text(p.on ? 'Menyala · ${pemicuLabel(p.pemicu)}' : (p.lastOn == null ? 'Belum pernah menyala' : 'Terakhir nyala ${ago(p.lastOn!, now)}'), style: t.bodySmall),
                  ]),
                ),
                const SizedBox(width: 8),
                Pill(p.on ? 'Nyala' : 'Mati', bg: p.on ? AppColors.okBg : AppColors.line, fg: p.on ? AppColors.okInk : AppColors.muted, icon: p.on ? Icons.play_arrow_rounded : Icons.stop_rounded),
              ]),
            ),
          ),
          if (p.on)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                if (p.endsAt != null) Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text.rich(TextSpan(text: 'Berhenti sendiri dalam ', style: t.bodyLarge, children: [TextSpan(text: countdown(left), style: AppText.metric(size: 24))])),
                ),
                SizedBox(
                  width: double.infinity, height: 56,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.critInk),
                    onPressed: canStop ? onStop : null,
                    icon: const Icon(Icons.stop_rounded),
                    label: Text(canStop ? 'Hentikan sekarang' : 'Perangkat offline'),
                  ),
                ),
              ]),
            ),
          if (selected)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Berapa lama menyala?', style: t.titleMedium),
                const SizedBox(height: 8),
                Row(children: [
                  for (final d in durations) Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Semantics(
                        selected: d == dur, button: true, label: durLabel(d),
                        child: Material(
                          color: d == dur ? AppColors.okBg : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: d == dur ? AppColors.primary : AppColors.line, width: 2)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => onDur(d),
                            child: SizedBox(
                              height: 60,
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text(d < 60 ? '$d' : '${d ~/ 60}', style: t.titleMedium!.copyWith(color: d == dur ? AppColors.okInk : AppColors.ink)),
                                Text(d < 60 ? 'detik' : 'menit', style: t.labelSmall),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, height: 56, child: FilledButton.icon(onPressed: onStart, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Nyalakan'))),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _CommandCard extends ConsumerWidget {
  const _CommandCard({required this.cmd, required this.onRetry});
  final Command cmd;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final title = cmd.tipe == 'mode'
        ? 'Perintah: pindah ke mode ${cmd.nilai == 'manual' ? 'Manual' : 'Otomatis'}'
        : 'Perintah: ${pumpInfo(cmd.target).name}, ${cmd.nilai == 'mati' ? 'hentikan' : durLabel(cmd.durasiDetik ?? 0)}';
    final failed = cmd.status == CommandStatus.ditolak || cmd.status == CommandStatus.kedaluwarsa;
    return Semantics(
      liveRegion: true,
      child: AppCard(
        color: cmd.status == CommandStatus.ditolak ? AppColors.critBg : cmd.status == CommandStatus.kedaluwarsa ? AppColors.warnBg : Colors.white,
        borderColor: cmd.status == CommandStatus.ditolak ? AppColors.crit : cmd.status == CommandStatus.kedaluwarsa ? AppColors.warn : AppColors.line,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: t.titleMedium)),
            IconButton(tooltip: 'Tutup status', onPressed: () => ref.read(commandProvider.notifier).dismiss(), icon: const Icon(Icons.close_rounded)),
          ]),
          if (failed) ...[
            StatusChip(level: cmd.status == CommandStatus.ditolak ? Level.crit : Level.warn, text: cmd.status == CommandStatus.ditolak ? 'Ditolak' : 'Kedaluwarsa'),
            const SizedBox(height: 8),
            Text(
              cmd.status == CommandStatus.ditolak ? (cmd.alasan ?? 'Server menolak perintah ini.') : 'Perangkat tidak merespons. Perintah tidak dijalankan.',
              style: t.bodyLarge,
            ),
            if (cmd.status == CommandStatus.kedaluwarsa) ...[
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 56, child: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Ulangi'))),
            ],
          ] else
            _Stepper(status: cmd.status),
        ]),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.status});
  final CommandStatus status;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const steps = [CommandStatus.menunggu, CommandStatus.diterima, CommandStatus.selesai];
    const labels = ['Menunggu', 'Diterima', 'Selesai'];
    final idx = steps.indexOf(status).clamp(0, 2).toInt();
    return Row(children: [
      for (var i = 0; i < 3; i++) ...[
        Column(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: i <= idx ? AppColors.primary : AppColors.line, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: (i < idx || status == CommandStatus.selesai)
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : Text('${i + 1}', style: t.titleSmall!.copyWith(color: i <= idx ? Colors.white : AppColors.muted)),
          ),
          const SizedBox(height: 4),
          Text(labels[i], style: t.bodySmall!.copyWith(fontWeight: i == idx ? FontWeight.w700 : FontWeight.w400)),
        ]),
        if (i < 2) Expanded(child: Container(height: 4, margin: const EdgeInsets.only(bottom: 22, left: 4, right: 4), decoration: BoxDecoration(color: i < idx ? AppColors.primary : AppColors.line, borderRadius: BorderRadius.circular(2)))),
      ],
    ]);
  }
}
