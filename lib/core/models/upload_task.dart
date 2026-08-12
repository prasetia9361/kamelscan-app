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

    /// Lokasi berkas di penyimpanan aplikasi. Dihapus setelah unggah sukses
    /// (Bab 0.2 poin 7).
    required String localPath,

    /// Kunci tujuan di R2.
    required String storageKey,
    required DateTime createdAt,

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

  /// Bab 7.7 — resi ganda tidak boleh diulang terus-menerus; ia menunggu
  /// tindakan pengguna (*Hapus dari antrian*).
  bool get needsUserAction => status == UploadTaskStatus.duplicate;

  bool isReady({DateTime? now, int maxAttempts = 5}) {
    if (isTerminal || status == UploadTaskStatus.paused) return false;
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
