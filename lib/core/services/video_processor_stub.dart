import '../models/app_settings.dart';
import '../utils/app_failure.dart';
import '../utils/result.dart';
import 'video_processor.dart';

/// Implementasi Web. Web **tidak merekam** (Bab 1.3 poin 5), jadi tidak ada
/// video yang perlu diproses di sini.
///
/// Kelas ini sengaja tidak melempar `UnsupportedError` pada jalur normal —
/// ia mengembalikan [AppFailure] agar bila ada layar yang keliru memanggilnya,
/// aplikasi web menampilkan pesan yang benar alih-alih layar putih.
class WebVideoProcessor implements VideoProcessor {
  const WebVideoProcessor();

  @override
  bool get isSupported => false;

  @override
  Future<Result<ProcessedVideo>> applyWatermark({
    required String inputPath,
    required String outputPath,
    required WatermarkData data,
    required TenantSettings settings,
  }) async =>
      const Result.err(_unsupported);

  @override
  Future<Result<String>> generateThumbnail({
    required String videoPath,
    required String outputPath,
  }) async =>
      const Result.err(_unsupported);

  @override
  Future<void> cancelAll() async {}

  static const AppFailure _unsupported = AppFailure(
    kind: FailureKind.unknown,
    messageKey: 'webRecordingUnavailable',
    debugMessage: 'VideoProcessor tidak tersedia di Flutter Web.',
  );
}

VideoProcessor createPlatformVideoProcessor() => const WebVideoProcessor();
