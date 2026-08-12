import 'dart:io';

import 'package:workmanager/workmanager.dart';

import '../config/app_constants.dart';
import '../utils/logger.dart';
import 'upload_worker.dart';

/// Titik masuk isolate latar belakang.
///
/// ⚠️ Fungsi ini berjalan di isolate terpisah tanpa `BuildContext` dan tanpa
/// provider Riverpod yang sudah hidup. Segala kebutuhan (Supabase, drift,
/// pembacaan pengaturan) **harus diinisialisasi ulang di dalamnya**. Logika
/// pemrosesan antrian ditulis di Bab 8; kerangkanya sudah benar sejak sekarang.
@pragma('vm:entry-point')
void uploadCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    const log = AppLogger('UploadWorker');
    log.i('Tugas latar dijalankan: $taskName');

    // TODO(Bab 8): inisialisasi Supabase + LocalDbService di isolate ini,
    // ambil UploadTask yang siap, unggah lewat presigned URL, tandai hasilnya,
    // lalu hapus berkas lokal setelah server mengonfirmasi.
    return true;
  });
}

/// Implementasi Android/iOS.
class MobileUploadWorker implements UploadWorker {
  MobileUploadWorker();

  static const AppLogger _log = AppLogger('UploadWorker');

  /// Android WorkManager menolak periode di bawah 15 menit; ini batas sistem,
  /// bukan pilihan kita.
  static const Duration _frequency = Duration(minutes: 15);

  @override
  bool get isSupported => true;

  @override
  Future<void> register() async {
    await Workmanager().initialize(uploadCallbackDispatcher);

    if (Platform.isAndroid) {
      await Workmanager().registerPeriodicTask(
        AppConstants.taskUploadQueue,
        AppConstants.taskUploadQueue,
        frequency: _frequency,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: AppConstants.uploadRetryBaseDelay,
      );
      return;
    }

    // iOS: BGTaskScheduler tidak menjamin waktu eksekusi. Pendaftaran tetap
    // dilakukan sebagai usaha terbaik, tetapi jalur utama pemrosesan antrian
    // di iOS adalah saat aplikasi berada di foreground (Bab 4.3).
    await Workmanager().registerPeriodicTask(
      AppConstants.taskUploadQueue,
      AppConstants.taskUploadQueue,
      frequency: _frequency,
    );
    _log.i('iOS: antrian upload diproses terutama saat aplikasi dibuka');
  }

  @override
  Future<void> requestImmediateRun() async {
    await Workmanager().registerOneOffTask(
      '${AppConstants.taskUploadQueue}.now',
      AppConstants.taskUploadQueue,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: AppConstants.uploadRetryBaseDelay,
    );
  }

  @override
  Future<void> cancelAll() => Workmanager().cancelAll();
}

UploadWorker createPlatformUploadWorker() => MobileUploadWorker();
