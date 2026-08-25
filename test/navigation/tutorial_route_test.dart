import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kamelscan/navigation/route_names.dart';

/// Alamat Tutorial — cacat 25 Agustus 2026.
///
/// Beranda membuka `'/tutorial'` sementara rutenya terdaftar sebagai **anak**
/// dari `/home`. GoRouter selalu menyambung alamat anak ke induknya, tanpa
/// peduli anaknya diawali garis miring atau tidak (`path_utils.dart:108`),
/// sehingga alamat sebenarnya `/home/tutorial`. Yang menekan menunya mendarat
/// di layar "halaman tidak ditemukan".
///
/// 🔴 Tidak ada yang menangkapnya: bukan `analyze`, bukan 307 tes yang ada.
/// Keduanya melihat dua konstanta `String` yang sah-sah saja. Yang salah hanya
/// terlihat bila alamatnya benar-benar dicocokkan ke daftar rute.
///
/// Tes pertama di bawah mengunci perilaku GoRouter itu sendiri. Bila suatu
/// hari ia berubah — misalnya alamat anak berawalan `/` mulai dianggap
/// mutlak — tes ini yang memberi tahu, sebelum ada yang menyederhanakan
/// [Routes.homeTutorial] kembali menjadi `'/tutorial'`.
void main() {
  /// Router seadanya dengan bentuk susunan yang sama seperti aslinya:
  /// Tutorial sebagai anak dari Beranda.
  GoRouter buatRouter() => GoRouter(
        initialLocation: Routes.home,
        errorBuilder: (_, _) => const Text('tidak ditemukan'),
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (_, _) => const Text('beranda'),
            routes: [
              GoRoute(
                path: 'tutorial',
                builder: (_, _) => const Text('tutorial'),
              ),
            ],
          ),
        ],
      );

  Future<void> buka(WidgetTester tester, String alamat) async {
    final router = buatRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go(alamat);
    await tester.pumpAndSettle();
  }

  group('Alamat anak selalu disambung ke induknya', () {
    testWidgets('"/home/tutorial" membuka Tutorial', (tester) async {
      await buka(tester, Routes.homeTutorial);
      expect(find.text('tutorial'), findsOneWidget);
    });

    testWidgets('"/tutorial" mendarat di halaman tidak ditemukan',
        (tester) async {
      // Inilah cacatnya, dibiarkan hidup sebagai bukti. Kalau baris ini suatu
      // hari gagal, berarti GoRouter berubah dan `Routes.homeTutorial` boleh
      // ditinjau ulang — sampai saat itu, jangan.
      await buka(tester, Routes.tutorial);
      expect(find.text('tidak ditemukan'), findsOneWidget);
    });
  });

  group('Kedua konstantanya sengaja berbeda', () {
    test('Tutorial di HP berada di bawah Beranda', () {
      expect(Routes.homeTutorial, startsWith('${Routes.home}/'));
    });

    test('Tutorial di web berdiri di akar, sesuai Bab 10.3', () {
      expect(Routes.tutorial, '/tutorial');
      expect(Routes.homeTutorial, isNot(Routes.tutorial));
    });
  });
}
