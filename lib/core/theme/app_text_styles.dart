import 'package:flutter/material.dart';

/// Sumber: `palet_warna_dan_tipografi.md` §3.
///
/// 🔴 Huruf dibundel sebagai aset, **bukan** lewat `google_fonts` yang mengunduh
/// saat aplikasi pertama dibuka. Di gudang bersinyal buruk, teks akan tampil
/// dengan huruf cadangan atau kosong sama sekali (§6).
class AppFonts {
  const AppFonts._();

  static const String sans = 'Inter';
  static const String mono = 'JetBrainsMono';
}

class AppTextStyles {
  const AppTextStyles._();

  /// ⚠️ Wajib pada semua angka yang berubah-ubah — penghitung durasi, sisa
  /// token, jumlah video. Tanpa ini lebar tiap angka berbeda dan tampilan
  /// bergoyang setiap detik (§3.3).
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static TextTheme textTheme(Color onSurface) => TextTheme(
        displayMedium: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 40,
            height: 48 / 40,
            fontWeight: FontWeight.w700,
            color: onSurface,
            fontFeatures: _tabular),
        displaySmall: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 32,
            height: 40 / 32,
            fontWeight: FontWeight.w700,
            color: onSurface,
            fontFeatures: _tabular),
        headlineMedium: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 26,
            height: 34 / 26,
            fontWeight: FontWeight.w700,
            color: onSurface),
        headlineSmall: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 22,
            height: 30 / 22,
            fontWeight: FontWeight.w600,
            color: onSurface),
        titleLarge: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 20,
            height: 28 / 20,
            fontWeight: FontWeight.w600,
            color: onSurface),
        titleMedium: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 17,
            height: 24 / 17,
            fontWeight: FontWeight.w600,
            color: onSurface),
        bodyLarge: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 16,
            height: 24 / 16,
            fontWeight: FontWeight.w400,
            color: onSurface),
        bodyMedium: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w400,
            color: onSurface),
        bodySmall: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 13,
            height: 18 / 13,
            fontWeight: FontWeight.w400,
            color: onSurface),
        labelLarge: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 15,
            height: 20 / 15,
            fontWeight: FontWeight.w600,
            color: onSurface),
        labelMedium: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 13,
            height: 16 / 13,
            fontWeight: FontWeight.w600,
            color: onSurface),
        labelSmall: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w500,
            color: onSurface),
      );

  // ---- Gaya khusus, sengaja tidak masuk TextTheme (§3.3) ----

  /// 🔴 Nomor resi WAJIB monospace. Pada Inter dan hampir semua huruf
  /// sans-serif, `0` dan `O` nyaris identik, begitu pula `1`, `l`, dan `I`.
  /// Packer yang membacakan resi lewat telepon ke pusat resolusi marketplace
  /// akan salah, dan bukti videonya jadi tidak ditemukan.
  static const TextStyle resiDisplay = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 26,
    height: 34 / 26,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    fontFeatures: _tabular,
  );

  static const TextStyle resiInline = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
    fontFeatures: _tabular,
  );

  static const TextStyle timerDisplay = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
  );

  /// Angka besar kartu monitoring.
  static const TextStyle statNumber = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 40,
    height: 48 / 40,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
  );
}

/// Radius, jarak, dan ukuran sentuh (§5).
class AppSizes {
  const AppSizes._();

  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusFull = 999;

  static const double spaceXs = 4;
  static const double spaceSm = 8;

  /// Padding baku halaman.
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  /// Batas mutlak area sentuh — gudang, sarung tangan.
  static const double touchMin = 48;

  /// Tinggi tombol baku.
  static const double touchComfort = 52;
}
