import '../utils/result.dart';

/// Akses object storage Cloudflare R2 (Bab 4.1).
///
/// 🔴 Aplikasi Flutter **tidak pernah** memegang kredensial R2. Setiap unggahan
/// memakai *presigned URL* berumur pendek yang diterbitkan Edge Function
/// `get-upload-url`, dan setiap pemutaran memakai URL bertanda tangan dari
/// `get-video-url`. Access key R2 hidup di Edge Function secrets (Bab 4.4).
///
/// Rincian pipeline unggah (multipart, retry, hapus berkas lokal) ada di
/// **Bab 8**; kontrak minimalnya sudah dikunci di sini.
abstract interface class StorageService {
  /// Minta presigned PUT URL untuk satu video.
  Future<Result<PresignedUpload>> requestUploadUrl({
    required String videoId,
    required String storageKey,
    required int sizeBytes,
    required String contentType,
  });

  /// Unggah berkas dengan progres dan kemampuan dibatalkan.
  Future<Result<void>> uploadFile({
    required String localPath,
    required PresignedUpload target,
    void Function(int sent, int total)? onProgress,
    String? cancelToken,
  });

  /// URL bertanda tangan untuk menonton/mengunduh.
  ///
  /// ⚠️ Bab 2.2 catatan 5 — Edge Function menolak pemanggil dengan
  /// `app_role = 'admin'`. Admin hanya boleh melihat metadata, tidak isinya.
  Future<Result<String>> getPlaybackUrl(String videoId);

  /// Batalkan unggahan yang sedang berjalan.
  Future<void> cancelUpload(String cancelToken);
}

/// Jawaban Edge Function `get-upload-url`.
class PresignedUpload {
  const PresignedUpload({
    required this.url,
    required this.storageKey,
    required this.expiresAt,
    this.headers = const {},
  });

  final String url;
  final String storageKey;
  final DateTime expiresAt;
  final Map<String, String> headers;

  bool isExpired({DateTime? now}) =>
      !expiresAt.isAfter(now ?? DateTime.now());
}

/// Susun kunci objek R2: `tenant/{tenantId}/{yyyy}/{MM}/{videoId}.mp4`
/// (format ditetapkan di Bab 5.2 kolom `storage_key`).
String buildStorageKey({
  required String tenantId,
  required String videoId,
  required DateTime scanDate,
  String extension = 'mp4',
}) {
  final d = scanDate.toUtc();
  final month = d.month.toString().padLeft(2, '0');
  return 'tenant/$tenantId/${d.year}/$month/$videoId.$extension';
}
