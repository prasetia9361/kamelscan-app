import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/quota_status.dart';

part 'home_stats.freezed.dart';
part 'home_stats.g.dart';

/// Isi kartu monitoring Beranda — hasil RPC `get_home_stats()` (Bab 9.2).
///
/// Satu panggilan mengisi seluruh kartu sekaligus. Menghitungnya di Flutter
/// ditolak karena alasan yang sama dengan Bab 7.3: angka yang dihitung di
/// perangkat akan salah begitu dua packer bekerja bersamaan.
///
/// ⚠️ Cakupannya ditentukan RLS, bukan oleh kode ini. Packer yang belum
/// diizinkan Owner melihat riwayat se-toko hanya menghitung rekamannya sendiri
/// (Bab 2.2 catatan 3) — sudah dibuktikan dengan JWT sungguhan 18 Agustus 2026,
/// hasilnya ada di `supabase/README.md`.
@freezed
abstract class HomeStats with _$HomeStats {
  const factory HomeStats({
    /// Awal periode yang sedang dihitung.
    ///
    /// 🔴 Berasal dari `token_wallets.period_start`, **bukan** awal bulan
    /// kalender — keputusan Product Owner 18 Agustus 2026 agar angka video
    /// selalu sejalan dengan sisa token. Selama uji coba, jatah 100 video tidak
    /// pernah di-reset, sehingga cara bulan kalender akan menampilkan "0 video"
    /// di sebelah "27 token terpakai".
    ///
    /// Ikut dikirim agar kartu dapat menulis keterangan yang jujur
    /// ("sejak 13 Agu") alih-alih kata "bulan ini" yang belum tentu benar.
    required DateTime periodStart,

    @Default(0) int packingCount,
    @Default(0) int returnCount,

    /// Baris `package_videos` yang tersangkut di server.
    ///
    /// ⚠️ **Bukan** ukuran antrian di perangkat, dan sengaja tidak dipakai
    /// untuk spanduk "menunggu Wi-Fi". Bab 8.7 / `DEVIASI_LIBRARY.md` L.5:
    /// baris `package_videos` baru dibuat **saat mengunggah**, jadi video yang
    /// direkam di gudang tanpa sinyal belum punya baris di sini sama sekali —
    /// justru video yang paling perlu diberitahukan. Sumber yang benar untuk
    /// spanduk itu `pendingUploadCountProvider`, yang membaca antrian lokal.
    @Default(0) int pendingUpload,

    /// Video yang sudah menghabiskan 5 percobaan unggah (Bab 8.7 langkah 6).
    /// Ini yang layak ditawarkan *Coba unggah lagi* di Riwayat.
    @Default(0) int failedUpload,

    /// null bila dompetnya belum terbentuk — **bukan** 0. Dua keadaan yang
    /// berbeda: kartu yang menampilkan 0 pada keadaan pertama akan menyuruh
    /// Owner membeli token yang sebenarnya sudah ia punya.
    int? tokenBalance,
    int? tokenQuota,
  }) = _HomeStats;

  const HomeStats._();

  factory HomeStats.fromJson(Map<String, dynamic> json) =>
      _$HomeStatsFromJson(json);

  int get totalVideos => packingCount + returnCount;

  bool get hasFailedUploads => failedUpload > 0;

  /// Belum ada satu pun rekaman pada periode ini — kondisi "kosong" Bab 3.4.
  bool get isEmpty => totalVideos == 0;

  /// Dibentuk di sini, bukan di widget, agar ambang warna dan spanduk tetap
  /// datang dari [QuotaStatus] yang sudah teruji tanpa perangkat (Bab 7.3).
  QuotaStatus quota({required bool isTrial}) => QuotaStatus(
        balance: tokenBalance ?? 0,
        quota: tokenQuota ?? 0,
        isTrial: isTrial,
      );
}
