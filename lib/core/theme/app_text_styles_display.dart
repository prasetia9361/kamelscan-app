import 'package:flutter/material.dart';

import 'app_text_styles.dart';

/// Gaya tampilan tambahan — REVISI TAMPILAN (`PANDUAN_TAMPILAN.md` Langkah 2).
///
/// Sengaja berkas terpisah supaya `app_text_styles.dart` yang sudah diuji tidak
/// perlu disentuh.
///
/// - [kicker]    — label bagian: huruf kecil, spasi lebar, ganti judul tebal.
///                 Ini yang menggantikan `titleMedium` sebagai penanda bagian;
///                 judul tebal berukuran sama di seluruh halaman membuat semua
///                 bagian terasa sepenting satu sama lain, dan tidak ada yang
///                 menonjol.
/// - [statHero]  — angka pantauan tanpa kotak.
/// - [resiStamp] — nomor resi sebagai objek utama pada detail video dan kepala
///                 dialog resi ganda.
/// - [metaMono]  — keterangan mono kecil: stempel waktu, koordinat, nama
///                 marketplace.
///
/// ⚠️ Sama seperti `AppTextStyles`, semua angka yang berubah-ubah wajib
/// `tabularFigures()` — tanpa itu lebar tiap angka berbeda dan tampilan
/// bergoyang setiap kali angkanya diperbarui (§3.3).
class AppDisplayStyles {
  const AppDisplayStyles._();

  static const TextStyle kicker = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 11,
    height: 1,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.0,
  );

  static const TextStyle statHero = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 40,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle resiStamp = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 25,
    height: 30 / 25,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Keterangan mono kecil: stempel waktu, koordinat, nama marketplace.
  static const TextStyle metaMono = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 11,
    height: 15 / 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );
}
