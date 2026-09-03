import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_constants.dart';
import '../models/tutorial.dart';
import '../services/supabase_service.dart';
import '../utils/result.dart';

/// Daftar tutorial yang dilihat Owner dan packer (Bab 9.9).
///
/// ⚠️ Hanya sisi **baca**. CRUD milik Admin hidup di
/// `AdminSettingsRepository`, mengikuti pemisahan yang sudah dipakai promo:
/// `findPromo` untuk pelanggan ada di `SubscriptionRepository`, sedangkan
/// `upsertPromo` ada di repository Admin. Menyatukannya berarti layar
/// pelanggan mengimpor berkas yang penuh operasi yang tidak boleh ia panggil.
///
/// 🔴 Tidak ada migrasi yang dibutuhkan berkas ini. Tabel `tutorials` sudah ada
/// sejak migrasi 10 dan izinnya sejak migrasi 14: `tutorials_read` memakai
/// `using (is_active)`, jadi **server sendiri** yang menyembunyikan langkah
/// nonaktif dari pelanggan. Saringan `is_active` di bawah karena itu bukan
/// penjagaan — ia hanya membuat maksudnya terbaca di tempat kueri ini ditulis.
class TutorialRepository {
  const TutorialRepository(this._client);

  final SupabaseClient _client;

  /// Seluruh langkah aktif, sudah terurut.
  ///
  /// Pengurutannya dilakukan **di aplikasi** lewat [Tutorial.urutkan], bukan
  /// `order('step_order')` di server. Alasannya ada di dartdoc `urutkan`:
  /// `step_order` tidak unik, dan tanpa pemutus seri dua langkah bernomor sama
  /// bertukar tempat setiap kali daftarnya dimuat ulang. PostgreSQL tidak
  /// menjanjikan urutan yang tetap untuk baris yang nilai `order by`-nya sama.
  Future<Result<List<Tutorial>>> fetchActive() async {
    try {
      final rows = await _client
          .from(AppConstants.tblTutorials)
          .select()
          .eq('is_active', true);

      final daftar = rows.map((r) => Tutorial.fromJson(r)).toList()
        ..sort(Tutorial.urutkan);
      return Result.ok(List.unmodifiable(daftar));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }
}
