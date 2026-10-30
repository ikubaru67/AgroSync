import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/dummy/dummy_backend.dart';
import '../../providers.dart';

class PengaturanScreen extends ConsumerWidget {
  const PengaturanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final user = ref.watch(authUserProvider).valueOrNull;
    final perm = ref.watch(notifPermProvider);
    final dummy = ref.watch(dummyBackendProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan dan Profil'), backgroundColor: AppColors.bg, surfaceTintColor: Colors.transparent),
      body: ResponsiveMaxWidth(child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
        AppCard(
          child: Row(children: [
            const IconBadge(Icons.person_rounded, bg: AppColors.primary, fg: Colors.white, size: 56),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user?.email ?? '-', style: t.titleMedium, overflow: TextOverflow.ellipsis),
              Text('Perangkat: ${user?.deviceId ?? '-'}', style: t.bodySmall),
            ])),
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            secondary: const Icon(Icons.notifications_rounded, color: AppColors.tealInk),
            title: Text('Pemberitahuan', style: t.titleMedium),
            subtitle: Text(perm == NotifPermission.granted ? 'Aktif. Anda akan diberi tahu bila ada gangguan.' : 'Mati. Anda bisa ketinggalan peringatan.', style: t.bodySmall),
            value: perm == NotifPermission.granted,
            onChanged: (v) => v ? ref.read(notifPermProvider.notifier).request() : ref.read(notifPermProvider.notifier).disable(),
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: const Icon(Icons.shield_rounded, color: AppColors.tealInk),
              title: Text('Kebijakan Privasi', style: t.titleMedium),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (k, v) in const [
                  ('Data apa', 'Email, kode akun, dan token notifikasi. Tidak ada lokasi, kontak, atau kamera ponsel.'),
                  ('Untuk apa', 'Masuk akun dan mengirim peringatan kebun.'),
                  ('Siapa yang melihat', 'Hanya anggota perangkat Anda.'),
                  ('Hapus data', 'Hubungi tim AgroSync. Permintaan diproses secara manual.'),
                ])
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: Text.rich(TextSpan(children: [TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)), TextSpan(text: v)]), style: t.bodyLarge!.copyWith(color: AppColors.muted))),
              ],
            ),
          ),
        ),
        if (dummy != null) ...[const SizedBox(height: 12), _DummyPanel(b: dummy)],
        const SizedBox(height: 16),
        Center(child: Text('AgroSync versi 0.1.0 (MVP)', style: t.bodySmall)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Keluar'),
            onPressed: () async {
              final ok = await confirmDialog(context, title: 'Keluar dari akun?', body: 'Anda perlu masuk lagi untuk melihat kebun. Notifikasi di ponsel ini akan berhenti.', confirmLabel: 'Ya, keluar', danger: true);
              if (ok) await signOut(ref);
            },
          ),
        ),
      ])),
    );
  }
}

/// Panel simulasi khusus flavor dummy: mencoba semua keadaan layar tanpa perangkat asli (dokumen 7.5).
class _DummyPanel extends StatelessWidget {
  const _DummyPanel({required this.b});
  final DummyBackend b;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const names = {Scenario.normal: 'Normal', Scenario.waspada: 'Waspada', Scenario.bahaya: 'Bahaya', Scenario.offline: 'Perangkat mati'};
    return AppCard(
      color: AppColors.okBg,
      borderColor: AppColors.primary,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Mode data dummy (pengembang)', style: t.titleMedium),
        Text('Coba tiap keadaan layar tanpa perangkat asli.', style: t.bodySmall),
        const SizedBox(height: 12),
        StreamBuilder<Scenario>(
          stream: b.scenario.stream,
          builder: (_, snap) {
            final cur = snap.data ?? b.scenario.value;
            return Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in names.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: cur == e.key,
                  showCheckmark: false,
                  labelStyle: t.titleSmall!.copyWith(color: cur == e.key ? Colors.white : AppColors.ink),
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  onSelected: (_) => b.setScenario(e.key),
                ),
            ]);
          },
        ),
        StreamBuilder<bool>(
          stream: b.emptyLog.stream,
          builder: (_, s) => SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Riwayat kosong', style: t.bodyLarge), value: s.data ?? false, onChanged: b.setEmptyLog),
        ),
        StreamBuilder<bool>(
          stream: b.noResponse.stream,
          builder: (_, s) => SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Perangkat tidak merespons perintah', style: t.bodyLarge), value: s.data ?? false, onChanged: (v) => b.noResponse.value = v),
        ),
      ]),
    );
  }
}
