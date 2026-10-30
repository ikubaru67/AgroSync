import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/pump_info.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../providers.dart';

// ────────────────────────────────────────────────────────────────────────────
// Beranda (Dashboard) Screen
// ────────────────────────────────────────────────────────────────────────────

class BerandaScreen extends ConsumerWidget {
  const BerandaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensor = ref.watch(sensorProvider);
    return sensor.when(
      loading: () => _Skeleton(),
      error: (_, __) => ErrorState(onRetry: () => ref.invalidate(sensorProvider)),
      data: (s) => _Content(sensor: s),
    );
  }
}

class _Skeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    children: const [
      _SkeletonHeader(),
      SizedBox(height: 16),
      SkeletonBox(height: 120),
      SizedBox(height: 12),
      SkeletonBox(height: 170),
      SizedBox(height: 12),
      SkeletonBox(height: 140),
      SizedBox(height: 12),
      SkeletonBox(height: 130),
    ],
  );
}

class _SkeletonHeader extends StatelessWidget {
  const _SkeletonHeader();
  @override
  Widget build(BuildContext context) => Container(
    height: 100,
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: AppColors.line,
      borderRadius: BorderRadius.circular(24),
    ),
  );
}

// ────────────────────────────────────────────────────────────────────────────

class _Content extends ConsumerWidget {
  const _Content({required this.sensor});
  final SensorReading? sensor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t     = Theme.of(context).textTheme;
    final now   = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final offline = ref.watch(isOfflineProvider);
    final status  = ref.watch(statusProvider).valueOrNull ?? const DeviceStatus();
    final pumps   = ref.watch(pumpsProvider).valueOrNull ?? const <PumpState>[];
    final perm    = ref.watch(notifPermProvider);
    final pred    = ref.watch(predictionProvider).valueOrNull;
    final s       = sensor;

    if (s == null) {
      return const EmptyState(
        icon: Icons.sensors_off_rounded,
        title: 'Belum ada data sensor',
        text: 'Data akan muncul setelah perangkat di rak mengirim pembacaan pertama.',
      );
    }

    final heroLevel = offline ? Level.warn : levelOf(status.keseluruhan);
    final heroStyle = styleOf(heroLevel);
    final heroTitle = offline
        ? 'Data Belum Terbarui'
        : switch (status.keseluruhan) {
            Severity.normal      => 'Semua Normal',
            Severity.waspada     => 'Perlu Perhatian',
            Severity.bahaya      => 'Bahaya, Segera Cek',
            Severity.sensorError => 'Sensor Bermasalah',
            Severity.unknown     => 'Status Belum Tersedia',
          };

    String? firstAbnormal() {
      for (final e in {'ph': status.ph, 'ec': status.ec, 'level': status.levelAir, 'suhu': status.suhu, 'hum': status.kelembapan}.entries) {
        if (e.value == Severity.waspada || e.value == Severity.bahaya || e.value == Severity.sensorError) return e.key;
      }
      return null;
    }

    final abnormal = firstAbnormal();

    // greeting based on time
    final hour = now.hour;
    final greeting = hour < 11 ? 'Selamat pagi' : hour < 15 ? 'Selamat siang' : hour < 18 ? 'Selamat sore' : 'Selamat malam';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        // ── Greeting header ──────────────────────────────────────────
        _GreetingHeader(greeting: greeting, now: now, offline: offline),
        const SizedBox(height: 16),

        // ── Offline / notif banners ──────────────────────────────────
        if (offline) ...[OfflineBanner(updatedAt: s.updatedAt, now: now), const SizedBox(height: 12)],
        if (perm == NotifPermission.denied) ...[
          _NotifBanner(onTap: () => ref.read(notifPermProvider.notifier).request()),
          const SizedBox(height: 12),
        ],

        // ── Status keseluruhan ───────────────────────────────────────
        Semantics(
          liveRegion: true,
          child: _StatusCard(
            offline: offline,
            heroStyle: heroStyle,
            heroTitle: heroTitle,
            status: status,
            sensor: s,
            now: now,
            abnormal: abnormal,
          ),
        ),

        // ── Sensor grid ──────────────────────────────────────────────
        const SizedBox(height: 20),
        _SectionHeader(title: 'Kondisi Sekarang', icon: Icons.monitor_heart_rounded),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _SensorTile(icon: Icons.tune_rounded, label: 'pH', value: fmtNum(s.ph), unit: '', sub: 'Tingkat keasaman air', sev: status.ph, onTap: () => context.push('/sensor/ph'))),
            const SizedBox(width: 12),
            Expanded(child: _SensorTile(icon: Icons.science_rounded, label: 'EC / Nutrisi', value: fmtNum(s.ec), unit: 'mS/cm', sub: s.tds == null ? 'Kepekatan pupuk' : 'TDS ${s.tds!.round()} ppm', sev: status.ec, onTap: () => context.push('/sensor/ec'))),
          ]),
        ),
        const SizedBox(height: 12),
        _SensorTile(
          icon: Icons.water_drop_rounded,
          label: 'Level Air',
          unitBg: status.levelAir == Severity.bahaya ? AppColors.critBg : AppColors.infoBg,
          unitFg: status.levelAir == Severity.bahaya ? AppColors.critInk : AppColors.infoInk,
          value: switch (s.levelAir) { LevelAir.cukup => 'Cukup', LevelAir.rendah => 'Rendah', LevelAir.unknown => '-' },
          unit: '',
          sub: switch (s.levelAir) {
            LevelAir.cukup   => 'Air di bak masih aman',
            LevelAir.rendah  => 'Segera isi galon!',
            LevelAir.unknown => 'Belum ada data',
          },
          sev: status.levelAir,
          onTap: () => context.push('/sensor/level'),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _SensorTile(icon: Icons.thermostat_rounded, label: 'Suhu', unitBg: AppColors.warnBg, unitFg: AppColors.warnInk, value: fmtNum(s.suhu), unit: '°C', sub: 'Udara di sekitar rak', sev: status.suhu, onTap: () => context.push('/sensor/suhu'))),
            const SizedBox(width: 12),
            Expanded(child: _SensorTile(icon: Icons.opacity_rounded, label: 'Kelembapan', unitBg: AppColors.infoBg, unitFg: AppColors.infoInk, value: s.kelembapan == null ? '-' : '${s.kelembapan!.round()}', unit: '%', sub: 'Udara di sekitar rak', sev: status.kelembapan, onTap: () => context.push('/sensor/hum'))),
          ]),
        ),

        // ── Pompa ────────────────────────────────────────────────────
        const SizedBox(height: 20),
        _SectionHeader(title: 'Status Pompa', icon: Icons.water_rounded, trailing: _ModeChip(mode: ref.watch(settingsProvider).valueOrNull?.mode)),
        const SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            if (pumps.isEmpty)
              Padding(padding: const EdgeInsets.all(20), child: Text('Belum ada data pompa.', style: t.bodyLarge)),
            for (int i = 0; i < pumps.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.line, indent: 16, endIndent: 16),
              _PumpRow(p: pumps[i], now: now),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
              child: OutlinedButton.icon(
                onPressed: () => context.go('/kontrol'),
                icon: const Icon(Icons.touch_app_rounded),
                label: const Text('Atur pompa sendiri'),
              ),
            ),
          ]),
        ),

        // ── Tanaman ──────────────────────────────────────────────────
        const SizedBox(height: 20),
        _SectionHeader(title: 'Tanaman', icon: Icons.eco_rounded),
        const SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          onTap: () => context.go('/tanaman'),
          child: Column(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Row(children: [
                Expanded(child: _PlantTierCard(tier: 1)),
                Container(width: 2, height: 160, color: const Color(0xFFF7F9F7)),
                Expanded(child: _PlantTierCard(tier: 2)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Lihat analisis tanaman', style: t.titleMedium),
                  Text('Foto terbaru & hasil CV per tingkat', style: t.bodySmall),
                ])),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.okBg, shape: BoxShape.circle),
                  child: const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                ),
              ]),
            ),
          ]),
        ),

        // ── Rekomendasi ──────────────────────────────────────────────
        const SizedBox(height: 12),
        _RekomCard(pred: pred, now: now, onTap: () => context.go('/tanaman')),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.greeting, required this.now, required this.offline});
  final String greeting;
  final DateTime now;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final weekdays = ['Senin','Selasa','Rabu','Kamis','Jumat','Sabtu','Minggu'];
    final months   = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    final dateStr  = '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(greeting, style: t.bodyMedium!.copyWith(color: Colors.white.withAlpha(200))),
          const SizedBox(height: 2),
          Text('Kebun Hidroponik Anda', style: t.titleLarge!.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(offline ? Icons.wifi_off_rounded : Icons.wifi_rounded, size: 14, color: Colors.white.withAlpha(180)),
            const SizedBox(width: 4),
            Text(offline ? 'Perangkat offline' : 'Perangkat online',
              style: t.bodySmall!.copyWith(color: Colors.white.withAlpha(200))),
            const SizedBox(width: 10),
            Icon(Icons.calendar_today_rounded, size: 13, color: Colors.white.withAlpha(180)),
            const SizedBox(width: 4),
            Text(dateStr, style: t.bodySmall!.copyWith(color: Colors.white.withAlpha(200))),
          ]),
        ])),
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.eco_rounded, color: Colors.white, size: 30),
        ),
      ]),
    );
  }
}

class _NotifBanner extends StatelessWidget {
  const _NotifBanner({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: AppColors.infoBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const Icon(Icons.notifications_rounded, color: AppColors.infoInk),
            const SizedBox(width: 12),
            Expanded(child: Text('Aktifkan notifikasi agar tidak ketinggalan peringatan.', style: t.bodyLarge!.copyWith(color: AppColors.infoInk, fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.infoInk),
          ]),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.offline, required this.heroStyle, required this.heroTitle,
    required this.status, required this.sensor, required this.now, required this.abnormal,
  });
  final bool offline;
  final LevelStyle heroStyle;
  final String heroTitle;
  final DeviceStatus status;
  final SensorReading sensor;
  final DateTime now;
  final String? abnormal;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final overall = offline ? null : status.keseluruhan;

    return AppCard(
      color: offline ? Colors.white : heroStyle.bg,
      borderColor: offline ? AppColors.line : heroStyle.dot,
      borderWidth: 2,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(child: offline
            ? const StatusChip(level: Level.warn, text: 'Data tidak terbaru')
            : StatusChip.severity(overall!)),
          const SizedBox(width: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: offline ? AppColors.warn : AppColors.ok,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: (offline ? AppColors.warn : AppColors.ok).withAlpha(120), blurRadius: 6, spreadRadius: 1)],
              ),
            ),
            const SizedBox(width: 6),
            Text(offline ? 'Offline' : 'Online',
              style: t.titleSmall!.copyWith(color: offline ? AppColors.warnInk : AppColors.okInk, fontWeight: FontWeight.w700)),
          ]),
        ]),
        const SizedBox(height: 10),
        Text(heroTitle, style: t.headlineMedium!.copyWith(color: offline ? AppColors.ink : heroStyle.ink)),
        const SizedBox(height: 4),
        Text(
          offline ? 'Kami belum menerima data baru dari rak Anda.' : (status.pesan ?? 'Tidak ada pesan dari sistem.'),
          style: t.bodyLarge!.copyWith(color: offline ? AppColors.muted : heroStyle.ink.withAlpha(190)),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.schedule_rounded, size: 14, color: offline ? AppColors.muted : heroStyle.ink.withAlpha(150)),
          const SizedBox(width: 4),
          Text(
            sensor.updatedAt == null ? 'Waktu pembaruan tidak diketahui' : 'Diperbarui ${ago(sensor.updatedAt!, now)} · ${hhmm(sensor.updatedAt!)}',
            style: t.bodySmall!.copyWith(color: offline ? AppColors.muted : heroStyle.ink.withAlpha(160)),
          ),
        ]),
        if (!offline && abnormal != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.push('/sensor/$abnormal'),
              child: const Text('Lihat penyebab dan saran'),
            ),
          ),
        ],
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon, this.trailing});
  final String title;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: AppColors.okBg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(title, style: t.titleLarge)),
      if (trailing != null) trailing!,
    ]);
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode});
  final OperatingMode? mode;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isManual = mode == OperatingMode.manual;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isManual ? AppColors.warnBg : AppColors.okBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isManual ? Icons.touch_app_rounded : Icons.autorenew_rounded, size: 13, color: isManual ? AppColors.warnInk : AppColors.okInk),
        const SizedBox(width: 4),
        Text(isManual ? 'Manual' : 'Otomatis', style: t.bodySmall!.copyWith(color: isManual ? AppColors.warnInk : AppColors.okInk, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _SensorTile extends StatelessWidget {
  const _SensorTile({
    required this.icon, required this.label, required this.value,
    required this.unit, required this.sub, required this.sev, required this.onTap,
    this.unitBg = AppColors.okBg, this.unitFg = AppColors.primary,
  });
  final IconData icon;
  final String label, value, unit, sub;
  final Severity sev;
  final VoidCallback onTap;
  final Color unitBg, unitFg;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final style = styleOf(levelOf(sev));
    final isAbnormal = sev == Severity.waspada || sev == Severity.bahaya || sev == Severity.sensorError;

    return Semantics(
      button: true, label: '$label $value $unit, ${severityLabel(sev)}',
      child: AppCard(
        onTap: onTap,
        color: isAbnormal ? style.bg.withAlpha(80) : Colors.white,
        borderColor: isAbnormal ? style.dot.withAlpha(130) : AppColors.line,
        child: ExcludeSemantics(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconBadge(icon, bg: isAbnormal ? style.bg : unitBg, fg: isAbnormal ? style.ink : unitFg, size: 36),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: t.titleSmall)),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.muted),
            ]),
            const SizedBox(height: 10),
            Text.rich(TextSpan(
              text: value,
              style: AppText.metric(),
              children: [
                if (unit.isNotEmpty) TextSpan(text: ' $unit', style: t.bodyLarge!.copyWith(color: AppColors.muted, fontWeight: FontWeight.w700)),
              ],
            )),
            const SizedBox(height: 4),
            Text(sub, style: t.bodySmall),
            const SizedBox(height: 8),
            StatusChip.severity(sev),
          ]),
        ),
      ),
    );
  }
}

class _PumpRow extends StatelessWidget {
  const _PumpRow({required this.p, required this.now});
  final PumpState p;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t    = Theme.of(context).textTheme;
    final info = pumpInfo(p.id);
    final left = p.endsAt == null ? 0 : ((p.endsAt! - now.millisecondsSinceEpoch) / 1000).ceil().clamp(0, 86400).toInt();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        Stack(children: [
          IconBadge(info.icon,
            bg: p.on ? AppColors.primary : AppColors.line,
            fg: p.on ? Colors.white : AppColors.muted, size: 42, round: false),
          if (p.on) Positioned(right: 0, top: 0,
            child: Container(width: 12, height: 12,
              decoration: BoxDecoration(color: AppColors.ok, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
            ),
          ),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(info.name, style: t.titleMedium),
          Text(
            p.on
              ? (p.endsAt != null ? 'Sedang menyala · berhenti dalam ${countdown(left)}' : 'Sedang menyala')
              : (p.lastOn == null ? 'Belum pernah menyala' : 'Terakhir ${ago(p.lastOn!, now)}'),
            style: t.bodySmall,
          ),
          Text(pemicuLabel(p.pemicu), style: t.bodySmall!.copyWith(color: AppColors.muted)),
        ])),
        Pill(
          p.on ? 'Nyala' : 'Mati',
          bg: p.on ? AppColors.okBg : AppColors.line,
          fg: p.on ? AppColors.okInk : AppColors.muted,
          icon: p.on ? Icons.play_arrow_rounded : Icons.stop_rounded,
        ),
      ]),
    );
  }
}

class _PlantTierCard extends StatelessWidget {
  const _PlantTierCard({required this.tier});
  final int tier;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      SizedBox(height: 160, child: PlantPhoto(tier: tier)),
      Positioned(top: 8, left: 8, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.black.withAlpha(100), borderRadius: BorderRadius.circular(20)),
        child: Text('Tingkat $tier', style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      )),
    ],
  );
}

class _RekomCard extends StatelessWidget {
  const _RekomCard({required this.pred, required this.now, required this.onTap});
  final Prediction? pred;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final daysLeft = pred?.perkiraanPanen == null ? null : math.max(0, ((pred!.perkiraanPanen! - now.millisecondsSinceEpoch) / 86400000).ceil());
    return AppCard(
      color: AppColors.okBg,
      borderColor: const Color(0x4D43A047),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const IconBadge(Icons.lightbulb_rounded, bg: AppColors.primary, fg: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Pill('PERKIRAAN', bg: Colors.white),
            const SizedBox(height: 4),
            Text(
              pred == null ? 'Rekomendasi belum tersedia.' : (pred!.rekomendasiSiram ?? 'Tidak ada rekomendasi saat ini.'),
              style: t.titleMedium!.copyWith(fontWeight: FontWeight.w700),
            ),
          ])),
        ]),
        if (daysLeft != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withAlpha(180), borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.agriculture_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('Perkiraan panen: $daysLeft hari lagi', style: t.bodyMedium!.copyWith(color: AppColors.okInk, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: const Text('Lihat detail rekomendasi'),
        ),
      ]),
    );
  }
}

int _days(int ms, DateTime now) => math.max(0, ((ms - now.millisecondsSinceEpoch) / 86400000).ceil());
