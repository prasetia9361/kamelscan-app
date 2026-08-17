import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import '../config/app_constants.dart';
import '../domain/watermark_command.dart';
import '../models/app_settings.dart';
import '../utils/app_failure.dart';
import '../utils/logger.dart';
import '../utils/result.dart';
import 'video_processor.dart';

/// Implementasi Android/iOS di atas FFmpegKit.
///
/// ⚠️ Rincian filter, bitrate, dan urutan langkah pipeline ditetapkan di
/// **Bab 8**. Yang sudah dikunci di sini adalah hal-hal yang sudah diputuskan
/// pada Bab 0–4: resolusi 480p (Bab 1.3 poin 3) dan isi watermark
/// (Bab 0.2 poin 6).
class MobileVideoProcessor implements VideoProcessor {
  MobileVideoProcessor();

  final AppLogger _log = const AppLogger('VideoProcessor');

  @override
  bool get isSupported => true;

  @override
  Future<Result<ProcessedVideo>> applyWatermark({
    required String inputPath,
    required String outputPath,
    required WatermarkData data,
    required TenantSettings settings,
  }) async {
    try {
      final input = File(inputPath);
      // Varian async disengaja: pemeriksaan ini berjalan tepat sebelum FFmpeg
      // dijalankan dan tidak boleh memblokir isolate UI.
      // ignore: avoid_slow_async_io
      if (!await input.exists()) {
        return Result.err(
          AppFailure.storage('Berkas sumber tidak ditemukan: $inputPath'),
        );
      }

      // 🔴 Wajib: tanpa fontfile, drawtext GAGAL. Terverifikasi di perangkat
      // (Redmi Note 9, 12 Agustus 2026) — lihat catatan pada [_resolveFontFile].
      final fontFile = await _resolveFontFile();
      if (fontFile == null) {
        return const Result.err(
          AppFailure(
            kind: FailureKind.storage,
            messageKey: 'errorWatermarkFontMissing',
            debugMessage: 'Tidak ada berkas font yang dapat dipakai drawtext',
          ),
        );
      }

      final command = _buildCommand(
        inputPath: inputPath,
        outputPath: outputPath,
        data: data,
        settings: settings,
        fontFile: fontFile,
      );

      final session = await FFmpegKit.execute(command);
      final code = await session.getReturnCode();

      if (!ReturnCode.isSuccess(code)) {
        final logs = await session.getAllLogsAsString();
        _log.e('FFmpeg gagal (${code?.getValue()})', logs);
        return Result.err(
          AppFailure.storage('FFmpeg keluar dengan kode ${code?.getValue()}'),
        );
      }

      final output = File(outputPath);
      final size = await output.length();

      return Result.ok(
        ProcessedVideo(
          path: outputPath,
          sizeBytes: size,
          durationSeconds: await _probeDurationSeconds(outputPath),
        ),
      );
    } on Object catch (e, s) {
      _log.e('applyWatermark gagal', e, s);
      return Result.err(AppFailure.storage(e, s));
    }
  }

  @override
  Future<Result<String>> generateThumbnail({
    required String videoPath,
    required String outputPath,
  }) async {
    try {
      final session = await FFmpegKit.execute(
        '-y -i ${_q(videoPath)} -ss 00:00:01 -vframes 1 '
        '-vf scale=-2:${AppConstants.recordingHeightPx} ${_q(outputPath)}',
      );
      final code = await session.getReturnCode();
      if (!ReturnCode.isSuccess(code)) {
        return Result.err(AppFailure.storage('Gagal membuat thumbnail'));
      }
      return Result.ok(outputPath);
    } on Object catch (e, s) {
      return Result.err(AppFailure.storage(e, s));
    }
  }

  @override
  Future<void> cancelAll() => FFmpegKit.cancel();

  // ---------------------------------------------------------------------

  /// Cache hasil pencarian font agar tidak menyentuh disk tiap perekaman.
  static String? _cachedFontFile;

  /// Berkas font untuk `drawtext`.
  ///
  /// 🔴 **Ini bukan pengaturan opsional.** Diverifikasi di Redmi Note 9
  /// (12 Agustus 2026) memakai `runFfmpegCapabilityCheck`:
  ///
  /// ```
  /// GAGAL  Render drawtext tanpa fontfile — kode 1 — Conversion failed!
  /// LULUS  Render drawtext dengan fontfile
  /// FONT DIPAKAI: /system/fonts/Roboto-Regular.ttf
  /// ```
  ///
  /// FFmpeg pada `ffmpeg_kit_flutter_new` dibangun **tanpa fontconfig**,
  /// sehingga `drawtext` tidak punya font bawaan dan menolak berjalan bila
  /// `fontfile` tidak diberikan.
  ///
  /// ⚠️ **Sisa pekerjaan Bab 8:** bundel satu berkas TTF sendiri di
  /// `assets/fonts/` dan pakai itu sebagai pilihan pertama. Bergantung pada
  /// font sistem berisiko dua hal: ROM pabrikan (khususnya ROM Cina) kadang
  /// mengganti atau menghapus Roboto, dan bentuk huruf yang berbeda-beda antar
  /// perangkat membuat watermark tidak seragam — padahal video ini dipakai
  /// sebagai bukti sengketa. Daftar di bawah adalah jaring pengaman, bukan
  /// solusi akhir.
  static const List<String> _systemFontCandidates = [
    '/system/fonts/Roboto-Regular.ttf',
    '/system/fonts/NotoSans-Regular.ttf',
    '/system/fonts/DroidSans.ttf',
    '/system/fonts/RobotoStatic-Regular.ttf',
    '/System/Library/Fonts/Helvetica.ttc', // iOS
  ];

  Future<String?> _resolveFontFile() async {
    final cached = _cachedFontFile;
    if (cached != null) return cached;

    for (final path in _systemFontCandidates) {
      // ignore: avoid_slow_async_io
      if (await File(path).exists()) {
        _cachedFontFile = path;
        _log.i('Font watermark: $path');
        return path;
      }
    }

    _log.e('Tidak ada font sistem yang cocok untuk drawtext');
    return null;
  }

  /// Susun perintah FFmpeg lewat [WatermarkCommand].
  ///
  /// ⚠️ Penyusunan string TIDAK dilakukan di sini. Berkas ini mengimpor
  /// FFmpeg, sehingga apa pun yang ditulis di dalamnya tidak dapat diuji di
  /// komputer. Bab 8.5 menyebut escape `:` sebagai penyebab kegagalan ffmpeg
  /// paling sering — aturan serawan itu harus berada di tempat yang teruji,
  /// yaitu `core/domain/watermark_command.dart`.
  String _buildCommand({
    required String inputPath,
    required String outputPath,
    required WatermarkData data,
    required TenantSettings settings,
    required String fontFile,
  }) {
    final lines = <String>[
      'RESI: ${data.resiCode}',
      WatermarkCommand.formatStamp(
        data.serverTime,
        timeVerified: data.timeVerified,
      ),
      data.shopName,
      if (settings.showGpsOnWatermark)
        data.coordinates == null
            ? 'Lokasi tidak tersedia'
            : 'GPS: ${data.coordinates}',
    ];

    // TODO(Bab 8.5): tier Pro menempelkan logo toko lewat `-i logo` + filter
    // `overlay`. `data.logoPath` sengaja belum dipakai agar tidak ada jalur
    // setengah jadi yang diam-diam mengabaikan logo pelanggan berbayar.
    final filterChain = WatermarkCommand.buildFilterChain(
      lines: lines,
      fontFile: fontFile,
      position: settings.watermarkPosition,
      heightPx: AppConstants.recordingHeightPx,
      boxOpacity: settings.watermarkOpacity.clamp(0.0, 1.0),
    );

    return WatermarkCommand.build(
      inputPath: inputPath,
      outputPath: outputPath,
      filterChain: filterChain,
      metadataComment: WatermarkCommand.buildMetadataComment(
        resiCode: data.resiCode,
        serverTime: data.serverTime,
        shopId: data.shopId,
        lat: data.lat,
        lng: data.lng,
        timeVerified: data.timeVerified,
      ),
    );
  }

  Future<int> _probeDurationSeconds(String path) async {
    try {
      final info = await FFprobeKit.getMediaInformation(path);
      final raw = info.getMediaInformation()?.getDuration();
      final value = double.tryParse(raw ?? '');
      return value?.round() ?? 0;
    } on Object {
      return 0;
    }
  }

  /// Pembungkus jalur berkas. Sama dengan `WatermarkCommand.quote`, dipakai
  /// oleh perintah thumbnail yang tidak melewati penyusun watermark.
  String _q(String path) => WatermarkCommand.quote(path);
}

VideoProcessor createPlatformVideoProcessor() => MobileVideoProcessor();
