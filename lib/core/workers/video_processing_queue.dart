import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/app_constants.dart';
import '../models/app_settings.dart';
import '../models/enums.dart';
import '../models/upload_task.dart';
import '../services/local_db_service.dart';
import '../services/video_processor.dart';
import '../utils/logger.dart';

/// Antrean watermark (Bab 8.5).
///
/// 🔴 **Satu FFmpeg pada satu waktu, dan tidak pernah selagi merekam.**
///
/// Keduanya bukan kehati-hatian berlebihan, melainkan hasil pengukuran di
/// Redmi Note 9 (15–16 Agustus 2026, tercatat di `DEVIASI_LIBRARY.md` bagian J):
/// pengukur watermark yang dipanggil `unawaited` tanpa antrean membuat beberapa
/// FFmpeg berjalan bersamaan saat perekaman beruntun, saling berebut CPU,
/// dan pratinjau kamera menjadi patah-patah sementara HP memanas.
///
/// Jadwal yang dipakai diputuskan Product Owner 17 Agustus 2026: **di sela
/// antar-paket**. Begitu perekaman berikutnya dimulai, pekerjaan yang sedang
/// berjalan dibatalkan dan diulang nanti dari berkas mentahnya yang masih utuh
/// — membatalkan lebih murah daripada mengganggu perekaman, dan rasio proses
/// di bawah 1,0x membuat antrean tetap terkuras selama ada jeda antar-paket.
///
/// Alternatif "kerjakan semua setelah keluar layar rekam" ditolak karena
/// 50 paket berarti ± 795 MB rekaman mentah menumpuk di HP selama sesi.
class VideoProcessingQueue {
  VideoProcessingQueue({
    required LocalDbService db,
    required VideoProcessor processor,
    required Future<TenantSettings> Function() settings,
    Future<void> Function()? onProcessed,
    Future<Directory> Function()? outputDirectory,
  })  : _db = db,
        _processor = processor,
        _settings = settings,
        _onProcessed = onProcessed,
        _outputDirectory = outputDirectory ?? _defaultOutputDirectory;

  final LocalDbService _db;
  final VideoProcessor _processor;
  final Future<TenantSettings> Function() _settings;

  /// Dipanggil setiap satu video selesai diberi watermark — dipakai untuk
  /// membangunkan antrian unggah (Bab 8.7).
  final Future<void> Function()? _onProcessed;

  /// Tempat berkas hasil proses. Dapat diganti agar aturan antrean ini dapat
  /// diuji di komputer, tanpa `path_provider` yang butuh perangkat.
  final Future<Directory> Function() _outputDirectory;

  static const AppLogger _log = AppLogger('WatermarkQueue');

  /// Berapa kali watermark boleh gagal sebelum menyerah dan meminta tindakan
  /// pengguna. Sama dengan batas percobaan unggah agar tidak ada dua angka
  /// berbeda yang harus diingat.
  static const int _maxAttempts = AppConstants.maxUploadAttempts;

  bool _running = false;
  bool _paused = false;
  bool _cancelledByPause = false;
  bool _disposed = false;

  bool get isBusy => _running;

  /// Perekaman dimulai — FFmpeg minggir.
  Future<void> pause() async {
    if (_paused) return;
    _paused = true;
    if (!_running) return;

    // Berkas mentahnya masih utuh dan barisnya masih `pendingProcess`, jadi
    // pembatalan ini tidak menghilangkan apa pun kecuali beberapa detik kerja.
    _cancelledByPause = true;
    _log.i('Perekaman dimulai — watermark yang berjalan dibatalkan sementara');
    await _processor.cancelAll();
  }

  /// Perekaman berhenti — antrean boleh jalan lagi.
  void resume() {
    if (!_paused) return;
    _paused = false;
    kick();
  }

  /// Periksa antrean dan kerjakan bila ada dan sedang boleh.
  ///
  /// Aman dipanggil kapan saja dan sesering apa pun: pemanggilan saat antrean
  /// sedang bekerja tidak menghasilkan pekerjaan kedua.
  void kick() {
    if (_running || _paused || _disposed) return;
    if (!_db.isSupported || !_processor.isSupported) return;
    unawaited(_drain());
  }

  Future<void> dispose() async {
    _disposed = true;
    await _processor.cancelAll();
  }

  // ---------------------------------------------------------------------

  Future<void> _drain() async {
    _running = true;
    try {
      while (!_paused && !_disposed) {
        final batch = await _db.tasksToProcess(limit: 1);
        final task = batch.valueOrNull?.firstOrNull;
        if (task == null) return;

        await _processOne(task);
      }
    } on Object catch (e, s) {
      _log.e('Antrean watermark berhenti karena kesalahan tak terduga', e, s);
    } finally {
      _running = false;
    }
  }

  Future<void> _processOne(UploadTask task) async {
    final input = File(task.localPath);
    // ignore: avoid_slow_async_io
    if (!await input.exists()) {
      // Terjadi setelah aplikasi dipasang ulang: cache aplikasi ikut terhapus
      // beserta seluruh rekaman mentah (jebakan 10 di `PROMPT_SESI_BARU.md`).
      // Mengulanginya tidak akan pernah berhasil, jadi jangan berputar-putar.
      _log.e('Rekaman mentah sudah tidak ada: ${task.localPath}');
      await _db.updateStatus(
        task.videoId,
        UploadTaskStatus.failed,
        lastError: 'Berkas rekaman tidak ditemukan lagi di perangkat',
      );
      return;
    }

    final outputPath = await _outputPathFor(task.videoId);
    final settings = await _settings();

    // Perekaman sempat dimulai selagi baris ini disiapkan. Berhenti sebelum
    // FFmpeg menyala sama sekali — membatalkannya setelah berjalan hanya
    // membuang kerja yang tidak perlu dimulai.
    if (_paused || _disposed) return;

    final started = DateTime.now();

    _log.i('Watermark mulai · resi=${task.resiCode} '
        'durasi=${task.durationSeconds} dtk');

    final result = await _processor.applyWatermark(
      inputPath: task.localPath,
      outputPath: outputPath,
      data: WatermarkData(
        resiCode: task.resiCode,
        serverTime: task.scanTime ?? task.createdAt,
        shopName: task.shopName,
        shopId: task.shopId,
        coordinates: _formatCoordinates(task),
        lat: task.lat,
        lng: task.lng,
        timeVerified: task.timeVerified,
      ),
      settings: settings,
    );

    if (_cancelledByPause) {
      // Bukan kegagalan — jangan menghabiskan jatah percobaan karena packer
      // kebetulan memindai paket berikutnya.
      _cancelledByPause = false;
      await _deleteQuietly(outputPath);
      _log.i('Watermark ditunda, akan diulang di sela berikutnya');
      return;
    }

    await result.fold(
      onOk: (processed) => _onSuccess(task, processed, started),
      onErr: (failure) async {
        await _deleteQuietly(outputPath);
        final attempts = task.attempts + 1;
        final giveUp = attempts >= _maxAttempts;

        _log.e('Watermark gagal (percobaan $attempts/$_maxAttempts)', failure);
        await _db.updateStatus(
          task.videoId,
          // 🔴 Berkas mentahnya **tidak** dihapus, apa pun hasilnya. Selama ia
          // masih ada, video buktinya masih dapat diselamatkan lewat tombol
          // *Coba lagi* di Riwayat.
          giveUp ? UploadTaskStatus.failed : UploadTaskStatus.pendingProcess,
          lastError: failure.debugMessage ?? failure.messageKey,
          incrementAttempts: true,
          nextAttemptAt: giveUp ? null : DateTime.now().add(task.retryDelay),
        );
      },
    );
  }

  Future<void> _onSuccess(
    UploadTask task,
    ProcessedVideo processed,
    DateTime started,
  ) async {
    final elapsed = DateTime.now().difference(started);
    final duration = processed.durationSeconds > 0
        ? processed.durationSeconds
        : task.durationSeconds;

    final marked = await _db.markProcessed(
      task.videoId,
      localPath: processed.path,
      bytesTotal: processed.sizeBytes,
      durationSeconds: duration,
      thumbnailPath: processed.thumbnailPath,
    );

    if (marked.isErr) {
      // Antrian tidak tahu berkas hasilnya — jangan hapus yang mentah, kalau
      // tidak buktinya hilang sama sekali.
      _log.e('Hasil watermark gagal dicatat di antrian', marked.failureOrNull);
      await _deleteQuietly(processed.path);
      return;
    }

    // 🔴 Baru **sekarang** berkas mentah boleh dihapus: hasil olahannya sudah
    // ada di disk dan sudah tercatat di antrian. Rekaman mentah ± 370–500 KB
    // per detik; membiarkannya berarti 50 paket = ± 795 MB yang tidak pernah
    // hilang dengan sendirinya (utang yang dilunasi di sini).
    await _deleteQuietly(task.localPath);

    final ratio = task.durationSeconds > 0
        ? (elapsed.inMilliseconds / (task.durationSeconds * 1000))
            .toStringAsFixed(2)
        : '-';
    final ringkasan = 'Watermark selesai · ${elapsed.inSeconds} dtk untuk video '
        '${task.durationSeconds} dtk (rasio $ratio) · '
        '${_mb(task.bytesTotal)} → ${_mb(processed.sizeBytes)}';
    _log.i(ringkasan);

    // 🔴 `debugPrint`, bukan hanya `AppLogger`. `AppLogger` memakai
    // `dart:developer` yang **tidak pernah sampai ke logcat** — hanya ke
    // terminal `flutter run`. Angka rasio inilah yang harus dapat dibaca dari
    // perangkat saat mengukur (jebakan 11 di `PROMPT_SESI_BARU.md`):
    //
    //   adb logcat -v time | findstr KAMELSCAN_PIPA
    debugPrint('KAMELSCAN_PIPA $ringkasan');

    await _onProcessed?.call();
  }

  /// Berkas hasil proses **tidak** boleh tinggal di folder cache.
  ///
  /// Cache boleh dibuang sistem operasi kapan saja saat penyimpanan menipis,
  /// dan yang dibuang di sini adalah bukti pelanggan yang belum terkirim.
  /// Rekaman mentah dari kamera memang tinggal di cache — itu tidak apa-apa,
  /// karena masih dapat diolah ulang selama masih ada, dan justru disengaja
  /// agar sisa yang terlanjur yatim ikut tersapu.
  Future<String> _outputPathFor(String videoId) async {
    final dir = await _outputDirectory();
    // ignore: avoid_slow_async_io
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return p.join(dir.path, '$videoId.mp4');
  }

  static Future<Directory> _defaultOutputDirectory() async {
    final base = await getApplicationSupportDirectory();
    return Directory(p.join(base.path, 'videos'));
  }

  static String? _formatCoordinates(UploadTask task) {
    final lat = task.lat;
    final lng = task.lng;
    if (lat == null || lng == null) return null;
    return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  }

  static String _mb(int bytes) =>
      '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

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
