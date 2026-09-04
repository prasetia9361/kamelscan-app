import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../config/app_constants.dart';
import '../models/enums.dart';
import '../models/queue_summary.dart';
import '../models/upload_task.dart';
import '../utils/app_failure.dart';
import '../utils/logger.dart';
import '../utils/result.dart';
import 'local_db_service.dart';

part 'local_db_mobile.g.dart';

/// Tabel antrian upload di perangkat.
///
/// `videoId` sengaja dipakai sebagai primary key dan bernilai sama dengan
/// `package_videos.id`, sehingga baris lokal dan baris server selalu dapat
/// dicocokkan tanpa tabel pemetaan tambahan.
class UploadQueue extends Table {
  TextColumn get videoId => text()();
  TextColumn get tenantId => text()();
  TextColumn get shopId => text()();
  TextColumn get userId => text()();
  TextColumn get resiCode => text()();
  TextColumn get type => text()();
  TextColumn get localPath => text()();
  TextColumn get storageKey => text()();
  TextColumn get status => text().withDefault(const Constant('queued'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get bytesTotal => integer().withDefault(const Constant(0))();
  IntColumn get bytesSent => integer().withDefault(const Constant(0))();
  TextColumn get thumbnailPath => text().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  // ---- versi 2 (Bab 8.5) — keterangan bukti yang ikut ke watermark ----
  //
  // Semuanya disimpan **saat merekam**, bukan diambil ulang saat memproses
  // atau saat mengunggah. Gudang sering tanpa sinyal, dan nilai yang benar
  // adalah nilai yang berlaku pada hari kejadian — bukan yang berlaku saat
  // videonya kebetulan berhasil terkirim.
  TextColumn get shopName => text().withDefault(const Constant(''))();
  DateTimeColumn get scanTime => dateTime().nullable()();
  BoolColumn get timeVerified =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get deviceStartedAt => dateTime().nullable()();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  RealColumn get locationAccuracyM => real().nullable()();

  @override
  Set<Column> get primaryKey => {videoId};
}

@DriftDatabase(tables: [UploadQueue])
class UploadQueueDatabase extends _$UploadQueueDatabase {
  UploadQueueDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'kamelscan_queue'));

  @override
  int get schemaVersion => 2;

  /// 🔴 Tabel ini **tidak boleh dibuat ulang** saat versinya naik.
  ///
  /// Isinya adalah satu-satunya jejak video bukti yang belum terkirim. Packer
  /// yang memperbarui aplikasi sementara 20 video masih mengantre akan
  /// kehilangan bukti pelanggannya secara permanen bila tabelnya dihapus dan
  /// dibuat ulang — dan itu tepat keadaan yang paling tidak boleh terjadi.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(uploadQueue, uploadQueue.shopName);
            await m.addColumn(uploadQueue, uploadQueue.scanTime);
            await m.addColumn(uploadQueue, uploadQueue.timeVerified);
            await m.addColumn(uploadQueue, uploadQueue.deviceStartedAt);
            await m.addColumn(uploadQueue, uploadQueue.durationSeconds);
            await m.addColumn(uploadQueue, uploadQueue.lat);
            await m.addColumn(uploadQueue, uploadQueue.lng);
            await m.addColumn(uploadQueue, uploadQueue.locationAccuracyM);
          }
        },
      );
}

/// Implementasi Android/iOS di atas drift.
class MobileLocalDbService implements LocalDbService {
  MobileLocalDbService([UploadQueueDatabase? db]) : _db = db;

  UploadQueueDatabase? _db;
  final AppLogger _log = const AppLogger('LocalDbService');

  UploadQueueDatabase get _database =>
      _db ??= UploadQueueDatabase();

  @override
  bool get isSupported => true;

  @override
  Future<void> init() async {
    // Membuka koneksi sekaligus menjalankan migrasi bila ada.
    await _database.customSelect('select 1').get();
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  @override
  Future<Result<void>> enqueue(UploadTask task) => _guard(() async {
        await _database.into(_database.uploadQueue).insertOnConflictUpdate(
              _toCompanion(task),
            );
      });

  @override
  Future<Result<List<UploadTask>>> pendingTasks({int limit = 10}) =>
      _guard(() async {
        final now = DateTime.now();
        final query = _database.select(_database.uploadQueue)
          ..where(
            (t) =>
                t.status.isIn([
                  UploadTaskStatus.queued.wire,
                  UploadTaskStatus.failed.wire,
                ]) &
                (t.nextAttemptAt.isNull() |
                    t.nextAttemptAt.isSmallerOrEqualValue(now)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit);
        final rows = await query.get();
        return rows.map(_toModel).toList();
      });

  @override
  Future<Result<List<UploadTask>>> tasksToProcess({int limit = 5}) =>
      _guard(() async {
        final now = DateTime.now();
        final query = _database.select(_database.uploadQueue)
          ..where(
            (t) =>
                t.status.equals(UploadTaskStatus.pendingProcess.wire) &
                (t.nextAttemptAt.isNull() |
                    t.nextAttemptAt.isSmallerOrEqualValue(now)),
          )
          // Yang paling lama menunggu dikerjakan lebih dulu: berkas mentahnya
          // yang paling lama menempati penyimpanan HP.
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit);
        final rows = await query.get();
        return rows.map(_toModel).toList();
      });

  @override
  Future<Result<void>> markProcessed(
    String videoId, {
    required String localPath,
    required int bytesTotal,
    required int durationSeconds,
    String? thumbnailPath,
  }) =>
      _guard(() async {
        await (_database.update(_database.uploadQueue)
              ..where((t) => t.videoId.equals(videoId)))
            .write(
          UploadQueueCompanion(
            localPath: Value(localPath),
            bytesTotal: Value(bytesTotal),
            durationSeconds: Value(durationSeconds),
            thumbnailPath: Value(thumbnailPath),
            status: Value(UploadTaskStatus.queued.wire),
            // Percobaan watermark yang gagal tidak boleh ikut terhitung
            // sebagai percobaan unggah — keduanya punya jatah sendiri.
            attempts: const Value(0),
            lastError: const Value(null),
            nextAttemptAt: const Value(null),
          ),
        );
      });

  @override
  Future<Result<List<UploadTask>>> allTasks() => _guard(() async {
        final query = _database.select(_database.uploadQueue)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
        final rows = await query.get();
        return rows.map(_toModel).toList();
      });

  @override
  Future<Result<UploadTask?>> findByVideoId(String videoId) => _guard(() async {
        final row = await (_database.select(_database.uploadQueue)
              ..where((t) => t.videoId.equals(videoId)))
            .getSingleOrNull();
        return row == null ? null : _toModel(row);
      });

  @override
  Future<Result<void>> updateStatus(
    String videoId,
    UploadTaskStatus status, {
    String? lastError,
    DateTime? nextAttemptAt,
    bool incrementAttempts = false,
  }) =>
      _guard(() async {
        final table = _database.uploadQueue;
        await _database.transaction(() async {
          final current = await (_database.select(table)
                ..where((t) => t.videoId.equals(videoId)))
              .getSingleOrNull();
          if (current == null) return;

          await (_database.update(table)
                ..where((t) => t.videoId.equals(videoId)))
              .write(
            UploadQueueCompanion(
              status: Value(status.wire),
              attempts: Value(
                incrementAttempts ? current.attempts + 1 : current.attempts,
              ),
              lastError: Value(lastError),
              nextAttemptAt: Value(nextAttemptAt),
            ),
          );
        });
      });

  @override
  Future<Result<void>> updateProgress(String videoId, int bytesSent) =>
      _guard(() async {
        await (_database.update(_database.uploadQueue)
              ..where((t) => t.videoId.equals(videoId)))
            .write(UploadQueueCompanion(bytesSent: Value(bytesSent)));
      });

  @override
  Future<Result<void>> remove(String videoId) => _guard(() async {
        await (_database.delete(_database.uploadQueue)
              ..where((t) => t.videoId.equals(videoId)))
            .go();
      });

  /// Satu pembacaan ringkasan antrian, tanpa aliran.
  ///
  /// 🔴 Pemilahannya mengikuti [UploadTask.isReady] persis, dan itu wajib:
  /// spanduk yang mengatakan "siap diunggah" untuk baris yang penjalan
  /// antrian tidak akan sentuh adalah bentuk kebohongan yang paling mahal —
  /// pengguna menekan "Unggah sekarang" berkali-kali dan tidak pernah terjadi
  /// apa-apa.
  Future<QueueSummary> _hitungRingkasan() async {
    final baris = await (_database.select(_database.uploadQueue)
          ..where((t) => t.status.isNotIn([
                UploadTaskStatus.done.wire,
                UploadTaskStatus.duplicate.wire,
              ])))
        .get();

    var siap = 0;
    var diproses = 0;
    var gagal = 0;
    var tertunda = 0;

    final sekarang = DateTime.now();
    for (final r in baris) {
      final status = UploadTaskStatus.fromWire(r.status);

      if (status == UploadTaskStatus.pendingProcess) {
        diproses++;
      } else if (status == UploadTaskStatus.failed ||
          r.attempts >= AppConstants.maxUploadAttempts) {
        gagal++;
      } else if (status == UploadTaskStatus.paused) {
        tertunda++;
      } else if (r.nextAttemptAt != null &&
          r.nextAttemptAt!.isAfter(sekarang)) {
        tertunda++;
      } else {
        siap++;
      }
    }

    return QueueSummary(
      siap: siap,
      sedangDiproses: diproses,
      gagal: gagal,
      tertunda: tertunda,
    );
  }

  /// Selang antara pembacaan ulang saat antrian **tidak kosong**.
  ///
  /// Tidak ada denyut sama sekali saat antrian kosong — keadaan itu tidak
  /// dapat basi (lihat catatan pada [watchQueueSummary]).
  static const Duration _denyutAntrean = Duration(seconds: 8);

  /// 🔴 Aliran Drift SAJA tidak cukup, dan alasannya bukan teori.
  ///
  /// Antrian unggah dijalankan dari **dua isolate**: aplikasi yang sedang
  /// terbuka, dan isolate latar WorkManager (`upload_worker_mobile.dart`),
  /// yang memanggil `createLocalDbService()` sendiri. Keduanya karena itu
  /// memegang sambungan SQLite yang **berbeda**, dan Drift hanya memberi tahu
  /// aliran miliknya sendiri — tulisan di satu isolate tidak pernah
  /// membangunkan aliran di isolate lain.
  ///
  /// Akibat yang dilaporkan Product Owner 3 September 2026: video terunggah
  /// dan barisnya terhapus oleh isolate latar, tetapi spanduk Beranda tetap
  /// menulis satu video menunggu sampai aplikasi ditutup dan dibuka lagi.
  /// Diukur langsung: tabelnya nol baris sementara layarnya menampilkan satu.
  ///
  /// ⚠️ Denyutnya hanya berjalan saat antriannya **tidak kosong**, dan itu
  /// disengaja: hitungan basi selalu terlalu TINGGI, tidak pernah terlalu
  /// rendah. Baris baru selalu ditulis isolate aplikasi sendiri — dan tulisan
  /// itu membangunkan alirannya sendiri seketika. Jadi antrian kosong yang
  /// basi tidak mungkin terjadi, dan HP tanpa antrian tidak membayar apa pun
  /// untuk penjagaan ini.
  ///
  /// 🔴 Denyutnya juga menjawab hal kedua yang tidak dapat dijawab Drift:
  /// baris `tertunda` menjadi `siap` semata-mata karena **waktu berlalu**
  /// (`nextAttemptAt` terlampaui). Tidak ada tulisan apa pun yang terjadi saat
  /// itu, jadi tidak ada aliran yang dapat membangunkannya.
  @override
  Stream<QueueSummary> watchQueueSummary() {
    late final StreamController<QueueSummary> kendali;
    StreamSubscription<void>? langganan;
    Timer? denyut;
    var terakhir = const QueueSummary();

    Future<void> kirim() async {
      final r = await _hitungRingkasan();
      if (kendali.isClosed || r == terakhir) return;
      terakhir = r;
      kendali.add(r);
    }

    void aturDenyut() {
      if (!terakhir.kosong && denyut == null) {
        denyut = Timer.periodic(_denyutAntrean, (_) => kirim());
      } else if (terakhir.kosong) {
        denyut?.cancel();
        denyut = null;
      }
    }

    kendali = StreamController<QueueSummary>(
      onListen: () {
        // Aliran Drift dipakai sebagai PEMICU, bukan sumber angkanya: ia
        // memberi tahu "tabelnya berubah", lalu ringkasannya dihitung ulang.
        langganan = _database
            .select(_database.uploadQueue)
            .watch()
            .listen((_) async {
          await kirim();
          aturDenyut();
        }, onError: kendali.addError);
      },
      onCancel: () async {
        denyut?.cancel();
        denyut = null;
        await langganan?.cancel();
        // Ditutup di sini, bukan di pemanggil: `kendali` lahir dan mati di
        // dalam metode ini, jadi hanya di sinilah penutupannya dapat dijamin.
        await kendali.close();
      },
    );

    return kendali.stream;
  }

  /// Turunan dari [watchQueueSummary] — satu sumber, satu denyut.
  @override
  Stream<int> watchPendingCount() =>
      watchQueueSummary().map((r) => r.total);

  // ---------------------------------------------------------------------

  Future<Result<T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Result.ok(await body());
    } on Object catch (e, s) {
      _log.e('Operasi antrian lokal gagal', e, s);
      return Result.err(AppFailure.storage(e, s));
    }
  }

  UploadQueueCompanion _toCompanion(UploadTask t) => UploadQueueCompanion(
        videoId: Value(t.videoId),
        tenantId: Value(t.tenantId),
        shopId: Value(t.shopId),
        userId: Value(t.userId),
        resiCode: Value(t.resiCode),
        type: Value(t.type.wire),
        localPath: Value(t.localPath),
        storageKey: Value(t.storageKey),
        status: Value(t.status.wire),
        attempts: Value(t.attempts),
        bytesTotal: Value(t.bytesTotal),
        bytesSent: Value(t.bytesSent),
        thumbnailPath: Value(t.thumbnailPath),
        lastError: Value(t.lastError),
        nextAttemptAt: Value(t.nextAttemptAt),
        createdAt: Value(t.createdAt),
        shopName: Value(t.shopName),
        scanTime: Value(t.scanTime),
        timeVerified: Value(t.timeVerified),
        deviceStartedAt: Value(t.deviceStartedAt),
        durationSeconds: Value(t.durationSeconds),
        lat: Value(t.lat),
        lng: Value(t.lng),
        locationAccuracyM: Value(t.locationAccuracyM),
      );

  UploadTask _toModel(UploadQueueData row) => UploadTask(
        videoId: row.videoId,
        tenantId: row.tenantId,
        shopId: row.shopId,
        userId: row.userId,
        resiCode: row.resiCode,
        type: VideoType.fromWire(row.type),
        localPath: row.localPath,
        storageKey: row.storageKey,
        createdAt: row.createdAt,
        status: UploadTaskStatus.fromWire(row.status),
        attempts: row.attempts,
        bytesTotal: row.bytesTotal,
        bytesSent: row.bytesSent,
        thumbnailPath: row.thumbnailPath,
        lastError: row.lastError,
        nextAttemptAt: row.nextAttemptAt,
        shopName: row.shopName,
        scanTime: row.scanTime,
        timeVerified: row.timeVerified,
        deviceStartedAt: row.deviceStartedAt,
        durationSeconds: row.durationSeconds,
        lat: row.lat,
        lng: row.lng,
        locationAccuracyM: row.locationAccuracyM,
      );
}

LocalDbService createPlatformLocalDbService() => MobileLocalDbService();
