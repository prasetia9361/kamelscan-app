import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config/app_constants.dart';
import '../models/enums.dart';
import '../models/upload_task.dart';
import '../repositories/video_repository.dart';
import '../services/connectivity_service.dart';
import '../services/local_db_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../utils/app_failure.dart';
import '../utils/logger.dart';

/// Penjalan antrian upload (Bab 8.7).
///
/// Ditulis sebagai kelas biasa — **tanpa Riverpod, tanpa BuildContext** —
/// supaya alur yang sama dapat dijalankan dari dua tempat: aplikasi yang
/// sedang terbuka, dan isolate latar belakang WorkManager yang tidak punya
/// satu pun provider hidup.
///
/// Urutannya mengikuti Bab 8.7 dan sudah dibuktikan berjalan di database
/// sungguhan pada 13 Agustus 2026 (`supabase/README.md`):
/// sisip baris → minta presigned URL → PUT ke R2 → tandai `uploaded`
/// (trigger memotong 1 token) → hapus berkas lokal → hapus baris antrian.
/// Apa yang **sebenarnya terjadi** pada satu putaran antrian.
///
/// 🔴 Sampai 3 September 2026 `run()` mengembalikan `void` dan setiap jalur
/// "tidak melakukan apa-apa" hanya `return` tanpa satu baris pun yang tembus
/// ke logcat — `AppLogger` memakai `dart:developer` (jebakan nomor 9).
///
/// Akibatnya dilaporkan Product Owner: menekan **Unggah sekarang** tidak
/// menghasilkan apa pun di layar, dan tidak ada cara mengetahui apakah
/// tombolnya rusak, jaringannya salah, atau memang tidak ada yang dapat
/// dikerjakan. Ternyata yang ketiga — tetapi butuh membaca database perangkat
/// untuk mengetahuinya.
enum UploadRunOutcome {
  /// Ada yang benar-benar terunggah.
  terunggah,

  /// Putaran lain sedang berjalan; panggilan ini tidak melakukan apa-apa.
  sedangBerjalan,

  /// Perangkat ini tidak punya antrian lokal (web, Bab 4.3).
  tidakDidukung,

  /// Tidak ada jaringan sama sekali.
  tanpaJaringan,

  /// Hanya ada data seluler dan pengguna belum mengizinkannya.
  menungguWifi,

  /// Antriannya kosong.
  kosong,

  /// Ada isinya, tetapi tidak satu pun yang siap diunggah sekarang — masih
  /// menunggu watermark, sudah menyerah, atau menunggu giliran percobaan.
  tidakAdaYangSiap,

  /// Percobaan unggah dilakukan tetapi semuanya gagal.
  semuaGagal,
}

class UploadQueueRunner {
  UploadQueueRunner({
    required LocalDbService db,
    required StorageService storage,
    required VideoRepository videos,
    required ConnectivityService connectivity,
    required NotificationService notifications,
    required Future<bool> Function() allowCellular,
  })  : _db = db,
        _storage = storage,
        _videos = videos,
        _connectivity = connectivity,
        _notifications = notifications,
        _allowCellular = allowCellular;

  final LocalDbService _db;
  final StorageService _storage;
  final VideoRepository _videos;
  final ConnectivityService _connectivity;
  final NotificationService _notifications;

  /// Bab 8.7 langkah 1 — unggah hanya lewat Wi-Fi kecuali pengguna
  /// mengizinkan data seluler.
  final Future<bool> Function() _allowCellular;

  static const AppLogger _log = AppLogger('UploadQueue');

  /// Bab 8.7 langkah 2 — maksimal 3 item per putaran. Bukan sekadar angka:
  /// mengunggah semuanya sekaligus di jaringan gudang membuat seluruhnya
  /// lambat dan tidak ada satu pun yang selesai.
  static const int _batchSize = 3;

  bool _running = false;

  bool get isRunning => _running;

  /// Satu putaran antrian. Aman dipanggil berkali-kali; panggilan saat sedang
  /// berjalan langsung kembali.
  Future<UploadRunOutcome> run() async {
    if (_running) {
      debugPrint('KAMELSCAN_PIPA Putaran dilewati - satu sedang berjalan');
      return UploadRunOutcome.sedangBerjalan;
    }
    if (!_db.isSupported) return UploadRunOutcome.tidakDidukung;

    _running = true;
    try {
      final hasil = await _runOnce();
      debugPrint('KAMELSCAN_PIPA Putaran selesai - ${hasil.name}');
      return hasil;
    } on Object catch (e, s) {
      _log.e('Putaran antrian upload berhenti tak terduga', e, s);
      // 🔴 Wajib `debugPrint`, bukan hanya `AppLogger` (jebakan nomor 9).
      debugPrint('KAMELSCAN_PIPA Putaran BERHENTI tak terduga - $e');
      return UploadRunOutcome.semuaGagal;
    } finally {
      _running = false;
    }
  }

  Future<UploadRunOutcome> _runOnce() async {
    final jaringan = await _periksaJaringan();
    if (jaringan != null) return jaringan;

    final pending = await _db.pendingTasks(limit: _batchSize);
    final tasks = pending.valueOrNull ?? const <UploadTask>[];
    final ready = tasks
        .where((t) => t.isReady(maxAttempts: AppConstants.maxUploadAttempts))
        .toList();

    if (ready.isEmpty) {
      // 🔴 Dua keadaan yang SANGAT berbeda, dan membedakannya adalah inti
      // perbaikan ini: antrian yang memang kosong, versus antrian berisi yang
      // tidak satu pun barisnya dapat disentuh. Yang kedua persis keadaan
      // yang membuat "Unggah sekarang" terasa rusak.
      final hasil = tasks.isEmpty
          ? UploadRunOutcome.kosong
          : UploadRunOutcome.tidakAdaYangSiap;
      debugPrint('KAMELSCAN_PIPA Tidak ada yang diunggah - ${hasil.name} '
          '(${tasks.length} baris di antrean)');
      return hasil;
    }

    _log.i('Mengunggah ${ready.length} video');
    debugPrint('KAMELSCAN_PIPA Mengunggah ${ready.length} video');
    await _notifications.showUploadProgress(
      pending: ready.length,
      total: ready.length,
    );

    var uploaded = 0;
    for (final task in ready) {
      final ok = await _uploadOne(task);
      if (ok) uploaded++;

      // Sinyal bisa hilang di tengah antrean — jangan menghabiskan jatah
      // percobaan seluruh sisa antrean karena packer berjalan ke gudang
      // belakang.
      if (await _periksaJaringan() != null) break;
    }

    if (uploaded > 0) {
      await _notifications.showUploadComplete(uploaded: uploaded);
      return UploadRunOutcome.terunggah;
    }

    await _notifications.cancelAll();
    return UploadRunOutcome.semuaGagal;
  }

  /// Bab 8.7 langkah 1.
  ///
  /// Mengembalikan **null** bila jaringannya mengizinkan, atau alasan
  /// penolakannya bila tidak.
  ///
  /// 🔴 Kedua jalur penolakan sekarang dicetak. Sebelumnya yang "tidak ada
  /// jaringan" `return false` tanpa sepatah kata pun, dan yang "menunggu
  /// Wi-Fi" hanya menulis ke `AppLogger` yang tidak pernah sampai ke logcat.
  /// Dari luar keduanya tidak dapat dibedakan dari antrian kosong.
  Future<UploadRunOutcome?> _periksaJaringan() async {
    if (!await _connectivity.isConnected) {
      debugPrint('KAMELSCAN_PIPA Tidak ada jaringan - antrean menunggu');
      return UploadRunOutcome.tanpaJaringan;
    }
    if (!await _connectivity.isMobileData) return null;

    if (await _allowCellular()) return null;

    _log.i('Hanya ada data seluler dan pengguna belum mengizinkannya — '
        'antrian menunggu Wi-Fi');
    debugPrint('KAMELSCAN_PIPA Hanya data seluler dan belum diizinkan - '
        'antrean menunggu Wi-Fi');
    return UploadRunOutcome.menungguWifi;
  }

  Future<bool> _uploadOne(UploadTask task) async {
    // ignore: avoid_slow_async_io
    if (!await File(task.localPath).exists()) {
      // Berkas hilang (mis. aplikasi dipasang ulang, jebakan 10 di
      // `PROMPT_SESI_BARU.md`). Mengulanginya tidak akan pernah berhasil.
      _log.e('Berkas antrian sudah tidak ada: ${task.localPath}');
      await _db.updateStatus(
        task.videoId,
        UploadTaskStatus.failed,
        lastError: 'Berkas video tidak ditemukan lagi di perangkat',
      );
      return false;
    }

    await _db.updateStatus(task.videoId, UploadTaskStatus.running);

    // ---- 1. Baris di server harus ada sebelum presigned URL bisa diminta ----
    final row = await _videos.ensureVideoRow(task);
    if (row.isErr) {
      await _handleFailure(task, row.failureOrNull!);
      return false;
    }
    final storageKey = row.valueOrNull?.storageKey ?? task.storageKey;

    // ---- 2. Presigned URL (Bab 8.7 langkah 3) ----
    final presigned = await _storage.requestUploadUrl(
      videoId: task.videoId,
      storageKey: storageKey,
      sizeBytes: task.bytesTotal,
      contentType: 'video/mp4',
    );
    if (presigned.isErr) {
      await _handleFailure(task, presigned.failureOrNull!);
      return false;
    }
    final target = presigned.valueOrNull!;

    // ---- 3. PUT ke R2 (langkah 4) ----
    final sent = await _storage.uploadFile(
      localPath: task.localPath,
      target: target,
      cancelToken: task.videoId,
      onProgress: (bytes, _) => unawaited(
        _db.updateProgress(task.videoId, bytes),
      ),
    );
    if (sent.isErr) {
      await _handleFailure(task, sent.failureOrNull!);
      return false;
    }

    // ---- 4. Tandai terunggah — di sinilah 1 token dipotong (langkah 5) ----
    final marked = await _videos.markUploaded(
      videoId: task.videoId,
      storageKey: target.storageKey,
      fileSizeBytes: task.bytesTotal,
      durationSeconds: task.durationSeconds,
    );
    if (marked.isErr) {
      // Berkasnya sudah sampai di R2, hanya penandanya yang gagal. Berkas lokal
      // **tidak** dihapus dan barisnya tetap di antrian: mengulang unggahan
      // yang sama jauh lebih murah daripada video yang ada di R2 tetapi tidak
      // pernah tercatat, sehingga tidak muncul di Riwayat siapa pun.
      await _handleFailure(task, marked.failureOrNull!);
      return false;
    }

    // ---- 5. Barulah berkas lokal boleh hilang (Bab 0.2 poin 7) ----
    await _deleteQuietly(task.localPath);
    if (task.thumbnailPath != null) await _deleteQuietly(task.thumbnailPath!);
    await _db.remove(task.videoId);

    _log.i('Video terunggah · resi=${task.resiCode} · $storageKey');
    // Lihat catatan pada `VideoProcessingQueue._onSuccess`: hanya `debugPrint`
    // yang tembus ke logcat, dan bukti bahwa video benar-benar sampai adalah
    // hal yang paling perlu dibaca dari perangkat.
    debugPrint('KAMELSCAN_PIPA Terunggah · resi=${task.resiCode} · $storageKey');
    return true;
  }

  Future<void> _handleFailure(UploadTask task, AppFailure failure) async {
    final attempts = task.attempts + 1;

    // Bab 7.7 — resi ganda tidak akan pernah berhasil dengan diulang. Ia
    // menunggu keputusan pengguna di Riwayat, bukan mengulang selamanya.
    if (failure.kind == FailureKind.conflict && failure.code == '23505') {
      _log.w('Resi ${task.resiCode} sudah ada di server — ditandai duplicate');
      await _db.updateStatus(
        task.videoId,
        UploadTaskStatus.duplicate,
        lastError: failure.messageKey,
      );
      return;
    }

    // Kuota habis atau langganan berakhir adalah keadaan **milik tenant**,
    // bukan kesalahan unggahan ini. Menghabiskan jatah percobaan karenanya akan
    // membuang video yang sebenarnya baik-baik saja begitu Owner mengisi token.
    if (failure.kind == FailureKind.quota ||
        failure.kind == FailureKind.subscriptionInactive) {
      _log.w('Unggahan ditunda: ${failure.messageKey}');
      await _db.updateStatus(
        task.videoId,
        UploadTaskStatus.queued,
        lastError: failure.messageKey,
        nextAttemptAt: DateTime.now().add(const Duration(hours: 1)),
      );
      return;
    }

    final giveUp = attempts >= AppConstants.maxUploadAttempts;
    _log.w('Unggahan gagal (percobaan $attempts/'
        '${AppConstants.maxUploadAttempts}): ${failure.debugMessage ?? failure.messageKey}');

    await _db.updateStatus(
      task.videoId,
      giveUp ? UploadTaskStatus.failed : UploadTaskStatus.queued,
      lastError: failure.debugMessage ?? failure.messageKey,
      incrementAttempts: true,
      nextAttemptAt: giveUp ? null : DateTime.now().add(task.retryDelay),
    );

    if (giveUp) {
      // Bab 8.7 langkah 6 — setelah 5 kali gagal, video muncul di Riwayat
      // dengan tombol *Coba lagi*. Berkas lokalnya tetap disimpan; tanpa itu
      // tombol tersebut tidak punya apa-apa untuk diulang.
      await _notifications.showUploadFailed(resiCode: task.resiCode);
      await _videos.recordUploadFailure(
        videoId: task.videoId,
        attempts: attempts,
        message: failure.debugMessage ?? failure.messageKey,
      );
    }
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      // ignore: avoid_slow_async_io
      if (await file.exists()) await file.delete();
    } on Object catch (e) {
      _log.w('Berkas tidak dapat dihapus: $path', e);
    }
  }
}
