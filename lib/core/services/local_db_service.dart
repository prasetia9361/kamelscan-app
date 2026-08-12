import '../models/enums.dart';
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

  /// Tugas yang siap dikerjakan sekarang, terurut dari yang tertua.
  Future<Result<List<UploadTask>>> pendingTasks({int limit = 10});

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

  /// Jumlah tugas yang belum selesai — dipakai lencana di Beranda.
  Stream<int> watchPendingCount();
}

LocalDbService createLocalDbService() => createPlatformLocalDbService();
