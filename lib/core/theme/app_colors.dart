import 'package:flutter/material.dart';

/// Palet aplikasi.
///
/// Bab 9.10: warna utama akan ditentukan desainer. Sampai palet Figma tiba,
/// `seedColor` sementara memakai `Colors.indigo` dan seluruh warna turunan
/// diambil dari `ColorScheme.fromSeed` — jadi mengganti palet nanti cukup
/// mengubah [seed], bukan menyisir 30 layar.
class AppColors {
  const AppColors._();

  /// 🟡 SEMENTARA — ganti begitu palet desainer masuk (Bab 17, Minggu 1).
  static const Color seed = Colors.indigo;

  // ---------- Warna semantik yang tidak diturunkan dari seed ----------
  // Warna status harus tetap konsisten di terang maupun gelap.

  static const Color success = Color(0xFF2E7D32);
  static const Color successContainer = Color(0xFFD7F2D9);
  static const Color warning = Color(0xFFE08600);
  static const Color warningContainer = Color(0xFFFFF0D4);
  static const Color danger = Color(0xFFC62828);
  static const Color dangerContainer = Color(0xFFFBDDDD);
  static const Color info = Color(0xFF0277BD);

  /// Indikator token (Bab 7.3): normal / ≤20% / ≤5%.
  static const Color tokenNormal = success;
  static const Color tokenWarning = warning;
  static const Color tokenCritical = danger;

  /// Latar layar kamera — selalu gelap apa pun temanya.
  static const Color cameraBackdrop = Color(0xFF101014);
  static const Color scannerFrame = Color(0xFF00E676);

  /// Warna dasar shimmer skeleton (Bab 9.10).
  static const Color shimmerBaseLight = Color(0xFFE7E7EC);
  static const Color shimmerHighlightLight = Color(0xFFF6F6F9);
  static const Color shimmerBaseDark = Color(0xFF2A2A31);
  static const Color shimmerHighlightDark = Color(0xFF3A3A44);

  /// Warna avatar fallback, dipilih dari hash `user_id` (Bab 9.x).
  static const List<Color> avatarPalette = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFEF6C00),
    Color(0xFF8E24AA),
    Color(0xFF00838F),
    Color(0xFFC2185B),
    Color(0xFF558B2F),
    Color(0xFF6D4C41),
  ];

  static Color avatarFor(String seedText) {
    if (seedText.isEmpty) return avatarPalette.first;
    final hash = seedText.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7FFFFFFF);
    return avatarPalette[hash % avatarPalette.length];
  }

  /// Warna indikator token berdasarkan rasio sisa saldo (Bab 7.3).
  static Color tokenIndicator(double ratio) {
    if (ratio <= 0.05) return tokenCritical;
    if (ratio <= 0.20) return tokenWarning;
    return tokenNormal;
  }
}
