import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/services/auth_service.dart';
import 'core/services/camera_capability_check.dart';
import 'core/services/ffmpeg_capability_check.dart';
import 'core/services/local_db_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/supabase_service.dart';
import 'core/utils/logger.dart';
import 'core/utils/url_strategy.dart';
import 'core/workers/upload_worker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Membuang `#` dari alamat web (Bab 10.2). Dipanggil sebelum apa pun
  // menggambar: strategi yang diganti setelah rute pertama terbaca akan
  // membuat alamat awal dan alamat berikutnya memakai bentuk berbeda.
  // Tidak melakukan apa-apa di Android dan iOS.
  applyUrlStrategy();

  // Gagal cepat bila --dart-define belum diisi.
  //
  // ⚠️ Melempar begitu saja TIDAK cukup: exception sebelum `runApp()` membuat
  // aplikasi mati tanpa pernah menggambar apa pun, sehingga di perangkat hanya
  // terlihat **layar hitam polos** — persis kebingungan yang ingin dicegah.
  // Terjadi sungguhan pada 13 Agustus 2026 saat APK dibangun tanpa
  // `--dart-define-from-file`. Karena itu kegagalannya ditangkap dan
  // ditampilkan sebagai layar yang bisa dibaca.
  try {
    Env.assertConfigured();
  } on Object catch (e) {
    runApp(_ConfigErrorApp(message: '$e'));
    return;
  }

  if (Env.sentryEnabled) {
    await SentryFlutter.init(_configureSentry, appRunner: _bootstrap);
  } else {
    await _bootstrap();
  }
}

/// Layar terakhir sebelum menyerah: menjelaskan mengapa aplikasi tidak bisa
/// jalan. Sengaja tidak memakai tema, l10n, atau provider apa pun — semuanya
/// bergantung pada konfigurasi yang justru sedang bermasalah.
class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1B1B1F),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.settings_ethernet,
                    color: Color(0xFFFFB4AB), size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Konfigurasi belum lengkap',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFE6E1E5),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Aplikasi ini dibangun tanpa kredensial. Bangun ulang dengan:\n\n'
                  'flutter run --dart-define-from-file=env.dev.json',
                  style: TextStyle(
                    color: Color(0xFFB9B4BA),
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _bootstrap() async {
  const log = AppLogger('bootstrap');

  await SupabaseService.init();

  if (!kIsWeb) {
    // Antrian offline & notifikasi hanya ada di mobile (Bab 4.3).
    final localDb = createLocalDbService();
    await localDb.init();

    await createNotificationService().init();
    await createUploadWorker().register();
  }

  log.i('Bootstrap selesai (${Env.appEnv.name}, web=$kIsWeb)');

  runApp(const ProviderScope(child: KamelScanApp()));

  // Pemanasan `google_sign_in` (Bab 6.5).
  //
  // 🔴 Sengaja SESUDAH `runApp` dan tanpa ditunggu: ia tidak boleh menunda
  // layar pertama. Yang dihemat adalah waktu tunggu setelah tombol
  // *Lanjutkan dengan Google* ditekan — di v7, `initialize()` yang menyiapkan
  // Credential Manager, dan sebelumnya seluruh biayanya dibayar saat itu juga
  // sehingga pemilih akun terasa lama sekali muncul.
  unawaited(const AuthService().warmUpGoogleSignIn());

  // Verifikasi kemampuan FFmpeg (DEVIASI_LIBRARY.md butir D.4). Hanya di debug,
  // dijalankan setelah runApp agar tidak menahan tampilnya layar pertama, dan
  // dibatasi waktu agar tidak menggantung bila FFmpeg bermasalah.
  if (kDebugMode && !kIsWeb) {
    unawaited(_reportFfmpegCapabilities());
  }
}

/// Verifikasi kamera (Bab 8.1) — dipanggil manual dari layar setup, bukan saat
/// aplikasi dibuka.
///
/// Berbeda dari pemeriksaan FFmpeg: yang ini **menyalakan kamera dan merekam**
/// selama 6 detik. Menjalankannya otomatis di setiap peluncuran akan merebut
/// kamera dan meminta izin pada saat pengguna tidak meminta apa pun.
Future<void> reportCameraCapabilities() async {
  try {
    final report = await runCameraCapabilityCheck()
        .timeout(const Duration(seconds: 60));
    for (final line in report.render().split('\n')) {
      if (line.isNotEmpty) debugPrint(line);
    }
  } on Object catch (e) {
    debugPrint('KAMELSCAN_CAMERA_CHECK GAGAL DIJALANKAN: $e');
  }
}

Future<void> _reportFfmpegCapabilities() async {
  try {
    final report = await runFfmpegCapabilityCheck()
        .timeout(const Duration(seconds: 90));
    // Dicetak baris per baris: debugPrint memotong baris yang terlalu panjang.
    for (final line in report.render().split('\n')) {
      if (line.isNotEmpty) debugPrint(line);
    }
  } on Object catch (e) {
    debugPrint('KAMELSCAN_FFMPEG_CHECK GAGAL DIJALANKAN: $e');
  }
}

/// 🔴 `sendDefaultPii: false` — Sentry tidak boleh ikut mengirim email, alamat
/// IP, atau nomor resi pengguna ke servernya. Ini permintaan eksplisit pemilik
/// produk; jangan diubah tanpa persetujuan tertulis.
void _configureSentry(SentryFlutterOptions options) {
  options.dsn = Env.sentryDsn;
  options.environment = Env.appEnv.name;
  options.sendDefaultPii = false;
  options.tracesSampleRate = Env.sentryTracesSampleRate;
  // Screenshot dapat memuat nomor resi & nama pelanggan di layar.
  options.attachScreenshot = false;
  options.debug = Env.isDev;

  // Lapis kedua: buang sisa data pribadi yang mungkin terbawa breadcrumb.
  options.beforeSend = (event, hint) {
    return event.copyWith(user: null, serverName: null);
  };
}
