import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Menu bawah menampilkan halaman menu lain — laporan Product Owner
/// 5 September 2026.
///
/// > *"saat saya klik menu pembayaran kemudian klik riwayat lalu kembali ke
/// > beranda tampilannya masih pembayaran, harusnya ke beranda (berlaku untuk
/// > semua menu)"*
///
/// 🔴 Sebabnya bukan di Beranda dan bukan di Pembayaran, melainkan di **tempat
/// rutenya terdaftar**. Pembayaran hidup di cabang Akun, tetapi selalu dibuka
/// dengan `context.push` dari Beranda. Tes pertama di bawah membuktikan apa
/// yang sesungguhnya dilakukan GoRouter dalam keadaan itu, dan jawabannya
/// tidak dapat diterka dari membaca kodenya:
///
///   - halamannya masuk ke tumpukan cabang yang **sedang terbuka** (Beranda),
///     bukan ke cabang pemiliknya;
///   - `currentIndex` tetap 0, sehingga menu bawah tetap menyorot Beranda
///     selagi yang tergambar Pembayaran;
///   - tumpukan itu **disimpan** per cabang, jadi menekan Riwayat lalu Beranda
///     menampilkannya kembali apa adanya.
///
/// Dua perbaikan dikunci di sini, dan keduanya diperlukan:
///
///   1. `goBranch(..., initialLocation: true)` — menekan tombol menu selalu
///      kembali ke akar menunya. Ini yang berlaku untuk SEMUA menu.
///   2. Pembayaran didaftarkan **di luar** rangka pada HP, sehingga ia tidak
///      pernah lagi menumpang tumpukan cabang mana pun.
///
/// ⚠️ Rangkanya sengaja tiruan, bukan `MobileShell` yang asli: yang diuji
/// perilaku GoRouter terhadap bentuk susunan rute, dan itu tidak menuntut
/// sesi, Supabase, maupun tema. Yang harus sama hanyalah bentuk susunannya —
/// cabang Beranda, cabang Riwayat, dan cabang Akun yang menampung Pembayaran.
void main() {
  StatefulNavigationShell? shell;

  GoRouter buatRouter({required bool pembayaranDiLuarRangka}) => GoRouter(
        initialLocation: '/home',
        routes: [
          // Susunan HP sesudah perbaikan: rute tingkat atas, di luar rangka.
          if (pembayaranDiLuarRangka)
            GoRoute(
              path: '/payment',
              builder: (_, _) => const Text('pembayaran'),
            ),
          StatefulShellRoute.indexedStack(
            builder: (_, _, sh) {
              shell = sh;
              return Scaffold(body: sh);
            },
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/home',
                    builder: (_, _) => const Text('beranda'),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/history',
                    builder: (_, _) => const Text('riwayat'),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/account',
                    builder: (_, _) => const Text('akun'),
                  ),
                  // Susunan lama, dan susunan web sampai sekarang.
                  if (!pembayaranDiLuarRangka)
                    GoRoute(
                      path: '/payment',
                      builder: (_, _) => const Text('pembayaran'),
                    ),
                ],
              ),
            ],
          ),
        ],
      );

  /// Menekan salah satu tombol menu bawah.
  ///
  /// [reset] meniru nilai `initialLocation` yang dikirim `MobileShell`.
  Future<void> tekanMenu(
    WidgetTester tester,
    int cabang, {
    required bool reset,
  }) async {
    shell!.goBranch(cabang, initialLocation: reset);
    await tester.pumpAndSettle();
  }

  group('Cacatnya: halaman yang di-push mendarat di cabang yang salah', () {
    testWidgets('Pembayaran menumpuk di cabang Beranda, bukan cabang Akun',
        (tester) async {
      final router = buatRouter(pembayaranDiLuarRangka: false);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      unawaited(router.push('/payment'));
      await tester.pumpAndSettle();

      expect(find.text('pembayaran'), findsOneWidget);
      // 🔴 Inilah buktinya. Cabang Akun bernomor 2; kalau halamannya
      // benar-benar masuk ke cabang pemiliknya, angka ini 2. Ia tetap 0 —
      // menu bawah menyorot Beranda selagi yang tergambar Pembayaran.
      expect(shell!.currentIndex, 0);
    });

    testWidgets('🔴 laporan Product Owner, langkah demi langkah',
        (tester) async {
      final router = buatRouter(pembayaranDiLuarRangka: false);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // "klik menu pembayaran"
      unawaited(router.push('/payment'));
      await tester.pumpAndSettle();
      expect(find.text('pembayaran'), findsOneWidget);

      // "kemudian klik riwayat"
      await tekanMenu(tester, 1, reset: false);
      expect(find.text('riwayat'), findsOneWidget);

      // "lalu kembali ke beranda" — dan yang tergambar masih Pembayaran.
      await tekanMenu(tester, 0, reset: false);
      expect(
        find.text('pembayaran'),
        findsOneWidget,
        reason: 'Cacat yang dilaporkan, dibiarkan hidup sebagai bukti. Kalau '
            'baris ini gagal berarti GoRouter berubah, dan perbaikan di '
            'bawah boleh ditinjau ulang — sampai saat itu, jangan.',
      );
      expect(find.text('beranda'), findsNothing);
    });
  });

  group('Perbaikan 1 — tombol menu selalu kembali ke akar menunya', () {
    testWidgets('Beranda menampilkan Beranda, bukan tumpukan lamanya',
        (tester) async {
      final router = buatRouter(pembayaranDiLuarRangka: false);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      unawaited(router.push('/payment'));
      await tester.pumpAndSettle();
      await tekanMenu(tester, 1, reset: true);

      await tekanMenu(tester, 0, reset: true);

      expect(find.text('beranda'), findsOneWidget);
      expect(find.text('pembayaran'), findsNothing);
    });

    testWidgets('berlaku untuk semua menu, bukan hanya Beranda',
        (tester) async {
      final router = buatRouter(pembayaranDiLuarRangka: false);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Kali ini tumpukannya ditinggalkan di cabang Riwayat.
      await tekanMenu(tester, 1, reset: true);
      unawaited(router.push('/payment'));
      await tester.pumpAndSettle();
      expect(find.text('pembayaran'), findsOneWidget);

      await tekanMenu(tester, 0, reset: true);
      await tekanMenu(tester, 1, reset: true);

      expect(find.text('riwayat'), findsOneWidget);
      expect(find.text('pembayaran'), findsNothing);
    });
  });

  group('Perbaikan 2 — di HP Pembayaran berdiri di luar rangka', () {
    testWidgets('tidak menumpang tumpukan cabang mana pun', (tester) async {
      final router = buatRouter(pembayaranDiLuarRangka: true);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      unawaited(router.push('/payment'));
      await tester.pumpAndSettle();
      expect(find.text('pembayaran'), findsOneWidget);

      // Kembali satu ketukan, persis seperti halaman biasa — dan Beranda
      // kembali seperti semula tanpa perlu menekan tombol menu apa pun.
      router.pop<void>();
      await tester.pumpAndSettle();
      expect(find.text('beranda'), findsOneWidget);
      expect(find.text('pembayaran'), findsNothing);
    });

    testWidgets('cabang lain tetap bersih sesudah Pembayaran ditutup',
        (tester) async {
      final router = buatRouter(pembayaranDiLuarRangka: true);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      unawaited(router.push('/payment'));
      await tester.pumpAndSettle();
      router.pop<void>();
      await tester.pumpAndSettle();

      await tekanMenu(tester, 1, reset: false);
      expect(find.text('riwayat'), findsOneWidget);

      await tekanMenu(tester, 0, reset: false);
      expect(find.text('beranda'), findsOneWidget);
      expect(find.text('pembayaran'), findsNothing);
    });
  });
}
