import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kamelscan/core/theme/app_theme.dart';

/// Palang atas & bawah layar kamera (revisi tampilan, 1 September 2026).
///
/// Layar kamera tidak dapat dipasang utuh di dalam tes — ia memerlukan plugin
/// kamera dan sebuah perangkat. Yang diuji di sini adalah **bentuk barisnya**,
/// disalin persis dari `recording_camera_page.dart`, dengan isi kasus terburuk:
/// nomor resi yang sangat panjang dan nama mode yang panjang.
///
/// 🔴 Kenapa justru dua baris ini: keduanya memakai `Expanded` di sebelah
/// elemen berlebar tetap. Susunan itulah yang paling mudah meluber begitu
/// isinya lebih panjang daripada yang dibayangkan — dan di layar kamera,
/// meluber berarti packer kehilangan pencatat waktu atau tombol Berhenti di
/// tengah perekaman.
void main() {
  Future<void> pasang(WidgetTester tester, Widget anak, {double lebar = 402}) {
    tester.view.physicalSize = Size(lebar, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(child: anak),
        ),
      ),
    );
  }

  /// Bentuk baris atas: resi + pencatat waktu di kanan.
  Widget barisAtas(String resi) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resi,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'JetBrainsMono',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('00:05',
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'JetBrainsMono',
                      fontSize: 30)),
              SizedBox(height: 6),
              Text('SISA 55 DETIK',
                  style: TextStyle(color: Colors.white, fontSize: 9)),
            ],
          ),
        ],
      );

  /// Bentuk palang bawah: ANTREAN · ruang tombol · MODE.
  Widget palangBawah(String mode) => Row(
        children: [
          const Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('ANTREAN\n4 video',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ),
          // Ruang tombol Berhenti — ia lapisan Stack tersendiri, bukan anak
          // baris ini.
          const SizedBox(width: 96),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                mode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      );

  testWidgets('baris atas — resi normal tidak meluber', (tester) async {
    await pasang(tester, barisAtas('TKP9047163852AA'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('🔴 baris atas — resi sangat panjang tetap tidak meluber',
      (tester) async {
    // Resi marketplace panjangnya berbeda-beda dan sebagian memuat tanda
    // kurung; yang terpanjang yang pernah ditemui jauh di atas 15 karakter.
    await pasang(tester, barisAtas('JX9988776655443322110099887766'));

    expect(tester.takeException(), isNull);
    // Pencatat waktu wajib tetap tergambar — ia yang memberi tahu packer
    // berapa lama lagi perekaman berjalan.
    expect(find.text('00:05'), findsOneWidget);
  });

  testWidgets('🔴 baris atas pada 360 dp — layar tersempit yang wajar',
      (tester) async {
    await pasang(tester, barisAtas('JX9988776655443322110099887766'),
        lebar: 360);

    expect(tester.takeException(), isNull);
    expect(find.text('00:05'), findsOneWidget);
  });

  testWidgets('palang bawah — kedua kolom muat bersama ruang tombol',
      (tester) async {
    await pasang(tester, palangBawah('Input Manual'));

    expect(tester.takeException(), isNull);
    expect(find.text('Input Manual'), findsOneWidget);
  });

  testWidgets('🔴 palang bawah pada 360 dp tetap menyisakan ruang tombol',
      (tester) async {
    await pasang(tester, palangBawah('Input Manual'), lebar: 360);

    expect(tester.takeException(), isNull);

    // Ruang 96 dp di tengah adalah tempat tombol Berhenti berdiri. Kalau kedua
    // kolom memakannya, tombol itu akan bertumpuk dengan teks.
    final kiri = tester.getBottomRight(find.text('ANTREAN\n4 video')).dx;
    final kanan = tester.getTopLeft(find.text('Input Manual')).dx;
    expect(kanan - kiri, greaterThanOrEqualTo(96.0));
  });
}
