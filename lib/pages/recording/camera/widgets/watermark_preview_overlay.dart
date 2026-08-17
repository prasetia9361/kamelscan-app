import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/enums.dart';
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
    final isLeft = preview.position == WatermarkPosition.topLeft ||
        preview.position == WatermarkPosition.bottomLeft;

    // `buildLines` menyusun dari tepi ke dalam: indeks 0 paling dekat tepi.
    // Di bawah itu berarti indeks 0 paling bawah, jadi urutannya dibalik.
    final ordered =
        isTop ? preview.lines : preview.lines.reversed.toList(growable: false);

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: switch (preview.position) {
            WatermarkPosition.topLeft => Alignment.topLeft,
            WatermarkPosition.topRight => Alignment.topRight,
            WatermarkPosition.bottomLeft => Alignment.bottomLeft,
            WatermarkPosition.bottomRight => Alignment.bottomRight,
          },
          child: Padding(
            // Jarak bawah 116 dp menghindari tombol Berhenti yang bulat
            // (76 dp + 24 dp dari dasar layar) beserta sisa ruang bernapas;
            // jarak atas 88 dp menghindari palang judul beserta nomor resinya.
            padding:
                EdgeInsets.fromLTRB(12, isTop ? 88 : 12, 12, isTop ? 12 : 116),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < ordered.length; i++)
                  _WatermarkLine(
                    text: ordered[i],
                    opacity: preview.opacity,
                    // Baris resi (indeks 0 pada daftar aslinya) satu tingkat
                    // lebih besar, meniru `buildFilterChain`.
                    emphasised: isTop ? i == 0 : i == ordered.length - 1,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WatermarkLine extends StatelessWidget {
  const _WatermarkLine({
    required this.text,
    required this.opacity,
    required this.emphasised,
  });

  final String text;
  final double opacity;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      // Kotak gelap di belakang teks, sama seperti `box=1:boxcolor=black@…`
      // pada perintah FFmpeg. Di atas kardus terang, garis tepi saja tidak
      // cukup terbaca (Bab 8.5).
      color: Color.fromRGBO(0, 0, 0, opacity),
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: Colors.white,
          fontSize: emphasised ? 15 : 13,
          fontWeight: emphasised ? FontWeight.w700 : FontWeight.w500,
          height: 1.25,
        ),
      ),
    );
  }
}
