import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../providers.dart';

String _gejala(String? kode) => switch (kode) {
      'tidak_ada' => 'Tidak ada gejala',
      'defisiensi_n' => 'Kurang nitrogen (daun menguning)',
      'defisiensi_k' => 'Kurang kalium (tepi daun cokelat)',
      'hawar' => 'Bercak pada daun',
      null => '-',
      _ => 'Gejala belum dikenali',
    };

class TanamanScreen extends ConsumerStatefulWidget {
  const TanamanScreen({super.key});
  @override
  ConsumerState<TanamanScreen> createState() => _TanamanState();
}

class _TanamanState extends ConsumerState<TanamanScreen> {
  int _tier = 1;
  final Set<int> _retried = {};
  bool _retrying = false;

  void _retry() async {
    setState(() => _retrying = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      setState(() {
        _retried.add(_tier);
        _retrying = false;
      });
    }
  }

  void _zoom() => showDialog<void>(
        context: context,
        builder: (ctx) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Stack(children: [
              Center(child: InteractiveViewer(minScale: 1, maxScale: 5, child: PlantPhoto(tier: _tier))),
              Positioned(top: 8, right: 8, child: IconButton.filled(tooltip: 'Tutup', style: IconButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded))),
              const Positioned(bottom: 16, left: 0, right: 0, child: Center(child: Text('Cubit dua jari untuk memperbesar', style: TextStyle(color: Colors.white, fontSize: 14)))),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final plant = ref.watch(plantProvider(_tier));
    final pred = ref.watch(predictionProvider).valueOrNull;
    final now = DateTime.now();

    return ResponsiveMaxWidth(child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
      Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Tanaman', style: t.headlineMedium)),
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [ButtonSegment(value: 1, label: Text('Tingkat 1')), ButtonSegment(value: 2, label: Text('Tingkat 2'))],
          selected: {_tier},
          onSelectionChanged: (s) => setState(() => _tier = s.first),
        ),
      ),
      const SizedBox(height: 12),
      plant.when(
        loading: () => const SkeletonBox(height: 260),
        error: (_, __) => ErrorState(onRetry: () => ref.invalidate(plantProvider(_tier))),
        data: (p) {
          if (p == null) {
            return const EmptyState(icon: Icons.photo_camera_rounded, title: 'Belum ada data tanaman', text: 'Foto dan analisis akan muncul setelah kamera rak mengambil gambar pertama.');
          }
          final path = p.fotoPath;
          final failed = path == 'dummy://error' && !_retried.contains(_tier);
          return Column(children: [
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (path == null)
                  const AspectRatio(aspectRatio: 1.6, child: Center(child: Text('Foto belum tersedia')))
                else if (failed)
                  AspectRatio(
                    aspectRatio: 1.6,
                    child: Container(
                      color: AppColors.line,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.photo_camera_rounded, size: 36, color: AppColors.muted),
                        const SizedBox(height: 8),
                        Text('Foto gagal dimuat', style: t.titleMedium),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(onPressed: _retrying ? null : _retry, icon: const Icon(Icons.refresh_rounded), label: Text(_retrying ? 'Memuat...' : 'Coba lagi')),
                      ]),
                    ),
                  )
                else if (path.startsWith('http'))
                  // Sumber foto final masih [TERBUKA] (dokumen 5.4); URL harus privat/bertoken.
                  Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const AspectRatio(aspectRatio: 1.6, child: Center(child: Text('Foto gagal dimuat'))))
                else
                  InkWell(
                    onTap: _zoom,
                    child: Stack(children: [
                      PlantPhoto(tier: _tier),
                      const Positioned(right: 12, top: 12, child: IconBadge(Icons.zoom_in_rounded, bg: Color(0x99000000), fg: Colors.white, size: 48)),
                    ]),
                  ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    const Icon(Icons.photo_camera_rounded, size: 16, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Text(p.fotoDiambil == null ? 'Waktu foto tidak diketahui' : 'Foto diambil pukul ${hhmm(p.fotoDiambil!)}', style: t.bodySmall),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hasil Analisis', style: t.titleLarge),
                const SizedBox(height: 8),
                if (p.hasAnalysis) ...[
                  Row(children: [
                    Expanded(child: _Stat(label: 'Luas daun (kanopi)', value: p.ukuran == null ? '-' : '${p.ukuran!.round()}', unit: 'cm²')),
                    const SizedBox(width: 12),
                    Expanded(child: _Stat(label: 'Jumlah daun', value: p.jumlahDaun?.toString() ?? '-', unit: 'helai')),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    StatusChip(level: p.gejalaKode == 'tidak_ada' ? Level.ok : (p.gejalaKode == null ? Level.neutral : Level.warn), text: _gejala(p.gejalaKode)),
                    if (p.gejalaKeyakinan != null) Text('Keyakinan analisis ${(p.gejalaKeyakinan! * 100).round()}%', style: t.bodySmall),
                  ]),
                ] else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.info_rounded, color: AppColors.infoInk),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Analisis belum tersedia', style: t.titleMedium),
                          Text('Ini bukan kesalahan. Hasil akan muncul setelah foto berikutnya diproses.', style: t.bodySmall),
                        ]),
                      ),
                    ]),
                  ),
              ]),
            ),
          ]);
        },
      ),
      const SizedBox(height: 12),
      AppCard(
        color: AppColors.okBg,
        borderColor: const Color(0x6643A047),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text('Rekomendasi', style: t.titleLarge)), const Pill('PERKIRAAN', bg: Colors.white)]),
          const SizedBox(height: 12),
          if (pred == null)
            Text('Rekomendasi belum tersedia. Model prediksi belum mengirim hasil.', style: t.bodyLarge)
          else ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const IconBadge(Icons.water_drop_rounded, bg: AppColors.infoBg, fg: AppColors.infoInk),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Penyiraman', style: t.bodySmall),
                Text(pred.rekomendasiSiram ?? 'Belum tersedia', style: t.titleMedium),
                if (pred.alasan != null) Text(pred.alasan!, style: t.bodyMedium),
              ])),
            ]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const IconBadge(Icons.calendar_month_rounded, bg: Colors.white, fg: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Perkiraan panen', style: t.bodySmall),
                if (pred.perkiraanPanen == null)
                  Text('Belum tersedia', style: t.titleMedium)
                else ...[
                  Text('± ${math.max(0, ((pred.perkiraanPanen! - now.millisecondsSinceEpoch) / 86400000).ceil())} hari lagi', style: AppText.metric(size: 26, color: AppColors.primary)),
                  Text('Sekitar ${dateShort(pred.perkiraanPanen!)}', style: t.bodyMedium),
                ],
              ])),
            ]),
          ],
          const SizedBox(height: 12),
          Text('Ini hanya perkiraan dari model. Rekomendasi tidak mengubah penyiraman otomatis.', style: t.bodySmall),
        ]),
      ),
    ]));
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.unit});
  final String label, value, unit;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: t.bodySmall),
        Text.rich(TextSpan(text: value, style: AppText.metric(size: 28), children: [TextSpan(text: ' $unit', style: t.bodyLarge!.copyWith(color: AppColors.muted, fontWeight: FontWeight.w700))])),
      ]),
    );
  }
}
