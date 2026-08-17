import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../config/app_constants.dart';
import '../repositories/video_repository.dart';
import '../services/connectivity_service.dart';
import '../services/local_db_service.dart';
import '../services/notification_service.dart';
import '../services/r2_storage_service.dart';
import '../services/supabase_service.dart';
import '../utils/logger.dart';
import 'upload_queue_runner.dart';
import 'upload_worker.dart';

/// Titik masuk isolate latar belakang (Bab 8.7).
///
/// ⚠️ Fungsi ini berjalan di isolate terpisah tanpa `BuildContext` dan tanpa
/// satu pun provider Riverpod yang hidup. Segala kebutuhan — Supabase, drift,
/// preferensi — **harus dibangun ulang di dalamnya**. Itu sebabnya
/// [UploadQueueRunner] sengaja ditulis sebagai kelas biasa: alur unggah yang
/// sama dipakai di sini tanpa disalin ulang.
///
/// 🔴 **Belum diuji di perangkat.** Jalur utama unggah tetap aplikasi yang
/// sedang terbuka (dipicu saat dibuka dan tiap kali jaringan kembali). Yang di
/// sini adalah tambahan: kesempatan menyusul saat aplikasi di latar. Dua hal
/// yang perlu diperhatikan saat mengujinya nanti:
///
/// 1. Sesi Supabase harus benar-benar pulih di isolate ini. Bila tidak, seluruh
///    permintaan akan ditolak 401 dan antrian menghabiskan jatah percobaannya
///    tanpa sebab yang terlihat pengguna.
/// 2. Dua koneksi drift ke berkas SQLite yang sama (aplikasi + isolate ini)
///    dapat saling mengunci. Token tidak akan terpotong dua kali — trigger
///    `after_video_uploaded` hanya bereaksi pada perubahan status — tetapi
///    kegagalan "database is locked" tetap mungkin muncul di log.
@pragma('vm:entry-point')
void uploadCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    const log = AppLogger('UploadWorker');
    log.i('Tugas latar dijalankan: $taskName');
    // 🔴 `debugPrint`, bukan hanya `AppLogger`. Isolate ini berjalan saat
    // aplikasi di latar belakang — tidak ada layar, tidak ada terminal
    // `flutter run`. Satu-satunya cara mengetahui ia pernah berjalan adalah
    // logcat, dan `AppLogger` tidak pernah sampai ke sana (jebakan 11).
    // Tanpa baris-baris ini, "gagal" dan "tidak pernah dipanggil" terlihat
    // persis sama: tidak ada apa-apa. Lihat L.9 di `DEVIASI_LIBRARY.md`.
    debugPrint('KAMELSCAN_LATAR Tugas latar dijalankan: $taskName');

    // Plugin (drift, path_provider, shared_preferences) memerlukan binding
    // yang sudah siap — isolate ini tidak melewati `main()`.
    WidgetsFlutterBinding.ensureInitialized();

    LocalDbService? db;
    try {
      await SupabaseService.init();

      // Risiko nomor satu isolate ini: sesi Supabase tidak ikut pulih.
      //
      // Bila itu terjadi, menjalankan antrian justru **merusak**: setiap
      // permintaan ditolak 401, tiap penolakan menghabiskan satu jatah
      // percobaan, dan setelah lima putaran video yang sebenarnya baik-baik
      // saja ditandai `failed`. Lebih baik tidak berbuat apa-apa dan meminta
      // WorkManager menjadwalkan ulang — persis alasan yang sama dengan kuota
      // habis di `UploadQueueRunner._handleFailure`.
      final user = SupabaseService.currentUser;
      if (user == null) {
        log.w('Sesi tidak pulih di isolate latar — antrian tidak dijalankan');
        debugPrint('KAMELSCAN_LATAR sesi TIDAK pulih · antrian dilewati, '
            'dijadwalkan ulang');
        return false;
      }
      debugPrint('KAMELSCAN_LATAR sesi pulih · uid=${user.id}');

      db = createLocalDbService();
      await db.init();

      final runner = UploadQueueRunner(
        db: db,
        storage: R2StorageService(SupabaseService.client),
        videos: VideoRepository(SupabaseService.client),
        connectivity: ConnectivityService(),
        notifications: createNotificationService(),
        allowCellular: () async {
          final prefs = await SharedPreferences.getInstance();
          return prefs.getBool(AppConstants.prefUploadOnCellular) ?? false;
        },
      );

      await runner.run();
      debugPrint('KAMELSCAN_LATAR selesai');
      return true;
    } on Object catch (e, s) {
      log.e('Tugas latar gagal', e, s);
      debugPrint('KAMELSCAN_LATAR GAGAL · $e');
      // `false` membuat WorkManager menjadwalkan ulang dengan backoff. Antrian
      // tetap utuh di SQLite, jadi tidak ada yang hilang karena kegagalan ini.
      return false;
    } finally {
      await db?.close();
    }
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
