import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'ffmpeg_capability_check.dart';

/// Kandidat berkas font untuk `drawtext`.
///
/// ⚠️ Ini jebakan klasik: `drawtext` **tidak punya font bawaan**. Di Android,
/// FFmpeg tanpa fontconfig akan menolak dengan
/// *"Cannot find a valid font for the family Sans"*. Karena itu pemeriksaan
/// dilakukan dua kali — tanpa `fontfile` dan dengan `fontfile` — supaya kita
/// tahu persis mana yang harus dipakai di Bab 8, bukan menebaknya nanti.
const List<String> _fontCandidates = [
  '/system/fonts/Roboto-Regular.ttf',
  '/system/fonts/DroidSans.ttf',
  '/system/fonts/NotoSans-Regular.ttf',
  '/System/Library/Fonts/Helvetica.ttc', // iOS
];

Future<FfmpegCheckReport> runPlatformFfmpegCapabilityCheck() async {
  final items = <FfmpegCheckItem>[];
  String? fontUsed;

  final tmp = await getTemporaryDirectory();
  final outPath = p.join(tmp.path, 'kamelscan_ffmpeg_check.mp4');

  // ---- 1. Apakah filter drawtext terdaftar di build ini? ----
  final filters = await _capture('-hide_banner -filters');
  final hasDrawText = filters.contains('drawtext');
  items.add(
    FfmpegCheckItem(
      name: 'Filter drawtext terdaftar',
      passed: hasDrawText,
      detail: hasDrawText ? null : 'Tidak ditemukan di keluaran `-filters`',
    ),
  );

  // ---- 2. Apakah encoder libx264 tersedia? ----
  final encoders = await _capture('-hide_banner -encoders');
  final hasX264 = encoders.contains('libx264');
  items.add(
    FfmpegCheckItem(
      name: 'Encoder libx264 tersedia',
      passed: hasX264,
      detail: hasX264 ? null : 'Tidak ditemukan di keluaran `-encoders`',
    ),
  );

  // ---- 3. Render sungguhan: drawtext TANPA fontfile ----
  final noFont = await _render(
    outPath: outPath,
    drawTextExtra: '',
  );
  items.add(
    FfmpegCheckItem(
      name: 'Render drawtext tanpa fontfile',
      passed: noFont.ok,
      detail: noFont.ok ? null : noFont.summary,
    ),
  );

  // ---- 4. Render sungguhan: drawtext DENGAN fontfile sistem ----
  if (!noFont.ok) {
    for (final font in _fontCandidates) {
      if (!File(font).existsSync()) continue;
      final withFont = await _render(
        outPath: outPath,
        drawTextExtra: ':fontfile=$font',
      );
      if (withFont.ok) {
        fontUsed = font;
        items.add(
          const FfmpegCheckItem(
            name: 'Render drawtext dengan fontfile',
            passed: true,
          ),
        );
        break;
      }
      items.add(
        FfmpegCheckItem(
          name: 'Render drawtext dengan fontfile ($font)',
          passed: false,
          detail: withFont.summary,
        ),
      );
    }
    if (fontUsed == null) {
      items.add(
        const FfmpegCheckItem(
          name: 'Font sistem yang dapat dipakai drawtext',
          passed: false,
          detail: 'Tidak ada kandidat font yang berhasil — '
              'perlu membundel TTF sendiri di assets/fonts',
        ),
      );
    }
  }

  // Bersihkan berkas uji agar tidak menumpuk di penyimpanan pengguna.
  try {
    final f = File(outPath);
    if (f.existsSync()) await f.delete();
  } on Object {
    // Kegagalan menghapus berkas sementara tidak boleh menggagalkan laporan.
  }

  return FfmpegCheckReport(items, fontFileUsed: fontUsed);
}

class _RenderResult {
  const _RenderResult(this.ok, this.summary);
  final bool ok;
  final String summary;
}

/// Bangun video uji 1 detik dari generator internal `testsrc`, tempel teks,
/// lalu encode dengan libx264. Tidak butuh berkas masukan apa pun.
Future<_RenderResult> _render({
  required String outPath,
  required String drawTextExtra,
}) async {
  final cmd = '-y -f lavfi -i testsrc=duration=1:size=320x240:rate=10 '
      '-vf "drawtext=text=\'KamelScan 0123456789\''
      ':fontsize=18:fontcolor=white:borderw=2:bordercolor=black'
      ':x=16:y=16$drawTextExtra" '
      '-c:v libx264 -preset ultrafast -t 1 "$outPath"';

  final session = await FFmpegKit.execute(cmd);
  final code = await session.getReturnCode();
  if (ReturnCode.isSuccess(code)) {
    final f = File(outPath);
    final size = f.existsSync() ? await f.length() : 0;
    if (size > 0) return _RenderResult(true, 'ok, $size byte');
    return const _RenderResult(false, 'keluar 0 tetapi berkas kosong');
  }

  final logs = await session.getAllLogsAsString() ?? '';
  // Ambil baris terakhir yang bermakna agar laporan tetap terbaca di logcat.
  final line = logs
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .lastWhere((l) => true, orElse: () => 'tanpa log');
  return _RenderResult(false, 'kode ${code?.getValue()} — $line');
}

Future<String> _capture(String command) async {
  try {
    final session = await FFmpegKit.execute(command);
    return (await session.getAllLogsAsString()) ?? '';
  } on Object catch (e) {
    return 'ERROR: $e';
  }
}
