import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/enums.dart';
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

  @override
  Set<Column> get primaryKey => {videoId};
}

@DriftDatabase(tables: [UploadQueue])
class UploadQueueDatabase extends _$UploadQueueDatabase {
  UploadQueueDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'kamelscan_queue'));

  @override
  int get schemaVersion => 1;
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

  @override
  Stream<int> watchPendingCount() {
    final count = _database.uploadQueue.videoId.count();
    final query = _database.selectOnly(_database.uploadQueue)
      ..addColumns([count])
      ..where(
        _database.uploadQueue.status.isNotIn([
          UploadTaskStatus.done.wire,
          UploadTaskStatus.duplicate.wire,
        ]),
      );
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

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
      );
}

LocalDbService createPlatformLocalDbService() => MobileLocalDbService();
