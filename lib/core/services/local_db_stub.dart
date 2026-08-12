import '../models/enums.dart';
import '../models/upload_task.dart';
import '../utils/app_failure.dart';
import '../utils/result.dart';
import 'local_db_service.dart';

/// Implementasi Web: antrian selalu kosong, karena web tidak merekam
/// (Bab 1.3 poin 5). Semua operasi tulis ditolak dengan sopan agar bug
/// pemanggilan terdeteksi cepat, bukan diam-diam hilang.
class WebLocalDbService implements LocalDbService {
  const WebLocalDbService();

  static const AppFailure _unsupported = AppFailure(
    kind: FailureKind.unknown,
    messageKey: 'webRecordingUnavailable',
    debugMessage: 'Antrian upload lokal tidak tersedia di Flutter Web.',
  );

  @override
  bool get isSupported => false;

  @override
  Future<void> init() async {}

  @override
  Future<void> close() async {}

  @override
  Future<Result<void>> enqueue(UploadTask task) async =>
      const Result.err(_unsupported);

  @override
  Future<Result<List<UploadTask>>> pendingTasks({int limit = 10}) async =>
      const Result.ok(<UploadTask>[]);

  @override
  Future<Result<List<UploadTask>>> allTasks() async =>
      const Result.ok(<UploadTask>[]);

  @override
  Future<Result<UploadTask?>> findByVideoId(String videoId) async =>
      const Result.ok(null);

  @override
  Future<Result<void>> updateStatus(
    String videoId,
    UploadTaskStatus status, {
    String? lastError,
    DateTime? nextAttemptAt,
    bool incrementAttempts = false,
  }) async =>
      const Result.err(_unsupported);

  @override
  Future<Result<void>> updateProgress(String videoId, int bytesSent) async =>
      const Result.err(_unsupported);

  @override
  Future<Result<void>> remove(String videoId) async =>
      const Result.err(_unsupported);

  @override
  Stream<int> watchPendingCount() => Stream<int>.value(0);
}

LocalDbService createPlatformLocalDbService() => const WebLocalDbService();
