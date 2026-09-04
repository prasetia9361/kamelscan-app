import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/models/app_settings.dart';
import 'package:kamelscan/core/models/enums.dart';
import 'package:kamelscan/core/models/queue_summary.dart';
import 'package:kamelscan/core/models/upload_task.dart';
import 'package:kamelscan/core/services/local_db_service.dart';
import 'package:kamelscan/core/services/video_processor.dart';
import 'package:kamelscan/core/utils/app_failure.dart';
import 'package:kamelscan/core/utils/result.dart';
import 'package:kamelscan/core/workers/video_processing_queue.dart';

/// Aturan antrean watermark (Bab 8.5).
///
/// Yang dijaga di sini adalah janji yang paling mahal bila dilanggar: **berkas
/// mentah tidak boleh hilang sebelum penggantinya aman**, dan **FFmpeg tidak
/// boleh berjalan selagi merekam**.
void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('kamelscan_queue_test');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  File writeRaw(String name, {int sizeBytes = 1024}) {
    final file = File('${temp.path}/$name')
      ..writeAsBytesSync(List<int>.filled(sizeBytes, 7));
    return file;
  }

  UploadTask taskFor(File raw) => UploadTask(
        videoId: 'video-1',
        tenantId: 'tenant-1',
        shopId: 'shop-1',
        userId: 'user-1',
        resiCode: 'SPX123456789',
        type: VideoType.packing,
        localPath: raw.path,
        storageKey: 'tenant/tenant-1/2026/08/video-1.mp4',
        createdAt: DateTime(2026, 8, 17, 10),
        status: UploadTaskStatus.pendingProcess,
        shopName: 'Shopee · Toko Kamel',
        scanTime: DateTime.utc(2026, 8, 17, 3),
        durationSeconds: 30,
        bytesTotal: 16000000,
      );

  VideoProcessingQueue queueFor(
    _FakeDb db,
    VideoProcessor processor, {
    Future<void> Function()? onProcessed,
  }) =>
      VideoProcessingQueue(
        db: db,
        processor: processor,
        settings: () async => const TenantSettings(tenantId: 'tenant-1'),
        onProcessed: onProcessed,
        outputDirectory: () async => Directory('${temp.path}/hasil'),
      );

  /// Menunggu antrean selesai; [kick] sengaja tidak mengembalikan Future agar
  /// pemanggilnya (layar rekam) tidak pernah ikut menunggu FFmpeg.
  Future<void> settle(VideoProcessingQueue queue) async {
    for (var i = 0; i < 200 && queue.isBusy; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  group('watermark berhasil', () {
    test('🔴 berkas mentah dihapus, hasilnya tercatat di antrian', () async {
      final raw = writeRaw('mentah.mp4');
      final db = _FakeDb([taskFor(raw)]);
      final queue = queueFor(db, _OkProcessor(sizeBytes: 1100000));

      queue.kick();
      await settle(queue);

      expect(db.processed, hasLength(1));
      expect(db.processed.single.videoId, 'video-1');
      expect(db.processed.single.bytesTotal, 1100000);
      expect(File(db.processed.single.localPath).existsSync(), isTrue,
          reason: 'berkas hasil proses harus ada di disk');
      expect(raw.existsSync(), isFalse,
          reason: 'rekaman mentah ± 370–500 KB/detik tidak boleh menumpuk');
    });

    test('antrian unggah dibangunkan setelah selesai', () async {
      final db = _FakeDb([taskFor(writeRaw('mentah.mp4'))]);
      var woken = 0;
      final queue = queueFor(
        db,
        _OkProcessor(),
        onProcessed: () async => woken++,
      );

      queue.kick();
      await settle(queue);

      expect(woken, 1);
    });

    test('antrean mengerjakan seluruh isinya, satu per satu', () async {
      final db = _FakeDb([
        taskFor(writeRaw('satu.mp4')),
        taskFor(writeRaw('dua.mp4')).copyWith(videoId: 'video-2'),
      ]);
      final processor = _OkProcessor();
      final queue = queueFor(db, processor);

      queue.kick();
      await settle(queue);

      expect(db.processed, hasLength(2));
      expect(processor.maxConcurrent, 1,
          reason: 'dua FFmpeg bersamaan membuat pratinjau patah-patah '
              '(DEVIASI_LIBRARY.md bagian J)');
    });
  });

  group('watermark gagal', () {
    test('🔴 berkas mentah TIDAK dihapus, dan dijadwalkan diulang', () async {
      final raw = writeRaw('mentah.mp4');
      final db = _FakeDb([taskFor(raw)]);
      final queue = queueFor(db, _FailingProcessor());

      queue.kick();
      await settle(queue);

      expect(raw.existsSync(), isTrue,
          reason: 'selama berkas mentah ada, buktinya masih bisa diselamatkan');
      expect(db.processed, isEmpty);
      expect(db.statusUpdates.single.status, UploadTaskStatus.pendingProcess);
      expect(db.statusUpdates.single.incrementAttempts, isTrue);
      expect(db.statusUpdates.single.nextAttemptAt, isNotNull);
    });

    test('setelah percobaan kelima menyerah dan menunggu pengguna', () async {
      final raw = writeRaw('mentah.mp4');
      final db = _FakeDb([taskFor(raw).copyWith(attempts: 4)]);
      final queue = queueFor(db, _FailingProcessor());

      queue.kick();
      await settle(queue);

      expect(db.statusUpdates.single.status, UploadTaskStatus.failed);
      expect(raw.existsSync(), isTrue,
          reason: 'tombol "Coba lagi" di Riwayat perlu berkasnya masih ada');
    });

    test('berkas mentah yang sudah lenyap tidak diulang selamanya', () async {
      // Terjadi setelah aplikasi dipasang ulang: cache aplikasi ikut terhapus.
      final db = _FakeDb([
        taskFor(File('${temp.path}/tidak-ada.mp4')),
      ]);
      final queue = queueFor(db, _OkProcessor());

      queue.kick();
      await settle(queue);

      expect(db.statusUpdates.single.status, UploadTaskStatus.failed);
      expect(db.statusUpdates.single.nextAttemptAt, isNull,
          reason: 'tidak ada gunanya menjadwalkan ulang berkas yang hilang');
    });
  });

  group('FFmpeg minggir saat merekam', () {
    test('🔴 pembatalan karena merekam bukan kegagalan — jatah percobaan '
        'tidak berkurang', () async {
      final raw = writeRaw('mentah.mp4');
      final db = _FakeDb([taskFor(raw)]);
      final processor = _PausableProcessor();
      final queue = queueFor(db, processor);

      queue.kick();
      await processor.started.future;
      await queue.pause();
      await settle(queue);

      expect(db.statusUpdates, isEmpty,
          reason: 'packer yang memindai paket berikutnya tidak boleh membuat '
              'video sebelumnya dianggap gagal');
      expect(db.processed, isEmpty);
      expect(raw.existsSync(), isTrue);
    });

    test('tidak mengambil pekerjaan baru selama dijeda', () async {
      final db = _FakeDb([taskFor(writeRaw('mentah.mp4'))]);
      final queue = queueFor(db, _OkProcessor());

      await queue.pause();
      queue.kick();
      await settle(queue);

      expect(db.processed, isEmpty);

      queue.resume();
      await settle(queue);

      expect(db.processed, hasLength(1),
          reason: 'jeda antar-paket adalah waktunya bekerja');
    });
  });
}

// ---------------------------------------------------------------------------
// Ganda
// ---------------------------------------------------------------------------

class _StatusUpdate {
  _StatusUpdate(this.status, this.incrementAttempts, this.nextAttemptAt);

  final UploadTaskStatus status;
  final bool incrementAttempts;
  final DateTime? nextAttemptAt;
}

class _Processed {
  _Processed(this.videoId, this.localPath, this.bytesTotal);

  final String videoId;
  final String localPath;
  final int bytesTotal;
}

class _FakeDb implements LocalDbService {
  _FakeDb(this._queue);

  final List<UploadTask> _queue;
  final List<_StatusUpdate> statusUpdates = [];
  final List<_Processed> processed = [];

  @override
  bool get isSupported => true;

  @override
  Future<Result<List<UploadTask>>> tasksToProcess({int limit = 5}) async =>
      Result.ok(_queue.take(limit).toList());

  @override
  Future<Result<void>> markProcessed(
    String videoId, {
    required String localPath,
    required int bytesTotal,
    required int durationSeconds,
    String? thumbnailPath,
  }) async {
    processed.add(_Processed(videoId, localPath, bytesTotal));
    _queue.removeWhere((t) => t.videoId == videoId);
    return okVoid;
  }

  @override
  Future<Result<void>> updateStatus(
    String videoId,
    UploadTaskStatus status, {
    String? lastError,
    DateTime? nextAttemptAt,
    bool incrementAttempts = false,
  }) async {
    statusUpdates.add(_StatusUpdate(status, incrementAttempts, nextAttemptAt));
    _queue.removeWhere((t) => t.videoId == videoId);
    return okVoid;
  }

  // ---- tidak dipakai antrean watermark ----
  @override
  Future<void> init() async {}
  @override
  Future<void> close() async {}
  @override
  Future<Result<void>> enqueue(UploadTask task) async => okVoid;
  @override
  Future<Result<List<UploadTask>>> pendingTasks({int limit = 10}) async =>
      const Result.ok([]);
  @override
  Future<Result<List<UploadTask>>> allTasks() async => const Result.ok([]);
  @override
  Future<Result<UploadTask?>> findByVideoId(String videoId) async =>
      const Result.ok(null);
  @override
  Future<Result<void>> updateProgress(String videoId, int bytesSent) async =>
      okVoid;
  @override
  Future<Result<void>> remove(String videoId) async => okVoid;
  @override
  Stream<int> watchPendingCount() => Stream.value(0);

  @override
  Stream<QueueSummary> watchQueueSummary() =>
      Stream<QueueSummary>.value(const QueueSummary());
}

class _OkProcessor implements VideoProcessor {
  _OkProcessor({this.sizeBytes = 1200000});

  final int sizeBytes;
  int _running = 0;
  int maxConcurrent = 0;

  @override
  bool get isSupported => true;

  @override
  Future<Result<ProcessedVideo>> applyWatermark({
    required String inputPath,
    required String outputPath,
    required WatermarkData data,
    required TenantSettings settings,
  }) async {
    _running++;
    maxConcurrent = _running > maxConcurrent ? _running : maxConcurrent;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    // FFmpeg sungguhan menulis berkasnya; tiruan ini pun harus, karena antrean
    // hanya boleh menghapus yang mentah setelah penggantinya benar-benar ada.
    File(outputPath).writeAsBytesSync(List<int>.filled(16, 1));
    _running--;
    return Result.ok(
      ProcessedVideo(path: outputPath, sizeBytes: sizeBytes, durationSeconds: 30),
    );
  }

  @override
  Future<Result<String>> generateThumbnail({
    required String videoPath,
    required String outputPath,
  }) async =>
      Result.ok(outputPath);

  @override
  Future<void> cancelAll() async {}
}

class _FailingProcessor implements VideoProcessor {
  @override
  bool get isSupported => true;

  @override
  Future<Result<ProcessedVideo>> applyWatermark({
    required String inputPath,
    required String outputPath,
    required WatermarkData data,
    required TenantSettings settings,
  }) async =>
      Result.err(AppFailure.storage('FFmpeg keluar dengan kode 1'));

  @override
  Future<Result<String>> generateThumbnail({
    required String videoPath,
    required String outputPath,
  }) async =>
      Result.err(AppFailure.storage('tidak dipakai'));

  @override
  Future<void> cancelAll() async {}
}

/// Meniru FFmpeg yang sedang berjalan lalu dibatalkan `cancelAll`.
class _PausableProcessor implements VideoProcessor {
  final Completer<void> started = Completer<void>();
  final Completer<void> _cancelled = Completer<void>();

  @override
  bool get isSupported => true;

  @override
  Future<Result<ProcessedVideo>> applyWatermark({
    required String inputPath,
    required String outputPath,
    required WatermarkData data,
    required TenantSettings settings,
  }) async {
    if (!started.isCompleted) started.complete();
    await _cancelled.future;
    return Result.err(AppFailure.storage('FFmpeg dibatalkan'));
  }

  @override
  Future<Result<String>> generateThumbnail({
    required String videoPath,
    required String outputPath,
  }) async =>
      Result.err(AppFailure.storage('tidak dipakai'));

  @override
  Future<void> cancelAll() async {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}
