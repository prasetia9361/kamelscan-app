import 'ffmpeg_capability_check.dart';

/// Web tidak punya FFmpeg. Pemeriksaan dilewati dengan jujur, bukan dipalsukan
/// menjadi "lulus".
Future<FfmpegCheckReport> runPlatformFfmpegCapabilityCheck() async {
  return const FfmpegCheckReport([
    FfmpegCheckItem(
      name: 'Platform mendukung FFmpeg',
      passed: false,
      detail: 'Web tidak merekam video, pemeriksaan tidak berlaku (Bab 4.3)',
    ),
  ]);
}
