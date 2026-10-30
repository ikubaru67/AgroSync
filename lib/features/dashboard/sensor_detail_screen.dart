import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../providers.dart';

class _Meta {
  const _Meta(this.title, this.what, this.unit, {this.lo, this.hi});
  final String title, what, unit;
  final double? lo, hi; // rentang tampilan bilah
}

const _meta = {
  'ph': _Meta('pH Air', 'pH menunjukkan seberapa asam atau basa air. Selada paling nyaman di pH sekitar 5,5 sampai 6,5.', '', lo: 4, hi: 9),
  'ec': _Meta('Nutrisi (EC)', 'EC mengukur kepekatan pupuk di dalam air. Terlalu rendah berarti tanaman lapar, terlalu tinggi bisa membakar akar. TDS adalah angka lain untuk hal yang sama.', 'mS/cm', lo: 0, hi: 3),
  'level': _Meta('Level Air', 'Sensor pelampung hanya tahu dua keadaan: air cukup atau air rendah.', ''),
  'suhu': _Meta('Suhu', 'Suhu udara di sekitar rak. Suhu terlalu tinggi membuat tanaman layu dan air cepat panas.', '°C'),
  'hum': _Meta('Kelembapan', 'Kelembapan udara di sekitar rak. Terlalu lembap memicu jamur, terlalu kering membuat daun kering.', '%'),
};

class SensorDetailScreen extends ConsumerWidget {
  const SensorDetailScreen({super.key, required this.sensorKey});
  final String sensorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final m = _meta[sensorKey] ?? _meta['ph']!;
    final key = _meta.containsKey(sensorKey) ? sensorKey : 'ph';
    final sensor = ref.watch(sensorProvider);
    final status = ref.watch(statusProvider).valueOrNull ?? const DeviceStatus();
    final cfg = ref.watch(settingsProvider).valueOrNull ?? const DeviceSettings();
    final offline = ref.watch(isOfflineProvider);
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final s = sensor.valueOrNull;

    final double? v = switch (key) { 'ph' => s?.ph, 'ec' => s?.ec, 'suhu' => s?.suhu, 'hum' => s?.kelembapan, _ => null };
    final sev = switch (key) { 'ph' => status.ph, 'ec' => status.ec, 'level' => status.levelAir, 'suhu' => status.suhu, _ => status.kelembapan };
    final valueText = key == 'level'
        ? switch (s?.levelAir) { LevelAir.cukup => 'Cukup', LevelAir.rendah => 'Rendah', _ => '-' }
        : key == 'hum' ? (v == null ? '-' : '${v.round()}') : fmtNum(v);
    final (double? min, double? max) = switch (key) { 'ph' => (cfg.phMin, cfg.phMax), 'ec' => (cfg.ecMin, cfg.ecMax), _ => (null, null) };
    final advice = _advice(key, sev, v, min, max);

    return Scaffold(
      appBar: AppBar(title: Text(m.title), backgroundColor: AppColors.bg, surfaceTintColor: Colors.transparent),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        if (offline) ...[OfflineBanner(updatedAt: s?.updatedAt, now: now, compact: true), const SizedBox(height: 12)],
        AppCard(
          child: Column(children: [
            Text.rich(TextSpan(text: valueText, style: AppText.metric(size: 48), children: [
              if (m.unit.isNotEmpty) TextSpan(text: ' ${m.unit}', style: t.titleMedium!.copyWith(color: AppColors.muted)),
            ])),
            const SizedBox(height: 12),
            StatusChip.severity(sev),
            const SizedBox(height: 8),
            Text(s?.updatedAt == null ? 'Waktu pembaruan tidak diketahui' : 'Diperbarui pukul ${hhmm(s!.updatedAt!)}', style: t.bodySmall),
            if (v != null && min != null && max != null && m.lo != null && m.hi != null) ...[
              const SizedBox(height: 20),
              _Gauge(value: v, lo: m.lo!, hi: m.hi!, min: min, max: max),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(fmtNum(m.lo, 0), style: t.bodySmall),
                Text('Batas aman ${fmtNum(min)} - ${fmtNum(max)}', style: t.titleSmall!.copyWith(color: AppColors.okInk)),
                Text(fmtNum(m.hi, 0), style: t.bodySmall),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.info_rounded, color: AppColors.infoInk), const SizedBox(width: 8), Text('Apa ini?', style: t.titleMedium)]),
            const SizedBox(height: 6),
            Text(m.what, style: t.bodyLarge!.copyWith(color: AppColors.muted)),
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(
          color: sev == Severity.waspada ? AppColors.warnBg : (sev == Severity.bahaya || sev == Severity.sensorError) ? AppColors.critBg : Colors.white,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.lightbulb_rounded), const SizedBox(width: 8), Text('Saran tindakan', style: t.titleMedium)]),
            const SizedBox(height: 6),
            Text(advice.$1, style: t.bodyLarge),
            if (advice.$2) ...[
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => context.go('/kontrol'), icon: const Icon(Icons.touch_app_rounded), label: const Text('Buka Kontrol Pompa'))),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Saran tindakan sederhana. Penentuan status tetap dari server; ini hanya teks bantuan.
(String, bool) _advice(String key, Severity sev, double? v, double? min, double? max) {
  if (sev == Severity.normal) return ('Kondisi baik. Tidak ada yang perlu dilakukan.', false);
  if (sev == Severity.sensorError) return ('Sensor memberi angka yang tidak masuk akal. Periksa kabel dan posisi sensor, lalu bersihkan ujungnya.', false);
  if (sev == Severity.unknown) return ('Status belum tersedia dari sistem. Tunggu beberapa saat.', false);
  final high = v != null && max != null && v > max;
  return switch (key) {
    'ph' => (high
        ? 'pH terlalu tinggi. Mode otomatis akan memberi larutan penurun pH. Anda juga bisa menyalakan Pompa Dosing 30 detik, lalu cek lagi dalam 2 jam.'
        : 'pH terlalu rendah. Tambahkan air bersih dari galon dan cek lagi dalam 2 jam.', true),
    'ec' => (high ? 'Nutrisi terlalu pekat. Tambahkan air bersih lewat Pompa Galon.' : 'Nutrisi kurang. Nyalakan Pompa Nutrisi sekitar 1 menit.', true),
    'level' => ('Air di bak hampir habis. Isi galon sekarang dan pastikan selang terpasang. Pompa nutrisi ditahan sampai air cukup.', false),
    'suhu' => ('Geser rak dari sinar matahari langsung dan buat udara bergerak dengan kipas ruangan.', false),
    _ => ('Atur ventilasi ruangan agar udara bergerak.', false),
  };
}

class _Gauge extends StatelessWidget {
  const _Gauge({required this.value, required this.lo, required this.hi, required this.min, required this.max});
  final double value, lo, hi, min, max;

  @override
  Widget build(BuildContext context) {
    double f(double x) => ((x - lo) / (hi - lo)).clamp(0.0, 1.0).toDouble();
    return Semantics(
      label: 'Nilai ${fmtNum(value)}, batas aman ${fmtNum(min)} sampai ${fmtNum(max)}',
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: 28,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(left: 0, right: 0, top: 6, child: Container(height: 16, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(8)))),
            Positioned(left: f(min) * w, width: (f(max) - f(min)) * w, top: 6, child: Container(height: 16, decoration: BoxDecoration(color: AppColors.ok, borderRadius: BorderRadius.circular(8)))),
            Positioned(
              left: f(value) * w - 14, top: 0,
              child: Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.ink, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), boxShadow: const [BoxShadow(blurRadius: 3, color: Color(0x55000000))])),
            ),
          ]),
        );
      }),
    );
  }
}
