import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/theme/app_theme.dart';

/// Kolom kode promo (Bab 9.8) pada lebar layar Redmi Note 9.
///
/// **Cacat yang terlihat di perangkat Product Owner 22 Agustus 2026:** kolom
/// kode promo tergencet habis. Yang tergambar hanya ikon label dan sepotong
/// garis vertikal — tanpa kolom teks, tanpa tombol *Terapkan*.
///
/// 🔴 Ini **pengulangan M.12**, di tempat baru dan oleh orang yang sudah
/// mencatat M.12. `filledButtonTheme` proyek ini memakai
/// `minimumSize: Size.fromHeight(...)`, dan `Size.fromHeight` berarti lebar
/// minimum **tak terhingga**. Tombol semacam itu di dalam `Row` melahap seluruh
/// lebar, dan `Expanded` di sebelahnya tidak kebagian apa pun.
///
/// ⚠️ Membungkus tombolnya dengan `SizedBox(height: ...)` **tidak** menolong —
/// itulah yang tertulis pada percobaan pertama. Yang merusak lebarnya, bukan
/// tingginya. Batasnya harus datang dari `Expanded`.
void main() {
  /// Redmi Note 9 pada kerapatan yang dipakai: ± 393 x 873 dp.
  const ukuranLayar = Size(393, 873);

  Future<void> pasang(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = ukuranLayar;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: SafeArea(child: widget)),
      ),
    );
  }

  /// Susunan yang dipakai `PromoField` sekarang: keduanya dibungkus `Expanded`.
  Widget bentukSekarang() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            flex: 3,
            child: TextField(
              key: Key('kode'),
              decoration: InputDecoration(
                labelText: 'Kode promo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_offer_outlined),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 58,
              child: FilledButton.tonal(
                key: const Key('terapkan'),
                onPressed: () {},
                child: const Text('Terapkan'),
              ),
            ),
          ),
        ],
      );

  group('Kolom promo dengan tema aplikasi sungguhan', () {
    testWidgets('tidak melempar galat tata letak apa pun', (tester) async {
      await pasang(tester, bentukSekarang());
      expect(tester.takeException(), isNull);
    });

    testWidgets('🔴 kolom kodenya benar-benar punya lebar', (tester) async {
      await pasang(tester, bentukSekarang());

      final lebar = tester.getSize(find.byKey(const Key('kode'))).width;

      // Inilah yang gagal sebelum perbaikan: lebarnya nol, sehingga di layar
      // hanya tersisa ikon dan garis pinggirnya.
      expect(lebar, greaterThan(150));
    });

    testWidgets('tombol Terapkan ikut tergambar dan cukup besar disentuh',
        (tester) async {
      await pasang(tester, bentukSekarang());

      final tombol = tester.getSize(find.byKey(const Key('terapkan')));

      expect(tombol.width, greaterThan(60));
      // Bab 9.10 — ukuran sentuh minimum 48 dp; gudang sering dioperasikan
      // dengan sarung tangan.
      expect(tombol.height, greaterThanOrEqualTo(48));
    });

    testWidgets('keduanya muat dalam satu baris tanpa meluber', (tester) async {
      await pasang(tester, bentukSekarang());

      final kode = tester.getSize(find.byKey(const Key('kode'))).width;
      final tombol = tester.getSize(find.byKey(const Key('terapkan'))).width;

      expect(kode + tombol + 10, lessThanOrEqualTo(ukuranLayar.width));
    });
  });

  group('Bentuk yang dulu rusak tetap dijaga sebagai peringatan', () {
    testWidgets('tombol TANPA Expanded menggencet kolom di sebelahnya',
        (tester) async {
      // Sengaja menegaskan perilaku yang SALAH. Bila suatu hari tema tombolnya
      // berubah dan bentuk ini tidak lagi merusak, tes ini gagal dan memberi
      // tahu bahwa alasan di balik `Expanded` tadi sudah tidak berlaku.
      await pasang(
        tester,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: TextField(
                key: Key('kode2'),
                decoration: InputDecoration(
                  labelText: 'Kode promo',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 58,
              child: FilledButton.tonal(
                onPressed: () {},
                child: const Text('Terapkan'),
              ),
            ),
          ],
        ),
      );

      // Entah ia melempar galat tata letak, atau kolomnya tergencet habis —
      // keduanya sama-sama membuktikan bentuk itu tidak layak dipakai.
      final galat = tester.takeException();
      if (galat == null) {
        expect(tester.getSize(find.byKey(const Key('kode2'))).width, 0);
      } else {
        expect(galat, isNotNull);
      }
    });
  });
}
