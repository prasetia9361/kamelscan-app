import '../models/app_settings.dart';
import '../utils/result.dart';

// ⚠️ Bab 4.3 — `ffmpeg_kit_flutter_new` TIDAK berjalan di Flutter Web.
// Pemisahan ini dikerjakan sejak Minggu 1; menundanya sampai Minggu 5 akan
// membuat `flutter build web` gagal total saat waktu sudah menipis.
import 'video_processor_stub.dart'
    if (dart.library.io) 'video_processor_mobile.dart';

/// Data yang dibakar ke dalam watermark video (Bab 0.2 poin 6).
class WatermarkData {
  const WatermarkData({
    required this.resiCode,
    required this.serverTime,
    required this.shopName,
    required this.shopId,
    this.coordinates,
    this.lat,
    this.lng,
    this.logoPath,
    this.timeVerified = true,
  });

  final String resiCode;

  /// Waktu **server**, bukan waktu HP — jam perangkat dapat dipalsukan.
  final DateTime serverTime;
  final String shopName;

  /// Ditanam ke metadata berkas (Bab 8.5) agar asal video tetap dapat
  /// ditelusuri saat berkasnya beredar lepas dari aplikasi.
  final String shopId;

  /// `null` bila izin lokasi ditolak; ditampilkan sebagai
  /// "Lokasi tidak tersedia" (Bab 1.3 poin 6).
  final String? coordinates;

  /// Koordinat mentah untuk metadata. Yang tampil di layar tetap
  /// [coordinates] yang sudah diformat.
  final double? lat;
  final double? lng;

  /// Logo kustom, hanya tier Pro (Bab 2.2 catatan 4).
  final String? logoPath;

  /// `false` = [serverTime] sebenarnya berasal dari jam HP, karena aplikasi
  /// belum pernah berhasil menanyakan waktu server (Bab 8.5 aturan 4).
  ///
  /// 🔴 Videonya tetap direkam — bukti dengan waktu yang mungkin meleset jauh
  /// lebih berharga daripada tidak ada bukti. Tetapi keterangannya ikut
  /// dibakar ke gambar dan ke metadata berkas, supaya orang yang membacanya
  /// saat sengketa tahu persis seberapa jauh jam itu boleh dipercaya.
  final bool timeVerified;
}

/// Hasil pemrosesan video.
class ProcessedVideo {
  const ProcessedVideo({
    required this.path,
    required this.sizeBytes,
    required this.durationSeconds,
    this.thumbnailPath,
  });

  final String path;
  final int sizeBytes;
  final int durationSeconds;
  final String? thumbnailPath;
}

/// Antarmuka pemroses video: watermark, kompresi, thumbnail.
///
/// Spesifikasi lengkap pipeline ada di **Bab 8**. Kelas ini hanya menetapkan
/// kontraknya agar pemisahan platform sudah benar sejak awal.
abstract interface class VideoProcessor {
  /// `true` di Android/iOS, `false` di Web. Layar yang memerlukan pemrosesan
  /// wajib memeriksa ini sebelum memanggil metode lain.
  bool get isSupported;

  /// Bakar watermark metadata ke dalam video dan kompres ke 480p.
  Future<Result<ProcessedVideo>> applyWatermark({
    required String inputPath,
    required String outputPath,
    required WatermarkData data,
    required TenantSettings settings,
  });

  /// Ambil satu bingkai untuk thumbnail riwayat.
  Future<Result<String>> generateThumbnail({
    required String videoPath,
    required String outputPath,
  });

  /// Batalkan seluruh pekerjaan yang sedang berjalan.
  Future<void> cancelAll();
}

/// Pabrik lintas platform. Web mendapat implementasi stub yang jujur menolak.
VideoProcessor createVideoProcessor() => createPlatformVideoProcessor();
