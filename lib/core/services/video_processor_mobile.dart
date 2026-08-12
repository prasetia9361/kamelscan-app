import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import '../config/app_constants.dart';
import '../models/app_settings.dart';
import '../models/enums.dart';
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

  /// Susun perintah FFmpeg: skala ke 480p + tempel teks watermark.
  ///
  /// Filter `drawtext` inilah alasan varian *min-gpl* diwajibkan di Bab 4.3 —
  /// dan alasan `ffmpeg_kit_flutter_new` harus diverifikasi menyertakannya
  /// (lihat DEVIASI_LIBRARY.md butir D.4).
  String _buildCommand({
    required String inputPath,
    required String outputPath,
    required WatermarkData data,
    required TenantSettings settings,
    required String fontFile,
  }) {
    final lines = <String>[
      data.resiCode,
      _formatServerTime(data.serverTime),
      data.shopName,
      if (settings.showGpsOnWatermark)
        data.coordinates ?? 'Lokasi tidak tersedia',
    ];

    final position = _positionExpression(settings.watermarkPosition);
    final alpha = settings.watermarkOpacity.clamp(0.0, 1.0);

    final drawTexts = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final text = _escapeDrawText(lines[i]);
      drawTexts.add(
        "drawtext=text='$text'"
        ':fontfile=$fontFile'
        ':fontsize=18'
        ':fontcolor=white@$alpha'
        ':borderw=2:bordercolor=black@$alpha'
        ':${position.x}'
        ':y=${position.yExpression(i, lines.length)}',
      );
    }

    // TODO(Bab 8.5): tier Pro menempelkan logo toko lewat `-i logo` + filter
    // `overlay`. `data.logoPath` sengaja belum dipakai di sini agar tidak ada
    // jalur setengah jadi yang diam-diam mengabaikan logo pelanggan berbayar.
    final filters = [
      'scale=-2:${AppConstants.recordingHeightPx}',
      ...drawTexts,
    ].join(',');

    return '-y -i ${_q(inputPath)} -vf "$filters" '
        '-c:v libx264 -preset veryfast -crf 28 -c:a aac -b:a 96k '
        '-movflags +faststart ${_q(outputPath)}';
  }

  _WatermarkAnchor _positionExpression(WatermarkPosition p) => switch (p) {
        WatermarkPosition.topLeft => const _WatermarkAnchor('x=16', top: true),
        WatermarkPosition.topRight =>
          const _WatermarkAnchor('x=w-tw-16', top: true),
        WatermarkPosition.bottomLeft =>
          const _WatermarkAnchor('x=16', top: false),
        WatermarkPosition.bottomRight =>
          const _WatermarkAnchor('x=w-tw-16', top: false),
      };

  /// Waktu server dalam format yang mudah dibaca petugas resolusi marketplace.
  String _formatServerTime(DateTime t) {
    final local = t.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}.${two(local.minute)}.${two(local.second)}';
  }

  /// `drawtext` memperlakukan `:`, `'`, `\`, dan `%` sebagai karakter khusus.
  String _escapeDrawText(String raw) => raw
      .replaceAll(r'\', r'\\')
      .replaceAll(':', r'\:')
      .replaceAll("'", r"\'")
      .replaceAll('%', r'\%');

  String _q(String path) => '"$path"';

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
}

class _WatermarkAnchor {
  const _WatermarkAnchor(this.x, {required this.top});

  final String x;
  final bool top;

  /// Baris ditumpuk ke bawah bila jangkar di atas, ke atas bila di bawah.
  String yExpression(int index, int total) {
    const lineHeight = 24;
    if (top) return '${16 + index * lineHeight}';
    final fromBottom = 16 + (total - 1 - index) * lineHeight;
    return 'h-th-$fromBottom';
  }
}

VideoProcessor createPlatformVideoProcessor() => MobileVideoProcessor();
