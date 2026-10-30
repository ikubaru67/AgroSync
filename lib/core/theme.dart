import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet AgroSync. Warna status selalu dipasangkan dengan ikon + teks.
/// Teks di atas latar terang memakai varian "Ink" yang lebih gelap agar
/// memenuhi kontras WCAG AA (4,5:1).
class AppColors {
  static const primary = Color(0xFF2E7D32);
  static const accent = Color(0xFF66BB6A);
  static const teal = Color(0xFF00897B);
  static const tealInk = Color(0xFF00695C);
  static const sky = Color(0xFF4FC3F7);
  static const bg = Color(0xFFF7F9F7);
  static const ink = Color(0xFF1B1E1C);
  static const muted = Color(0xFF4A524C);
  static const line = Color(0xFFDFE6DF);
  static const field = Color(0xFF8A948C);

  static const ok = Color(0xFF43A047);
  static const okInk = Color(0xFF1B5E20);
  static const okBg = Color(0xFFE8F5E9);
  static const warn = Color(0xFFFFB300);
  static const warnInk = Color(0xFF5D4300);
  static const warnBg = Color(0xFFFFF4D1);
  static const crit = Color(0xFFE53935);
  static const critInk = Color(0xFFB71C1C);
  static const critBg = Color(0xFFFDECEA);
  static const infoInk = Color(0xFF01579B);
  static const infoBg = Color(0xFFE3F4FC);
}

class AppText {
  /// Angka kunci (nilai sensor): 32sp tebal, Inter.
  static TextStyle metric({double size = 32, Color color = AppColors.ink}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: FontWeight.w700, color: color, height: 1.1);
}

class AppTheme {
  static TextStyle _h(double s, [FontWeight w = FontWeight.w600, Color c = AppColors.ink]) =>
      GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.25);
  static TextStyle _b(double s, [FontWeight w = FontWeight.w400, Color c = AppColors.ink]) =>
      GoogleFonts.inter(fontSize: s, fontWeight: w, color: c, height: 1.4);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.teal,
      tertiary: AppColors.sky,
      error: AppColors.critInk,
      surface: Colors.white,
      onSurface: AppColors.ink,
    );
    // Poppins untuk judul dan tombol; Inter untuk isi dan data. Isi minimal 14sp.
    final text = TextTheme(
      headlineLarge: _h(28),
      headlineMedium: _h(24),
      headlineSmall: _h(20),
      titleLarge: _h(20),
      titleMedium: _h(16),
      titleSmall: _h(14),
      labelLarge: _h(16),
      labelMedium: _h(14),
      labelSmall: _b(14, FontWeight.w500),
      bodyLarge: _b(16),
      bodyMedium: _b(15),
      bodySmall: _b(14, FontWeight.w400, AppColors.muted),
    );
    const stadium = StadiumBorder();
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: text,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          shape: stadium,
          textStyle: _h(16),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 56),
          shape: stadium,
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 2),
          textStyle: _h(16),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 48),
          foregroundColor: AppColors.primary,
          textStyle: _h(16),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: _b(16, FontWeight.w500, AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.field, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.field, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.okBg,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => _b(
              14,
              states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              states.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted,
            )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 26,
              color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted,
            )),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 56)),
          textStyle: WidgetStatePropertyAll(_h(16)),
          backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? AppColors.primary : Colors.white),
          foregroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.muted),
          side: const WidgetStatePropertyAll(BorderSide(color: AppColors.line, width: 2)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: _b(15, FontWeight.w500, Colors.white),
      ),
    );
  }
}
