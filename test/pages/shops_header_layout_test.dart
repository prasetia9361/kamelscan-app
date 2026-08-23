import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/theme/app_theme.dart';

/// Kepala halaman Toko (Bab 9.5) pada lebar layar Redmi Note 9.
///
/// **Cacat yang dilaporkan Product Owner 19 Agustus 2026:** judul "Toko Saya"
/// tergambar menurun satu huruf per baris, dan daftarnya tidak terlihat sama
/// sekali.
///
/// 🔴 Sebabnya ada di **tema**, bukan di susunan widgetnya. `filledButtonTheme`
/// memakai `minimumSize: Size.fromHeight(...)`, dan `Size.fromHeight` berarti
/// lebar minimum **tak terhingga**:
///
/// ```
/// BoxConstraints forces an infinite width.
/// BoxConstraints(w=Infinity, 52.0<=h<=Infinity)
/// ```
///
/// Itu disengaja — tombol utama seperti *Simpan* dan *Mulai* memang harus
/// selebar layar. Tetapi menaruh tombol seperti itu di dalam `Row` membuatnya
/// menuntut seluruh lebar, dan `Expanded` di sebelahnya tidak kebagian apa pun.
///
/// ⚠️ Percobaan pertama tes ini memakai tema bawaan Flutter dan **lulus**,
/// sehingga sempat menyimpulkan susunannya baik-baik saja. Tes tata letak yang
/// tidak memakai `AppTheme` tidak membuktikan apa pun tentang aplikasi ini.
void main() {
  /// Redmi Note 9 pada kerapatan yang dipakai: ± 393 x 873 dp.
  const ukuranLayar = Size(393, 873);

  Widget bungkus(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: SafeArea(child: child)),
      );

  Future<void> pasang(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = ukuranLayar;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(bungkus(widget));
  }

  group('Kepala halaman Toko — bentuk bertumpuk yang dipakai sekarang', () {
    /// Salinan susunan `ShopsPage`: judul, keterangan, lalu tombol di bawahnya.
    Widget kepala() => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Toko Saya', key: Key('judul')),
                  const SizedBox(height: 4),
                  const Text(
                    'Kelola toko dan marketplace tempat Anda berjualan.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    key: const Key('tambah'),
                    onPressed: () {},
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Tambah Toko'),
                  ),
                ],
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
        );

    testWidgets('tidak melempar galat tata letak apa pun', (tester) async {
      await pasang(tester, kepala());
      expect(tester.takeException(), isNull);
    });

    testWidgets('judul tergambar satu baris, bukan menurun per huruf',
        (tester) async {
      await pasang(tester, kepala());

      // ⚠️ Yang diukur **tinggi**, bukan lebar. `Text` di dalam `Column`
      // menyusut ke lebar tulisannya sendiri, jadi lebarnya tidak memberi tahu
      // apa pun tentang ruang yang tersedia. Tingginya yang berbicara: "Toko
      // Saya" sebaris ± 30 dp, sedangkan yang menurun satu huruf per baris
      // menjadi sembilan baris — ratusan dp.
      expect(
        tester.getSize(find.byKey(const Key('judul'))).height,
        lessThan(60),
      );
    });

    testWidgets('tombol Tambah Toko selebar layar dan mudah ditekan',
        (tester) async {
      await pasang(tester, kepala());

      final tombol = tester.getSize(find.byKey(const Key('tambah')));
      expect(tombol.width, greaterThan(300));
      // Bab 9.10 — ukuran sentuh minimum 48 dp; gudang sering dioperasikan
      // dengan sarung tangan.
      expect(tombol.height, greaterThanOrEqualTo(48));
    });
  });

  group('Dua tombol yang keduanya dibungkus Expanded tetap aman', () {
    testWidgets('halaman detail video: Unduh + Tautan Publik berdampingan',
        (tester) async {
      await pasang(
        tester,
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Unduh Video'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  key: const Key('tautan'),
                  onPressed: () {},
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Tautan Publik'),
                ),
              ),
            ),
          ],
        ),
      );

      // Keduanya `Expanded`, jadi lebarnya ditentukan induknya — bukan diminta
      // sendiri oleh tombol. Ini bentuk yang kebal terhadap jebakan di atas,
      // dan itulah sebabnya tombol di halaman detail video tidak ikut runtuh.
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const Key('tautan'))).width,
        greaterThan(120),
      );
    });
  });
}
