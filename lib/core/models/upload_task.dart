import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'upload_task.freezed.dart';
part 'upload_task.g.dart';

/// Satu berkas video di HP yang menunggu diunggah.
///
/// Ini **model lokal** (tabel SQLite `upload_queue`), bukan tabel Supabase.
/// Sumber kebenarannya ada di perangkat sampai unggahan berhasil — inilah inti
/// pendekatan offline-first di Bab 8.
@freezed
abstract class UploadTask with _$UploadTask {
  const factory UploadTask({
    /// Sama dengan `package_videos.id` agar mudah dicocokkan setelah sinkron.
    required String videoId,
    required String tenantId,
    required String shopId,
    required String userId,
    required String resiCode,
    required VideoType type,

    /// Berkas yang berlaku **sekarang**.
    ///
    /// Selama [status] masih `pendingProcess` ini adalah rekaman mentah dari
    /// kamera; setelah watermark ditempelkan ia berganti menjadi hasil
    /// prosesnya, dan yang mentah dihapus. Satu kolom, bukan dua, agar tidak
    /// pernah ada keraguan berkas mana yang akan diunggah.
    ///
    /// Dihapus setelah unggah sukses (Bab 0.2 poin 7).
    required String localPath,

    /// Kunci tujuan di R2.
    required String storageKey,
    required DateTime createdAt,

    /// Nama toko **saat direkam**, untuk teks watermark.
    ///
    /// Disimpan, bukan diambil ulang saat memproses. Dua alasan: gudang sering
    /// tanpa sinyal sehingga nama toko tidak dapat ditanyakan ke server, dan
    /// bila Owner mengganti nama tokonya bulan depan, video ini tetap harus
    /// menunjukkan nama yang berlaku pada hari kejadian.
    @Default('') String shopName,

    /// Waktu yang dibakar ke watermark — hasil koreksi [ServerClock], bukan
    /// jam HP. Dipakai lagi saat menyusun kunci objek R2.
    DateTime? scanTime,

    /// `false` = aplikasi belum pernah menyinkronkan waktu server, sehingga
    /// jam pada watermark berasal dari jam HP apa adanya (Bab 8.5 aturan 4).
    /// Ikut ke kolom `package_videos.time_verified`.
    @Default(true) bool timeVerified,

    /// Waktu mulai rekam menurut jam HP. Hanya untuk audit selisih jam
    /// (`package_videos.device_started_at`), tidak pernah dipakai berhitung.
    DateTime? deviceStartedAt,
    @Default(0) int durationSeconds,

    /// Koordinat saat merekam. `null` bila izin lokasi ditolak — video tetap
    /// sah (Bab 1.3 poin 6).
    double? lat,
    double? lng,
    double? locationAccuracyM,

    @Default(UploadTaskStatus.queued) UploadTaskStatus status,
    @Default(0) int attempts,
    @Default(0) int bytesTotal,
    @Default(0) int bytesSent,
    String? thumbnailPath,
    String? lastError,
    DateTime? nextAttemptAt,
  }) = _UploadTask;

  const UploadTask._();

  factory UploadTask.fromJson(Map<String, dynamic> json) =>
      _$UploadTaskFromJson(json);

  double get progress =>
      bytesTotal <= 0 ? 0 : (bytesSent / bytesTotal).clamp(0.0, 1.0);

  bool get isTerminal =>
      status == UploadTaskStatus.done || status == UploadTaskStatus.duplicate;

  /// Masih menunggu watermark (Bab 8.5) — berkasnya belum layak diunggah.
  bool get needsProcessing => status == UploadTaskStatus.pendingProcess;

  /// Bab 7.7 — resi ganda tidak boleh diulang terus-menerus; ia menunggu
  /// tindakan pengguna (*Hapus dari antrian*).
  bool get needsUserAction => status == UploadTaskStatus.duplicate;

  bool isReady({DateTime? now, int maxAttempts = 5}) {
    if (isTerminal || status == UploadTaskStatus.paused) return false;
    // 🔴 Rekaman mentah tidak pernah diunggah — lihat [localPath].
    if (needsProcessing) return false;
    if (attempts >= maxAttempts) return false;
    final next = nextAttemptAt;
    if (next == null) return true;
    return !next.isAfter(now ?? DateTime.now());
  }

  /// Backoff eksponensial dengan batas atas 30 menit.
  Duration get retryDelay {
    final seconds = 30 * (1 << attempts.clamp(0, 6));
    return Duration(seconds: seconds.clamp(30, 1800));
  }
}
