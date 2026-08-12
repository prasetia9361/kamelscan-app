import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'package_video.freezed.dart';
part 'package_video.g.dart';

/// Tabel inti — satu baris = satu sesi rekam (`public.package_videos`, Bab 5.2).
@freezed
abstract class PackageVideo with _$PackageVideo {
  const factory PackageVideo({
    required String id,
    required String tenantId,
    required String shopId,
    required String userId,
    required String resiCode,
    required VideoType type,

    /// Waktu **server** saat baris dibuat — bukan waktu HP (Bab 5.2).
    required DateTime scanDate,

    /// Waktu hapus otomatis sesuai retensi tier.
    required DateTime expiresAt,

    @Default(VideoStatus.pendingUpload) VideoStatus status,

    /// Waktu HP, hanya untuk audit selisih jam perangkat.
    DateTime? deviceStartedAt,
    int? durationSeconds,
    int? fileSizeBytes,

    double? locationLat,
    double? locationLng,
    double? locationAccuracyM,

    /// Kunci objek di R2: `tenant/{tenant_id}/2026/08/{id}.mp4`.
    String? storageKey,
    String? thumbnailKey,

    /// Diisi hanya saat Owner menekan "Bagikan".
    String? publicToken,
    DateTime? publicExpiresAt,

    DateTime? uploadedAt,
    @Default(0) int uploadAttempts,
    String? lastError,

    String? deviceModel,
    String? appVersion,
    DateTime? createdAt,
  }) = _PackageVideo;

  const PackageVideo._();

  factory PackageVideo.fromJson(Map<String, dynamic> json) =>
      _$PackageVideoFromJson(json);

  bool get isUploaded => status == VideoStatus.uploaded;
  bool get isPending => status == VideoStatus.pendingUpload;
  bool get isFailed => status == VideoStatus.failed;
  bool get hasPublicLink => publicToken != null;

  /// Bab 1.3 poin 6 — izin lokasi boleh ditolak; video tetap sah.
  bool get hasLocation => locationLat != null && locationLng != null;

  /// Sisa hari sebelum video dihapus otomatis. Negatif berarti sudah lewat.
  int daysUntilExpiry({DateTime? now}) =>
      expiresAt.difference(now ?? DateTime.now()).inDays;

  bool isExpired({DateTime? now}) =>
      expiresAt.isBefore(now ?? DateTime.now()) ||
      status == VideoStatus.expired;

  /// Bab 0.3 — tautan publik mengikuti retensi video.
  bool isPublicLinkActive({DateTime? now}) {
    final exp = publicExpiresAt;
    if (publicToken == null || exp == null) return false;
    return exp.isAfter(now ?? DateTime.now());
  }

  Duration? get duration =>
      durationSeconds == null ? null : Duration(seconds: durationSeconds!);
}
