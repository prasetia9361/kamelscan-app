import 'ffmpeg_capability_check_stub.dart'
    if (dart.library.io) 'ffmpeg_capability_check_mobile.dart';

/// Hasil satu butir pemeriksaan kemampuan FFmpeg.
class FfmpegCheckItem {
  const FfmpegCheckItem({
    required this.name,
    required this.passed,
    this.detail,
  });

  final String name;
  final bool passed;
  final String? detail;

  @override
  String toString() =>
      '${passed ? 'LULUS' : 'GAGAL'}  $name${detail == null ? '' : ' — $detail'}';
}

class FfmpegCheckReport {
  const FfmpegCheckReport(this.items, {this.fontFileUsed});

  final List<FfmpegCheckItem> items;

  /// Berkas font yang akhirnya berhasil dipakai `drawtext`, bila ada.
  final String? fontFileUsed;

  bool get allPassed => items.every((i) => i.passed);

  String render() {
    final b = StringBuffer()
      ..writeln('===== KAMELSCAN_FFMPEG_CHECK MULAI =====');
    for (final i in items) {
      b.writeln(i.toString());
    }
    if (fontFileUsed != null) {
      b.writeln('FONT DIPAKAI: $fontFileUsed');
    }
    b
      ..writeln('KESIMPULAN: ${allPassed ? 'SEMUA LULUS' : 'ADA YANG GAGAL'}')
      ..writeln('===== KAMELSCAN_FFMPEG_CHECK SELESAI =====');
    return b.toString();
  }
}

/// Verifikasi bahwa build FFmpeg yang terpasang benar-benar menyediakan
/// `drawtext` dan `libx264` — dua syarat mutlak pipeline watermark Bab 8.
///
/// Ini menjawab butir D.4 di `DEVIASI_LIBRARY.md`. Bab 4.3 mewajibkan varian
/// *min-gpl*; karena paket aslinya ditarik dari pub.dev dan diganti
/// `ffmpeg_kit_flutter_new`, klaim itu harus dibuktikan di perangkat asli,
/// bukan diasumsikan.
Future<FfmpegCheckReport> runFfmpegCapabilityCheck() =>
    runPlatformFfmpegCapabilityCheck();
