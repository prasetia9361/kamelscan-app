import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/watermark_command.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../recording_camera_view_model.dart';

/// Menampilkan isi watermark **selama merekam**, di tempat dan dengan bentuk
/// yang sama seperti yang akan terbakar ke video (Bab 8.5).
///
/// 🔴 Diminta Product Owner 17 Agustus 2026. Sebelumnya isi watermark baru
/// dapat dilihat setelah videonya jadi dan terunggah — terlambat untuk
/// menyadari nama toko yang salah, GPS yang tidak terbaca, atau waktu yang
/// belum terverifikasi. Sekarang packer melihatnya saat masih bisa berbuat
/// sesuatu.
///
/// ⚠️ **Ini pratinjau, bukan yang direkam.** Yang tergambar di berkas video
/// tetap dibakar FFmpeg sesudah rekaman ditutup; widget ini hanya menirunya.
/// Bila keduanya berbeda, yang salah adalah widget ini — barisnya sama-sama
/// datang dari `WatermarkCommand.buildLines`, jadi yang mungkin menyimpang
/// hanyalah tata letaknya.
///
/// 🔴 Berlangganan **hanya** pada `watermarkPreview`, sama seperti
/// `_TransitionCover`. Membangunnya dari seluruh keadaan layar berarti ia ikut
/// dibangun ulang tiap detak pencatat waktu — jebakan 14 di
/// `PROMPT_SESI_BARU.md`, yang dulu membuat pratinjau kamera patah-patah dan
/// gejalanya tampak seperti masalah kamera.
class WatermarkPreviewOverlay extends ConsumerWidget {
  const WatermarkPreviewOverlay({super.key, required this.provider});

  final RecordingCameraViewModelProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(provider.select((s) => s.watermarkPreview));
    if (preview == null) return const SizedBox.shrink();

    final isTop = preview.position == WatermarkPosition.topLeft ||
        preview.position == WatermarkPosition.topRight;

    final lines = preview.lines;
    if (lines.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
          child: Padding(
            // Jarak bawah 116 dp menghindari tombol Berhenti yang bulat
            // (76 dp + 24 dp dari dasar layar) beserta sisa ruang bernapas;
            // jarak atas 88 dp menghindari palang judul beserta pil keadaan.
            padding:
                EdgeInsets.fromLTRB(12, isTop ? 88 : 12, 12, isTop ? 12 : 116),
            child: _Plaque(lines: lines, opacity: preview.opacity),
          ),
        ),
      ),
    );
  }
}

/// Plakat bukti — tiruan bentuk yang dibakar `WatermarkCommand.buildFilterChain`.
///
/// Susunannya: garis aksen camel di tepi kiri, kepala
/// `KAMELSCAN · BUKTI VIDEO`, nomor resi besar bermonospace, lalu keterangan
/// kecil. Semuanya rata kiri di dalam satu bidang gelap.
///
/// ⚠️ Angka-angka di sini sengaja mengikuti konstanta di `WatermarkCommand`
/// (`resiFontSize`, `metaFontSize`, `accentWidth`, `accentGap`) supaya
/// keduanya bergerak bersama. Kalau salah satunya diubah tanpa yang lain,
/// packer melihat satu bentuk di layar dan mendapat bentuk lain di videonya.
class _Plaque extends StatelessWidget {
  const _Plaque({required this.lines, required this.opacity});

  final List<String> lines;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final resi = lines.first;
    final meta = lines.skip(1).toList(growable: false);

    return Container(
      width: double.infinity,
      color: Color.fromRGBO(0, 0, 0, opacity),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Garis aksen camel — satu-satunya warna merek pada bukti.
            Container(
              width: WatermarkCommand.accentWidth.toDouble(),
              color: const Color(0xFF9A5B00),
            ),
            SizedBox(width: WatermarkCommand.accentGap.toDouble()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 10, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      WatermarkCommand.plaqueKicker,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFD9A441),
                        fontFamily: AppFonts.sans,
                        fontSize: 8.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Bab 8.3.5 — nomor resi besar. Monospace supaya 0 dan O
                    // tidak tertukar saat bukti dibacakan lewat telepon.
                    Text(
                      resi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: AppFonts.mono,
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 3),
                    for (final line in meta)
                      Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: AppFonts.mono,
                          fontSize: 10,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
