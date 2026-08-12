import 'package:flutter/material.dart';

/// Tipografi aplikasi.
///
/// Bab 9.10: ukuran font isi minimal **14 sp**, angka penting minimal **20 sp**.
/// Aplikasi dipakai di gudang — teks kecil tidak terbaca.
class AppTextStyles {
  const AppTextStyles._();

  /// Belum ada font kustom dari desainer; memakai font bawaan platform.
  static const String? fontFamily = null;

  static const TextTheme textTheme = TextTheme(
    displaySmall: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, height: 1.2),
    headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25),
    headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
    titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.35),
    titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.35),
    bodyLarge: TextStyle(fontSize: 16, height: 1.45),
    bodyMedium: TextStyle(fontSize: 14, height: 1.45),
    // Batas bawah 14 sp — bodySmall lama (12 sp) melanggar aturan Bab 9.10.
    bodySmall: TextStyle(fontSize: 14, height: 1.4),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    labelSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  );

  /// Angka besar pada kartu monitoring — minimal 20 sp, dipakai 28 sp.
  static const TextStyle metricValue =
      TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.1);

  static const TextStyle metricLabel =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.2);

  /// Nomor resi — monospace agar digit sejajar dan mudah dibandingkan.
  static const TextStyle resiCode = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    fontFamily: 'monospace',
    letterSpacing: 0.5,
  );

  /// Penghitung durasi di layar rekam.
  static const TextStyle recordingTimer = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
