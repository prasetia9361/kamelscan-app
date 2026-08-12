import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ffmpeg_capability_check.dart';

/// Hasil pemeriksaan FFmpeg terakhir, diisi oleh `main.dart` setelah
/// [runFfmpegCapabilityCheck] selesai.
///
/// ⚠️ **Alat bantu debug, bukan bagian produk.** Seluruh berkas ini hanya aktif
/// pada `kDebugMode` dan wajib dihapus begitu butir D.4 di `DEVIASI_LIBRARY.md`
/// dinyatakan tuntas.
final ValueNotifier<FfmpegCheckReport?> ffmpegCheckResult =
    ValueNotifier<FfmpegCheckReport?>(null);

/// Membungkus aplikasi dan menampilkan laporan FFmpeg di atasnya saat debug.
///
/// Alasan ditampilkan di layar, bukan hanya di log: verifikasi ini harus bisa
/// dilakukan tanpa kabel USB — cukup pasang APK, buka aplikasi, foto layarnya.
class FfmpegCheckOverlay extends StatelessWidget {
  const FfmpegCheckOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;

    return Stack(
      children: [
        child,
        ValueListenableBuilder<FfmpegCheckReport?>(
          valueListenable: ffmpegCheckResult,
          builder: (context, report, _) {
            if (report == null) return const SizedBox.shrink();
            return _ReportSheet(
              report: report,
              onClose: () => ffmpegCheckResult.value = null,
            );
          },
        ),
      ],
    );
  }
}

class _ReportSheet extends StatelessWidget {
  const _ReportSheet({required this.report, required this.onClose});

  final FfmpegCheckReport report;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ok = report.allPassed;

    return Material(
      color: Colors.black.withValues(alpha: 0.88),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    ok ? Icons.check_circle : Icons.error,
                    color: ok ? Colors.greenAccent : Colors.redAccent,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Diagnostik FFmpeg',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Tutup',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                ok
                    ? 'Semua syarat watermark Bab 8 terpenuhi.'
                    : 'Ada syarat yang tidak terpenuhi — kirim layar ini ke programmer.',
                style: TextStyle(
                  color: ok ? Colors.greenAccent : Colors.orangeAccent,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    report.render(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: report.render()),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Salin hasil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
