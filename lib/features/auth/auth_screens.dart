import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/repositories.dart';
import '../../providers.dart';

// ─── SPLASH ───────────────────────────────────────────────────────────────────

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashState();
}

class _SplashState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _scale = CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6, curve: Curves.elasticOut));
    _fade  = CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 0.7, curve: Curves.easeIn));
    _slide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 0.7, curve: Curves.easeOut)));
    _ctrl.forward();
    _go();
  }

  Future<void> _go() async {
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    final user = await ref.read(authUserProvider.future);
    if (!mounted) return;
    context.go(user == null ? '/login' : '/beranda');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
          ),
        ),
        child: Stack(
          children: [
            // decorative circles
            Positioned(top: -60, right: -60, child: _Circle(120, Colors.white.withAlpha(15))),
            Positioned(top: 100, left: -80, child: _Circle(180, Colors.white.withAlpha(10))),
            Positioned(bottom: -40, right: -40, child: _Circle(200, Colors.white.withAlpha(12))),
            Positioned(bottom: 80, left: 20, child: _Circle(80, Colors.white.withAlpha(8))),
            // leaf decorations
            ..._leaves(size),
            // main content
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 30, spreadRadius: 2)],
                    ),
                    child: const Icon(Icons.eco_rounded, size: 64, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 28),
                SlideTransition(
                  position: _slide,
                  child: FadeTransition(
                    opacity: _fade,
                    child: Column(children: [
                      Text('AgroSync',
                        style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                          color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      Text('Pantau kebun hidroponik Anda',
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          color: Colors.white.withAlpha(204))),
                    ]),
                  ),
                ),
              ]),
            ),
            // loading indicator at bottom
            Positioned(
              bottom: 60,
              left: 0, right: 0,
              child: FadeTransition(
                opacity: _fade,
                child: Column(children: [
                  const SizedBox(
                    width: 28, height: 28,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  ),
                  const SizedBox(height: 12),
                  Text('Memeriksa sesi Anda...',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.white.withAlpha(180))),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _leaves(Size size) {
    const positions = [
      (0.08, 0.12, 40.0, 0.06),
      (0.85, 0.08, 30.0, 0.05),
      (0.15, 0.82, 50.0, 0.07),
      (0.78, 0.75, 35.0, 0.04),
      (0.5, 0.05, 25.0, 0.03),
    ];
    return positions.map((p) => Positioned(
      left: size.width * p.$1,
      top: size.height * p.$2,
      child: Opacity(
        opacity: p.$4,
        child: Icon(Icons.eco_rounded, size: p.$3, color: Colors.white),
      ),
    )).toList();
  }
}

class _Circle extends StatelessWidget {
  const _Circle(this.size, this.color);
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

// ─── LOGIN ────────────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _email;
  late final TextEditingController _pw;
  late AnimationController _formCtrl;
  late Animation<Offset> _formSlide;
  bool _show = false, _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final dummy = ref.read(dummyBackendProvider) != null;
    _email = TextEditingController(text: dummy ? 'sari@email.com' : '');
    _pw    = TextEditingController(text: dummy ? 'agrosync123' : '');
    _formCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _formCtrl, curve: Curves.easeOut));
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _formCtrl.forward();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    _formCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_email.text.contains('@')) return setState(() => _error = 'Alamat email belum benar. Contoh: nama@email.com');
    if (_pw.text.isEmpty)          return setState(() => _error = 'Kata sandi belum diisi.');
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(authRepoProvider).signIn(_email.text, _pw.text);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal masuk. Periksa koneksi internet lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t    = Theme.of(context).textTheme;
    final dummy = ref.watch(dummyBackendProvider) != null;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Stack(
        children: [
          // ── hero header ───────────────────────────
          SizedBox(
            height: size.height * 0.38,
            width: double.infinity,
            child: _HeroHeader(),
          ),
          // ── scrollable form ───────────────────────
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: size.height * 0.28),
                SlideTransition(
                  position: _formSlide,
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(minHeight: size.height * 0.72),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF7F9F7),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Selamat datang kembali', style: t.headlineMedium),
                      const SizedBox(height: 4),
                      Text('Masuk untuk memantau kebun hidroponik Anda.',
                        style: t.bodyLarge!.copyWith(color: AppColors.muted)),
                      const SizedBox(height: 28),

                      // email field
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        style: t.bodyLarge,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // password field
                      TextField(
                        controller: _pw,
                        obscureText: !_show,
                        autofillHints: const [AutofillHints.password],
                        style: t.bodyLarge,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Kata sandi',
                          prefixIcon: const Icon(Icons.lock_rounded),
                          suffixIcon: IconButton(
                            tooltip: _show ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi',
                            icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                            onPressed: () => setState(() => _show = !_show),
                          ),
                        ),
                      ),

                      // error banner
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.critBg, borderRadius: BorderRadius.circular(16)),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.error_rounded, color: AppColors.critInk),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_error!, style: t.bodyLarge!.copyWith(color: AppColors.critInk, fontWeight: FontWeight.w600))),
                            ]),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),

                      // login button
                      SizedBox(
                        width: double.infinity, height: 56,
                        child: FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('Masuk'),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // info note
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: Text('Akun dibuat oleh tim AgroSync. Belum punya akun? Hubungi tim Anda.', style: t.bodySmall),
                      ),
                      if (dummy) Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(20)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.science_rounded, size: 14, color: AppColors.infoInk),
                              const SizedBox(width: 6),
                              Text('Mode dummy · akun contoh sudah terisi',
                                style: t.bodySmall!.copyWith(color: AppColors.infoInk, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
        ),
      ),
      child: Stack(
        children: [
          // decorative circles
          Positioned(top: -20, right: -20, child: _Circle2(100, Colors.white.withAlpha(18))),
          Positioned(top: 40, left: -30, child: _Circle2(80, Colors.white.withAlpha(12))),
          Positioned(bottom: -10, right: 40, child: _Circle2(60, Colors.white.withAlpha(10))),
          // leaf icons scattered
          Positioned(top: 30, right: 60, child: Opacity(opacity: 0.12, child: Transform.rotate(angle: 0.4, child: const Icon(Icons.eco_rounded, size: 50, color: Colors.white)))),
          Positioned(top: 60, left: 30, child: Opacity(opacity: 0.08, child: Transform.rotate(angle: -0.6, child: const Icon(Icons.eco_rounded, size: 35, color: Colors.white)))),
          // logo + brand
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(height: 16),
                Container(
                  width: 76, height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 20)],
                  ),
                  child: const Icon(Icons.eco_rounded, size: 44, color: AppColors.primary),
                ),
                const SizedBox(height: 14),
                Text('AgroSync',
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                const SizedBox(height: 4),
                Text('Sistem Pemantauan Hidroponik',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.white.withAlpha(204))),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Circle2 extends StatelessWidget {
  const _Circle2(this.size, this.color);
  final double size; final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

// ─── PERMISSION ───────────────────────────────────────────────────────────────

class PermissionScreen extends ConsumerWidget {
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(height: 24),
                  Stack(clipBehavior: Clip.none, children: const [
                    IconBadge(Icons.notifications_active_rounded, bg: AppColors.warn, fg: AppColors.ink, size: 120),
                    Positioned(right: -4, top: -4, child: IconBadge(Icons.warning_amber_rounded, bg: AppColors.crit, fg: Colors.white, size: 44)),
                  ]),
                  const SizedBox(height: 32),
                  Text('Aktifkan pemberitahuan', style: t.headlineLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(
                    'Kami akan memberi tahu Anda bila air hampir habis, pH atau nutrisi di luar batas, atau perangkat berhenti mengirim data, walau aplikasi sedang ditutup.',
                    style: t.bodyLarge!.copyWith(color: AppColors.muted, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  for (final s in const ['Hanya kondisi penting, tanpa iklan', 'Bisa dimatikan kapan saja di Pengaturan'])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [const Icon(Icons.check_circle_rounded, color: AppColors.ok), const SizedBox(width: 8), Expanded(child: Text(s, style: t.bodyLarge))]),
                    ),
                ]),
              ),
            ),
            SizedBox(
              width: double.infinity, height: 56,
              child: FilledButton(
                onPressed: () async {
                  await ref.read(notifPermProvider.notifier).request();
                  if (context.mounted) context.go('/beranda');
                },
                child: const Text('Izinkan pemberitahuan'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                ref.read(notifPermProvider.notifier).skip();
                context.go('/beranda');
              },
              child: const Text('Nanti saja'),
            ),
          ]),
        ),
      ),
    );
  }
}
