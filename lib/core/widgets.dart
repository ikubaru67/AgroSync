import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'format.dart';
import 'theme.dart';

/// Batas lebar untuk tata letak adaptif: lebih lebar dari ini dianggap tablet/landscape.
const kTablet = 840.0;

/// Membatasi lebar konten layar (Center + ConstrainedBox) di layar lebar
/// tanpa mengubah tata letak ponsel.
class ResponsiveMaxWidth extends StatelessWidget {
  const ResponsiveMaxWidth({super.key, required this.child, this.maxWidth = 640});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}

enum Level { ok, warn, crit, info, neutral }

class LevelStyle {
  const LevelStyle(this.bg, this.ink, this.dot, this.dotFg, this.icon, this.label);
  final Color bg, ink, dot, dotFg;
  final IconData icon;
  final String label;
}

LevelStyle styleOf(Level l) => switch (l) {
      Level.ok => const LevelStyle(AppColors.okBg, AppColors.okInk, AppColors.ok, Colors.white, Icons.check_circle_rounded, 'Normal'),
      Level.warn => const LevelStyle(AppColors.warnBg, AppColors.warnInk, AppColors.warn, AppColors.ink, Icons.warning_amber_rounded, 'Waspada'),
      Level.crit => const LevelStyle(AppColors.critBg, AppColors.critInk, AppColors.crit, Colors.white, Icons.error_rounded, 'Bahaya'),
      Level.info => const LevelStyle(AppColors.infoBg, AppColors.infoInk, AppColors.sky, AppColors.ink, Icons.info_rounded, 'Info'),
      Level.neutral => const LevelStyle(AppColors.line, AppColors.muted, Color(0xFF6B736D), Colors.white, Icons.help_outline_rounded, 'Belum dinilai'),
    };

Level levelOf(Severity s) => switch (s) {
      Severity.normal => Level.ok,
      Severity.waspada => Level.warn,
      Severity.bahaya || Severity.sensorError => Level.crit,
      Severity.unknown => Level.neutral,
    };

String severityLabel(Severity s) => switch (s) {
      Severity.normal => 'Normal',
      Severity.waspada => 'Waspada',
      Severity.bahaya => 'Bahaya',
      Severity.sensorError => 'Sensor bermasalah',
      Severity.unknown => 'Belum dinilai',
    };

/// Status selalu berupa ikon + teks, tidak pernah warna saja.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.level, this.text});
  StatusChip.severity(Severity s, {super.key, String? text})
      : level = levelOf(s),
        text = text ?? severityLabel(s);
  final Level level;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final st = styleOf(level);
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 4, 12, 4),
      decoration: ShapeDecoration(color: st.bg, shape: const StadiumBorder()),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(color: st.dot, shape: BoxShape.circle),
          child: Icon(st.icon, size: 16, color: st.dotFg),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(text ?? st.label, style: Theme.of(context).textTheme.titleSmall!.copyWith(color: st.ink, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.color = Colors.white, this.borderColor = AppColors.line, this.borderWidth = 1, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final VoidCallback? onTap;
  final Color color, borderColor;
  final double borderWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: borderColor, width: borderWidth)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.bg = AppColors.okBg, this.fg = AppColors.primary, this.size = 44, this.round = true});
  final IconData icon;
  final Color bg, fg;
  final double size;
  final bool round;
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(color: bg, shape: round ? BoxShape.circle : BoxShape.rectangle, borderRadius: round ? null : BorderRadius.circular(16)),
        child: Icon(icon, color: fg, size: size * 0.5),
      );
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.bg = AppColors.okBg, this.fg = AppColors.okInk, this.icon});
  final String text;
  final Color bg, fg;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Text(text, style: Theme.of(context).textTheme.titleSmall!.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ]),
      );
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String body, required String confirmLabel, bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      icon: IconBadge(danger ? Icons.warning_amber_rounded : Icons.power_settings_new_rounded,
          bg: danger ? AppColors.warn : AppColors.okBg, fg: danger ? AppColors.ink : AppColors.primary, size: 52),
      title: Text(title, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.titleLarge),
      content: Text(body, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.bodyLarge),
      actionsOverflowDirection: VerticalDirection.down,
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowButtonSpacing: 8,
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.critInk) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.updatedAt, required this.now, this.compact = false});
  final int? updatedAt;
  final DateTime now;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.warnBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.warn, width: 2)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IconBadge(Icons.wifi_off_rounded, bg: AppColors.warn, fg: AppColors.ink, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Data tidak terbaru', style: t.titleMedium!.copyWith(color: AppColors.warnInk)),
              Text(
                updatedAt == null
                    ? 'Belum ada data dari perangkat.${compact ? '' : ' Periksa listrik dan Wi-Fi di rak.'}'
                    : 'Terakhir diperbarui ${ago(updatedAt!, now)} (pukul ${hhmm(updatedAt!)}).${compact ? '' : ' Periksa listrik dan Wi-Fi di rak.'}',
                style: t.bodyMedium!.copyWith(color: AppColors.warnInk),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.text, this.action});
  final IconData icon;
  final String title, text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          IconBadge(icon, bg: AppColors.line, fg: AppColors.muted, size: 64),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(text, style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: AppColors.muted), textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.onRetry, this.message = 'Data gagal dimuat. Periksa koneksi internet Anda.'});
  final VoidCallback onRetry;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Terjadi masalah',
          text: message,
          action: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Coba lagi')),
        ),
      );
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(24)),
      );
}

class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.sub});
  final String title;
  final String? sub;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          if (sub != null) Text(sub!, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

/// Placeholder foto tanaman (tampak atas) selama sumber foto belum diputuskan (dokumen 5.4).
class PlantPhotoPainter extends CustomPainter {
  PlantPhotoPainter(this.tier);
  final int tier;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2B3A2D));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.65, w, h * 0.35), Paint()..color = const Color(0xFF1F2B21));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.04, h * 0.6, w * 0.92, h * 0.1), const Radius.circular(6)), Paint()..color = AppColors.tealInk);
    final n = tier == 1 ? 6 : 5;
    for (var i = 0; i < n; i++) {
      final cx = w * 0.12 + i * (w * 0.76 / (n - 1));
      final cy = h * 0.46;
      for (var a = 0; a < 6; a++) {
        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate((a * 60 + i * 11) * 3.14159 / 180);
        final leaf = Rect.fromCenter(center: Offset(0, -h * 0.08), width: w * 0.075, height: h * 0.2);
        canvas.drawOval(leaf, Paint()..color = i.isEven ? AppColors.ok : AppColors.accent);
        canvas.drawOval(leaf, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = AppColors.primary);
        canvas.restore();
      }
      canvas.drawCircle(Offset(cx, cy), w * 0.022, Paint()..color = const Color(0xFFA5D6A7));
    }
  }

  @override
  bool shouldRepaint(PlantPhotoPainter old) => old.tier != tier;
}

class PlantPhoto extends StatelessWidget {
  const PlantPhoto({super.key, required this.tier});
  final int tier;
  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: 'Foto tanaman tingkat $tier',
        child: AspectRatio(aspectRatio: 1.6, child: CustomPaint(painter: PlantPhotoPainter(tier))),
      );
}
