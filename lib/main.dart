import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/services/ffmpeg_capability_check.dart';
import 'core/services/ffmpeg_check_overlay.dart';
import 'core/services/local_db_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/supabase_service.dart';
import 'core/utils/logger.dart';
import 'core/workers/upload_worker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Gagal cepat bila --dart-define belum diisi. Layar putih tanpa penjelasan
  // di tangan pengguna jauh lebih mahal daripada crash di terminal.
  Env.assertConfigured();

  if (Env.sentryEnabled) {
    await SentryFlutter.init(_configureSentry, appRunner: _bootstrap);
  } else {
    await _bootstrap();
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

  // Verifikasi kemampuan FFmpeg (DEVIASI_LIBRARY.md butir D.4). Hanya di debug,
  // dijalankan setelah runApp agar tidak menahan tampilnya layar pertama, dan
  // dibatasi waktu agar tidak menggantung bila FFmpeg bermasalah.
  if (kDebugMode && !kIsWeb) {
    unawaited(_reportFfmpegCapabilities());
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
    // Tampilkan juga di layar, agar verifikasi bisa dilakukan tanpa kabel USB.
    ffmpegCheckResult.value = report;
  } on Object catch (e) {
    debugPrint('KAMELSCAN_FFMPEG_CHECK GAGAL DIJALANKAN: $e');
    ffmpegCheckResult.value = FfmpegCheckReport([
      FfmpegCheckItem(
        name: 'Pemeriksaan gagal dijalankan',
        passed: false,
        detail: '$e',
      ),
    ]);
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
