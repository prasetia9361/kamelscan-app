import '../models/enums.dart';
import '../models/queue_summary.dart';
import '../models/upload_task.dart';
import '../utils/result.dart';

// ⚠️ Bab 4.3 — `drift` (native SQLite) tidak berjalan di Flutter Web tanpa
// worker WASM. Karena web tidak merekam, web memakai implementasi kosong.
import 'local_db_stub.dart' if (dart.library.io) 'local_db_mobile.dart';

/// Antrian upload lokal — tabel SQLite `upload_queue` (Bab 1.2 / Bab 8).
///
/// Ini satu-satunya sumber kebenaran video yang belum terkirim. Berkas fisik
/// baru boleh dihapus setelah server mengonfirmasi unggahan berhasil
/// (Bab 0.2 poin 7).
abstract interface class LocalDbService {
  bool get isSupported;

  Future<void> init();
  Future<void> close();

  Future<Result<void>> enqueue(UploadTask task);

  /// Tugas yang siap **diunggah** sekarang, terurut dari yang tertua.
  ///
  /// Rekaman yang watermark-nya belum ditempelkan tidak pernah ikut di sini
  /// (lihat [UploadTask.needsProcessing]).
  Future<Result<List<UploadTask>>> pendingTasks({int limit = 10});

  /// Rekaman mentah yang menunggu watermark (Bab 8.5), tertua lebih dulu.
  Future<Result<List<UploadTask>>> tasksToProcess({int limit = 5});

  /// Watermark selesai: berkas mentah berganti menjadi hasil prosesnya dan
  /// barisnya naik ke antrian unggah.
  Future<Result<void>> markProcessed(
    String videoId, {
    required String localPath,
    required int bytesTotal,
    required int durationSeconds,
    String? thumbnailPath,
  });

  Future<Result<List<UploadTask>>> allTasks();

  Future<Result<UploadTask?>> findByVideoId(String videoId);

  Future<Result<void>> updateStatus(
    String videoId,
    UploadTaskStatus status, {
    String? lastError,
    DateTime? nextAttemptAt,
    bool incrementAttempts = false,
  });

  Future<Result<void>> updateProgress(String videoId, int bytesSent);

  Future<Result<void>> remove(String videoId);

  /// Jumlah tugas yang belum selesai — dipakai lencana di Beranda dan
  /// peringatan saat keluar.
  ///
  /// Sama dengan `watchQueueSummary().total`; dipertahankan karena kedua
  /// tempat itu memang hanya menanyakan *"ada berapa yang belum terkirim"*.
  Stream<int> watchPendingCount();

  /// Antrian dipecah menurut **apa yang menahannya** (Bab 8.7).
  ///
  /// 🔴 Dipakai spanduk Beranda supaya kalimatnya menyebutkan sebab yang
  /// sebenarnya. Sampai 3 September 2026 kalimat itu ditulis mati
  /// *"menunggu Wi-Fi"* dan diucapkan bahkan ketika yang menahan adalah
  /// watermark yang gagal — uraiannya di [QueueSummary].
  Stream<QueueSummary> watchQueueSummary();
}

LocalDbService createLocalDbService() => createPlatformLocalDbService();
