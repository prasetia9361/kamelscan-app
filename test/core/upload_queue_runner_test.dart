import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/models/enums.dart';
import 'package:kamelscan/core/models/package_video.dart';
import 'package:kamelscan/core/models/queue_summary.dart';
import 'package:kamelscan/core/models/upload_task.dart';
import 'package:kamelscan/core/repositories/video_repository.dart';
import 'package:kamelscan/core/services/connectivity_service.dart';
import 'package:kamelscan/core/services/local_db_service.dart';
import 'package:kamelscan/core/services/notification_service.dart';
import 'package:kamelscan/core/services/storage_service.dart';
import 'package:kamelscan/core/utils/app_failure.dart';
import 'package:kamelscan/core/utils/result.dart';
import 'package:kamelscan/core/workers/upload_queue_runner.dart';
import 'package:mocktail/mocktail.dart';

/// Aturan antrian unggah (Bab 8.7).
///
/// Dua hal yang paling mahal bila salah, dan karena itu diuji di sini:
/// **berkas lokal hanya boleh dihapus setelah server benar-benar mengakui**,
/// dan **kuota data packer tidak boleh terbakar tanpa izin**.
class _MockVideos extends Mock implements VideoRepository {}

class _MockStorage extends Mock implements StorageService {}

class _MockConnectivity extends Mock implements ConnectivityService {}

void main() {
  late Directory temp;
  late _MockVideos videos;
  late _MockStorage storage;
  late _MockConnectivity connectivity;
  late _FakeDb db;
  late _SpyNotifications notifications;

  final presigned = PresignedUpload(
    url: 'https://r2.example/upload',
    storageKey: 'tenant/t1/2026/08/video-1.mp4',
    expiresAt: DateTime.now().add(const Duration(minutes: 15)),
  );

  setUpAll(() {
    registerFallbackValue(
      UploadTask(
        videoId: 'x',
        tenantId: 't',
        shopId: 's',
        userId: 'u',
        resiCode: 'R',
        type: VideoType.packing,
        localPath: 'p',
        storageKey: 'k',
        createdAt: DateTime(2026),
      ),
    );
    registerFallbackValue(
      PresignedUpload(
        url: 'https://contoh',
        storageKey: 'k',
        expiresAt: DateTime(2026),
      ),
    );
  });

  setUp(() {
    temp = Directory.systemTemp.createTempSync('kamelscan_upload_test');
    videos = _MockVideos();
    storage = _MockStorage();
    connectivity = _MockConnectivity();
    notifications = _SpyNotifications();
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  File writeProcessed() =>
      File('${temp.path}/hasil.mp4')..writeAsBytesSync(List<int>.filled(64, 3));

  UploadTask taskFor(File file, {int attempts = 0}) => UploadTask(
        videoId: 'video-1',
        tenantId: 'tenant-1',
        shopId: 'shop-1',
        userId: 'user-1',
        resiCode: 'SPX123456789',
        type: VideoType.packing,
        localPath: file.path,
        storageKey: 'tenant/tenant-1/2026/08/video-1.mp4',
        createdAt: DateTime(2026, 8, 17),
        durationSeconds: 30,
        bytesTotal: 1200000,
        attempts: attempts,
      );

  PackageVideo rowFor(UploadTask task) => PackageVideo(
        id: task.videoId,
        tenantId: task.tenantId,
        shopId: task.shopId,
        userId: task.userId,
        resiCode: task.resiCode,
        type: task.type,
        scanDate: DateTime(2026, 8, 17),
        expiresAt: DateTime(2026, 9, 17),
        storageKey: task.storageKey,
      );

  UploadQueueRunner runnerWith({bool allowCellular = false}) =>
      UploadQueueRunner(
        db: db,
        storage: storage,
        videos: videos,
        connectivity: connectivity,
        notifications: notifications,
        allowCellular: () async => allowCellular,
      );

  void onWifi() {
    when(() => connectivity.isConnected).thenAnswer((_) async => true);
    when(() => connectivity.isMobileData).thenAnswer((_) async => false);
  }

  void onCellular() {
    when(() => connectivity.isConnected).thenAnswer((_) async => true);
    when(() => connectivity.isMobileData).thenAnswer((_) async => true);
  }

  void uploadSucceeds(UploadTask task) {
    when(() => videos.ensureVideoRow(any()))
        .thenAnswer((_) async => Result.ok(rowFor(task)));
    when(
      () => storage.requestUploadUrl(
        videoId: any(named: 'videoId'),
        storageKey: any(named: 'storageKey'),
        sizeBytes: any(named: 'sizeBytes'),
        contentType: any(named: 'contentType'),
      ),
    ).thenAnswer((_) async => Result.ok(presigned));
    when(
      () => storage.uploadFile(
        localPath: any(named: 'localPath'),
        target: any(named: 'target'),
        onProgress: any(named: 'onProgress'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => okVoid);
    when(
      () => videos.markUploaded(
        videoId: any(named: 'videoId'),
        storageKey: any(named: 'storageKey'),
        fileSizeBytes: any(named: 'fileSizeBytes'),
        durationSeconds: any(named: 'durationSeconds'),
      ),
    ).thenAnswer((_) async => okVoid);
  }

  group('jaringan (Bab 8.7 langkah 1)', () {
    test('tanpa jaringan sama sekali, antrian tidak disentuh', () async {
      when(() => connectivity.isConnected).thenAnswer((_) async => false);
      db = _FakeDb([taskFor(writeProcessed())]);

      final hasil = await runnerWith().run();

      expect(db.statusUpdates, isEmpty);
      verifyNever(() => videos.ensureVideoRow(any()));

      // 🔴 Alasannya WAJIB terbawa keluar. Sampai 3 September 2026 jalur ini
      // hanya `return` tanpa sepatah kata pun — layar tidak punya cara
      // membedakannya dari antrian kosong, dan tombol "Unggah sekarang"
      // karenanya terasa rusak.
      expect(hasil, UploadRunOutcome.tanpaJaringan);
    });

    test('🔴 hanya data seluler dan belum diizinkan → menunggu Wi-Fi', () async {
      onCellular();
      db = _FakeDb([taskFor(writeProcessed())]);

      final hasil = await runnerWith().run();

      expect(db.statusUpdates, isEmpty,
          reason: 'kuota data packer tidak boleh terbakar tanpa izin');
      verifyNever(() => videos.ensureVideoRow(any()));

      // Inilah satu-satunya keadaan yang boleh menyebut Wi-Fi. Kalimat itu
      // dulu ditulis mati di spanduk dan diucapkan untuk semua sebab.
      expect(hasil, UploadRunOutcome.menungguWifi);
    });

    test('data seluler yang sudah diizinkan tetap jalan', () async {
      onCellular();
      final file = writeProcessed();
      final task = taskFor(file);
      db = _FakeDb([task]);
      uploadSucceeds(task);

      final hasil = await runnerWith(allowCellular: true).run();

      expect(db.removed, contains('video-1'));
      expect(hasil, UploadRunOutcome.terunggah);
    });
  });

  // ==========================================================================
  // 🔴 run() melaporkan ALASAN, bukan diam
  // ==========================================================================
  //
  // Ditambahkan 3 September 2026. Product Owner melaporkan bahwa menekan
  // "Unggah sekarang" tidak menghasilkan apa pun di layar. Ternyata benar —
  // dan bukan karena tombolnya rusak: `run()` memang berhenti di salah satu
  // dari lima jalur, seluruhnya tanpa satu baris pun yang tembus ke logcat
  // (`AppLogger` memakai `dart:developer`, jebakan nomor 9).
  //
  // Butuh membaca `kamelscan_queue.sqlite` di perangkat untuk mengetahui
  // sebabnya. Itu bukan sesuatu yang boleh dituntut dari pengguna.
  group('🔴 alasan putaran antrian', () {
    test('antrian kosong dibedakan dari antrian yang tidak ada isinya siap',
        () async {
      onWifi();
      db = _FakeDb(const []);

      expect(await runnerWith().run(), UploadRunOutcome.kosong);
    });

    test('🔴 berisi tetapi tidak satu pun siap — BUKAN "kosong"', () async {
      onWifi();
      // Jatah percobaannya habis: penjalan antrian tidak akan pernah
      // menyentuhnya, tetapi barisnya tetap ada dan tetap terhitung di
      // spanduk. Inilah keadaan yang membuat tombolnya terasa mati.
      final task = taskFor(writeProcessed()).copyWith(attempts: 5);
      db = _FakeDb([task]);

      final hasil = await runnerWith().run();

      expect(hasil, UploadRunOutcome.tidakAdaYangSiap);
      expect(hasil, isNot(UploadRunOutcome.kosong),
          reason: 'membedakan keduanya adalah inti perbaikan ini');
      verifyNever(() => videos.ensureVideoRow(any()));
    });

    test('rekaman yang masih menunggu watermark tidak dianggap siap',
        () async {
      onWifi();
      final task = taskFor(writeProcessed())
          .copyWith(status: UploadTaskStatus.pendingProcess);
      db = _FakeDb([task]);

      expect(await runnerWith().run(), UploadRunOutcome.tidakAdaYangSiap);
      verifyNever(() => videos.ensureVideoRow(any()));
    });
  });

  group('unggah berhasil', () {
    test('🔴 berkas lokal baru dihapus SETELAH server mengakui', () async {
      onWifi();
      final file = writeProcessed();
      final task = taskFor(file);
      db = _FakeDb([task]);
      uploadSucceeds(task);

      await runnerWith().run();

      verify(
        () => videos.markUploaded(
          videoId: 'video-1',
          storageKey: presigned.storageKey,
          fileSizeBytes: 1200000,
          durationSeconds: 30,
        ),
      ).called(1);
      expect(file.existsSync(), isFalse);
      expect(db.removed, contains('video-1'));
    });

    test('penandaan gagal → berkas dan barisnya DIPERTAHANKAN', () async {
      // Video sudah ada di R2 tetapi belum tercatat. Mengulang unggahan jauh
      // lebih murah daripada video yang tidak pernah muncul di Riwayat.
      onWifi();
      final file = writeProcessed();
      final task = taskFor(file);
      db = _FakeDb([task]);
      uploadSucceeds(task);
      when(
        () => videos.markUploaded(
          videoId: any(named: 'videoId'),
          storageKey: any(named: 'storageKey'),
          fileSizeBytes: any(named: 'fileSizeBytes'),
          durationSeconds: any(named: 'durationSeconds'),
        ),
      ).thenAnswer((_) async => const Result.err(AppFailure.network));

      await runnerWith().run();

      expect(file.existsSync(), isTrue);
      expect(db.removed, isEmpty);
      expect(db.statusUpdates.last.status, UploadTaskStatus.queued);
    });
  });

  group('kegagalan', () {
    test('resi ganda ditandai duplicate, tidak diulang selamanya', () async {
      onWifi();
      final task = taskFor(writeProcessed());
      db = _FakeDb([task]);
      when(() => videos.ensureVideoRow(any()))
          .thenAnswer((_) async => const Result.err(AppFailure.resiDuplicate));

      await runnerWith().run();

      expect(db.statusUpdates.last.status, UploadTaskStatus.duplicate);
      expect(db.statusUpdates.last.incrementAttempts, isFalse);
    });

    test('🔴 kuota habis tidak menghabiskan jatah percobaan', () async {
      // Keadaan milik tenant, bukan kesalahan unggahan ini. Begitu Owner
      // mengisi token, videonya harus masih dapat terkirim.
      onWifi();
      final task = taskFor(writeProcessed());
      db = _FakeDb([task]);
      when(() => videos.ensureVideoRow(any()))
          .thenAnswer((_) async => const Result.err(AppFailure.tokenExhausted));

      await runnerWith().run();

      expect(db.statusUpdates.last.status, UploadTaskStatus.queued);
      expect(db.statusUpdates.last.incrementAttempts, isFalse);
      expect(db.statusUpdates.last.nextAttemptAt, isNotNull);
    });

    test('gagal jaringan → mundur dan dicoba lagi', () async {
      onWifi();
      final task = taskFor(writeProcessed());
      db = _FakeDb([task]);
      when(() => videos.ensureVideoRow(any()))
          .thenAnswer((_) async => Result.ok(rowFor(task)));
      when(
        () => storage.requestUploadUrl(
          videoId: any(named: 'videoId'),
          storageKey: any(named: 'storageKey'),
          sizeBytes: any(named: 'sizeBytes'),
          contentType: any(named: 'contentType'),
        ),
      ).thenAnswer((_) async => const Result.err(AppFailure.network));

      await runnerWith().run();

      expect(db.statusUpdates.last.status, UploadTaskStatus.queued);
      expect(db.statusUpdates.last.incrementAttempts, isTrue);
      expect(db.statusUpdates.last.nextAttemptAt, isNotNull);
    });

    test('percobaan kelima yang gagal berhenti dan memberi tahu', () async {
      onWifi();
      final file = writeProcessed();
      final task = taskFor(file, attempts: 4);
      db = _FakeDb([task]);
      when(() => videos.ensureVideoRow(any()))
          .thenAnswer((_) async => const Result.err(AppFailure.network));
      when(
        () => videos.recordUploadFailure(
          videoId: any(named: 'videoId'),
          attempts: any(named: 'attempts'),
          message: any(named: 'message'),
        ),
      ).thenAnswer((_) async => okVoid);

      await runnerWith().run();

      expect(db.statusUpdates.last.status, UploadTaskStatus.failed);
      expect(notifications.failedFor, 'SPX123456789');
      expect(file.existsSync(), isTrue,
          reason: 'tombol "Coba lagi" di Riwayat perlu berkasnya masih ada');
    });

    test('berkas yang sudah lenyap langsung gagal, tanpa menyentuh server',
        () async {
      onWifi();
      db = _FakeDb([taskFor(File('${temp.path}/tidak-ada.mp4'))]);

      await runnerWith().run();

      expect(db.statusUpdates.single.status, UploadTaskStatus.failed);
      verifyNever(() => videos.ensureVideoRow(any()));
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

class _FakeDb implements LocalDbService {
  _FakeDb(this._queue);

  final List<UploadTask> _queue;
  final List<_StatusUpdate> statusUpdates = [];
  final List<String> removed = [];

  @override
  bool get isSupported => true;

  @override
  Future<Result<List<UploadTask>>> pendingTasks({int limit = 10}) async =>
      Result.ok(_queue.take(limit).toList());

  @override
  Future<Result<void>> updateStatus(
    String videoId,
    UploadTaskStatus status, {
    String? lastError,
    DateTime? nextAttemptAt,
    bool incrementAttempts = false,
  }) async {
    // `running` hanyalah penanda sementara; yang menarik untuk diuji adalah
    // keputusan akhirnya.
    if (status != UploadTaskStatus.running) {
      statusUpdates.add(
        _StatusUpdate(status, incrementAttempts, nextAttemptAt),
      );
    }
    return okVoid;
  }

  @override
  Future<Result<void>> remove(String videoId) async {
    removed.add(videoId);
    return okVoid;
  }

  // ---- tidak dipakai penjalan unggah ----
  @override
  Future<void> init() async {}
  @override
  Future<void> close() async {}
  @override
  Future<Result<void>> enqueue(UploadTask task) async => okVoid;
  @override
  Future<Result<List<UploadTask>>> tasksToProcess({int limit = 5}) async =>
      const Result.ok([]);
  @override
  Future<Result<void>> markProcessed(
    String videoId, {
    required String localPath,
    required int bytesTotal,
    required int durationSeconds,
    String? thumbnailPath,
  }) async =>
      okVoid;
  @override
  Future<Result<List<UploadTask>>> allTasks() async => const Result.ok([]);
  @override
  Future<Result<UploadTask?>> findByVideoId(String videoId) async =>
      const Result.ok(null);
  @override
  Future<Result<void>> updateProgress(String videoId, int bytesSent) async =>
      okVoid;
  @override
  Stream<int> watchPendingCount() => Stream.value(0);

  @override
  Stream<QueueSummary> watchQueueSummary() =>
      Stream<QueueSummary>.value(const QueueSummary());
}

class _SpyNotifications implements NotificationService {
  String? failedFor;
  int? completedCount;

  @override
  bool get isSupported => true;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> showUploadProgress({
    required int pending,
    required int total,
  }) async {}

  @override
  Future<void> showUploadComplete({required int uploaded}) async {
    completedCount = uploaded;
  }

  @override
  Future<void> showUploadFailed({required String resiCode}) async {
    failedFor = resiCode;
  }

  @override
  Future<void> cancelAll() async {}
}
