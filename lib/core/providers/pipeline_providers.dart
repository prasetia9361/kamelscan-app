import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_constants.dart';
import '../models/app_settings.dart';
import '../services/r2_storage_service.dart';
import '../services/server_clock.dart';
import '../services/storage_service.dart';
import '../utils/logger.dart';
import '../workers/upload_queue_runner.dart';
import '../workers/video_processing_queue.dart';
import 'repository_providers.dart';
import 'session_provider.dart';

part 'pipeline_providers.g.dart';

/// Pipeline Bab 8.5–8.7 dirangkai di satu tempat: watermark → antrian → unggah.
///
/// Ketiganya sengaja tidak saling memanggil lewat provider. Antrean watermark
/// hanya tahu "ada yang selesai diproses", dan penjalan unggah hanya tahu "ada
/// yang siap diunggah". Perangkaiannya ada di sini supaya urutan pipeline dapat
/// dibaca dalam satu layar, bukan dikumpulkan dari lima berkas.

const AppLogger _log = AppLogger('Pipeline');

// ---------------------------------------------------------------------------
// Waktu server
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
ServerClock serverClock(Ref ref) =>
    ServerClock(ref.watch(supabaseClientProvider));

// ---------------------------------------------------------------------------
// Pengaturan tenant untuk watermark
// ---------------------------------------------------------------------------

/// Pengaturan watermark milik tenant, **dengan salinan lokal**.
///
/// 🔴 Salinannya bukan pengoptimalan. Video diproses di gudang yang sering
/// tanpa sinyal, kadang berjam-jam setelah aplikasi dibuka. Tanpa salinan,
/// posisi dan opasitas watermark akan diam-diam jatuh ke nilai bawaan dan
/// video pelanggan tampil berbeda dari yang mereka atur.
@Riverpod(keepAlive: true)
Future<TenantSettings> tenantSettings(Ref ref) async {
  final session = ref.watch(sessionProvider).value;
  final prefs = await SharedPreferences.getInstance();

  Future<TenantSettings> cached(String tenantId) async {
    final raw = prefs.getString(AppConstants.prefTenantSettings);
    if (raw == null) return TenantSettings(tenantId: tenantId);
    try {
      return TenantSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on Object catch (e) {
      _log.w('Salinan pengaturan tenant tidak terbaca', e);
      return TenantSettings(tenantId: tenantId);
    }
  }

  if (session == null) return cached('');

  final result = await ref
      .read(settingsRepositoryProvider)
      .fetchTenantSettings(session.tenantId);

  return result.fold(
    onOk: (settings) {
      unawaited(
        prefs.setString(
          AppConstants.prefTenantSettings,
          jsonEncode(settings.toJson()),
        ),
      );
      return settings;
    },
    onErr: (failure) {
      _log.i('Pengaturan tenant dibaca dari salinan lokal: '
          '${failure.messageKey}');
      return cached(session.tenantId);
    },
  );
}

// ---------------------------------------------------------------------------
// Penyimpanan objek
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
StorageService storageService(Ref ref) =>
    R2StorageService(ref.watch(supabaseClientProvider));

// ---------------------------------------------------------------------------
// Sakelar "unggah juga lewat data seluler" (Bab 8.7 langkah 1)
// ---------------------------------------------------------------------------

/// Disimpan di perangkat, bukan di server — diputuskan Product Owner
/// 17 Agustus 2026.
///
/// Alasannya bukan penghematan migrasi: ini preferensi milik **satu HP**.
/// Packer dengan kuota data terbatas dan packer yang memakai HP kantor
/// berlangganan tak terbatas tidak seharusnya dipaksa berbagi satu pilihan.
@Riverpod(keepAlive: true)
class UploadOnCellular extends _$UploadOnCellular {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    // Bawaannya **mati**: membakar kuota data packer tanpa diminta adalah
    // keluhan yang baru terdengar setelah pelanggan memakainya.
    return prefs.getBool(AppConstants.prefUploadOnCellular) ?? false;
  }

  Future<void> set(bool value) async {
    state = AsyncData(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefUploadOnCellular, value);
    // Baru saja diizinkan — antrian tidak perlu menunggu putaran berikutnya.
    if (value) unawaited(ref.read(uploadQueueRunnerProvider).run());
  }
}

/// Sakelar **"Rekam dengan suara"** (Bab 9.7, diminta Product Owner
/// 19 Agustus 2026).
///
/// Disimpan di perangkat, sejajar dengan [UploadOnCellular] — keputusan
/// Product Owner: tiap HP boleh punya pilihannya sendiri.
///
/// 🔴 Bawaannya **menyala**, dan itu disengaja. Sebelum sakelar ini ada,
/// seluruh video direkam bersuara selama izin mikrofon diberikan. Bawaan mati
/// akan diam-diam mengubah isi bukti pada perangkat yang sudah dipakai —
/// pelanggan baru menyadarinya saat membuka video lama untuk sengketa dan
/// menemukannya bisu.
///
/// ⚠️ Sakelar ini hanya **menurunkan** kemampuan: bila izin mikrofon ditolak
/// sistem, video tetap bisu walaupun sakelarnya menyala (Bab 8.9 — video bisu
/// jauh lebih baik daripada tidak ada video).
@Riverpod(keepAlive: true)
class MicEnabled extends _$MicEnabled {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.prefMicEnabled) ?? true;
  }

  Future<void> set(bool value) async {
    state = AsyncData(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefMicEnabled, value);
  }
}

// ---------------------------------------------------------------------------
// Antrian unggah
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
UploadQueueRunner uploadQueueRunner(Ref ref) => UploadQueueRunner(
      db: ref.watch(localDbServiceProvider),
      storage: ref.watch(storageServiceProvider),
      videos: ref.watch(videoRepositoryProvider),
      connectivity: ref.watch(connectivityServiceProvider),
      notifications: ref.watch(notificationServiceProvider),
      allowCellular: () async {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getBool(AppConstants.prefUploadOnCellular) ?? false;
      },
    );

// ---------------------------------------------------------------------------
// Antrean watermark
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
VideoProcessingQueue videoProcessingQueue(Ref ref) {
  final queue = VideoProcessingQueue(
    db: ref.watch(localDbServiceProvider),
    processor: ref.watch(videoProcessorProvider),
    settings: () => ref.read(tenantSettingsProvider.future),
    // Video yang baru selesai diberi watermark langsung ditawarkan ke antrian
    // unggah; bila sinyalnya mati, penjalan itu sendiri yang memutuskan untuk
    // menunggu.
    onProcessed: () => ref.read(uploadQueueRunnerProvider).run(),
  );
  ref.onDispose(queue.dispose);
  return queue;
}

// ---------------------------------------------------------------------------
// Pemicu
// ---------------------------------------------------------------------------

/// Menyalakan pipeline saat aplikasi dibuka dan tiap kali jaringan kembali.
///
/// ⚠️ `connectivity_plus` hanya melaporkan **ada antarmuka jaringan**, bukan
/// bahwa internet benar-benar dapat dijangkau (Wi-Fi hotel dengan halaman
/// login tetap dilaporkan "terhubung"). Karena itu ini hanya pemicu; yang
/// menentukan berhasil atau tidak tetap percobaan unggahnya sendiri.
@Riverpod(keepAlive: true)
Stream<bool> uploadPipeline(Ref ref) {
  final connectivity = ref.watch(connectivityServiceProvider);
  final clock = ref.watch(serverClockProvider);
  final runner = ref.watch(uploadQueueRunnerProvider);
  final processing = ref.watch(videoProcessingQueueProvider);

  Future<void> wake(String sebab) async {
    _log.i('Pipeline dibangunkan: $sebab');
    // Waktu disinkronkan lebih dulu: video yang direkam sesudah ini akan
    // memakai hasilnya, dan sekarang justru saat sinyalnya ada.
    await clock.ensureSynced();
    // Rekaman yang belum sempat diberi watermark diselesaikan lebih dulu —
    // yang mentah tidak pernah boleh diunggah.
    processing.kick();
    await runner.run();
  }

  unawaited(wake('aplikasi dibuka'));

  // 🔴 Sinkronisasi ulang begitu sesi pengguna siap.
  //
  // Tanpa ini, `wake('aplikasi dibuka')` di atas berjalan pada build pertama
  // `KamelScanApp` — saat sesi Supabase belum pulih dari penyimpanan. Pada saat
  // itu `server_now()` dipanggil sebagai anon dan ditolak `42501`, dan satu-
  // satunya pemicu ulang yang tersisa adalah jaringan berganti. HP yang
  // menyala di satu jaringan yang sama sepanjang sesi tidak pernah memicunya,
  // sehingga titik acuan waktu tidak pernah terisi dan **seluruh** video sesi
  // itu keluar bertanda `time_verified = false`.
  //
  // Terjadi sungguhan pada uji 17 Agustus 2026: enam video, tidak satu pun
  // waktunya terverifikasi.
  ref.listen(sessionProvider, (previous, next) {
    if (previous?.value != null || next.value == null) return;
    unawaited(wake('sesi pengguna siap'));
  });

  return connectivity.onConnectivityChanged.map((connected) {
    if (connected) unawaited(wake('jaringan kembali'));
    return connected;
  });
}
