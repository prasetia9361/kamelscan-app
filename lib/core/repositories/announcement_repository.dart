import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_constants.dart';
import '../models/announcement.dart';
import '../models/enums.dart';
import '../services/supabase_service.dart';
import '../utils/result.dart';

/// Iklan & pengumuman yang dilihat Owner dan packer sesudah masuk (migrasi 50).
///
/// ⚠️ Hanya sisi **baca**, ditambah satu tulisan: mencatat bahwa pengguna sudah
/// menutup sebuah pengumuman. CRUD milik Admin hidup di
/// `AdminSettingsRepository`, mengikuti pemisahan yang sudah dipakai promo dan
/// tutorial — layar pelanggan tidak boleh mengimpor berkas yang penuh operasi
/// yang tidak boleh ia panggil.
///
/// 🔴 Saringan `is_active` di bawah bukan penjagaan. Yang menegakkannya policy
/// `announcements_read` (`using (is_active)`) di server; baris di sini hanya
/// membuat maksudnya terbaca di tempat kuerinya ditulis.
class AnnouncementRepository {
  const AnnouncementRepository(this._client);

  final SupabaseClient _client;

  /// Pengumuman aktif yang berlaku untuk [role] dan **belum** ditutup [userId].
  ///
  /// 🔴 Penyaringan menurut peran dan penutupan dikerjakan **di aplikasi**,
  /// bukan sebagai `not.in` di server, dan itu keputusan sadar. Dua alasannya:
  ///
  ///   - Jumlah pengumuman aktif selalu kecil — beberapa baris, bukan ribuan.
  ///     Menyusun filter server untuk itu menukar kejelasan dengan penghematan
  ///     yang tidak terukur.
  ///   - Aturan siapa melihat apa hidup di [Announcement.untuk], tempat ia
  ///     dapat diuji tanpa basis data. Menyalinnya menjadi string kueri berarti
  ///     aturannya ada di dua tempat, dan yang di server tidak pernah ikut
  ///     berubah saat yang di Dart diperbaiki.
  ///
  /// ⚠️ Pengumuman `important` sengaja **tidak** disaring oleh daftar
  /// penutupan: penutupannya memang tidak pernah dicatat (lihat [tutup]), dan
  /// membiarkannya lewat saringan ini adalah jaring kedua kalau suatu hari ada
  /// baris yang terlanjur tercatat lewat jalur lain.
  Future<Result<List<Announcement>>> fetchFor({
    required UserRole? role,
    required String userId,
  }) async {
    try {
      final rows = await _client
          .from(AppConstants.tblAnnouncements)
          .select()
          .eq('is_active', true);

      final ditutup = await _client
          .from(AppConstants.tblAnnouncementDismissals)
          .select('announcement_id')
          .eq('user_id', userId);

      final sudah = ditutup
          .map((r) => (r['announcement_id'] as String?) ?? '')
          .toSet();

      final daftar = rows
          .map(Announcement.fromJson)
          .where((a) => a.untuk(role))
          .where((a) => a.mengunci || !sudah.contains(a.id))
          .toList()
        ..sort(Announcement.urutkan);

      return Result.ok(List.unmodifiable(daftar));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Mencatat bahwa [userId] sudah menutup pengumuman [announcementId].
  ///
  /// 🔴 Hanya dipanggil untuk pengumuman `normal`. Yang `important` harus
  /// muncul lagi pada login berikutnya selama masih aktif — mencatat
  /// penutupannya berarti sekali lolos, selamanya lolos, dan orang yang
  /// memakai versi lama tidak akan pernah diminta memperbarui lagi.
  ///
  /// ⚠️ `upsert`, bukan `insert`. Menutup pengumuman yang sama dua kali —
  /// dari HP lalu dari web, atau karena ketukan ganda — adalah keadaan yang
  /// wajar, dan `insert` menjawabnya dengan galat pelanggaran primary key yang
  /// akan muncul sebagai pesan merah untuk sesuatu yang sudah berhasil.
  Future<Result<void>> tutup({
    required String announcementId,
    required String userId,
  }) async {
    try {
      await _client.from(AppConstants.tblAnnouncementDismissals).upsert({
        'announcement_id': announcementId,
        'user_id': userId,
      }, onConflict: 'announcement_id,user_id');
      return okVoid;
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }
}
