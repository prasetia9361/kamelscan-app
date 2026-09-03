import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/theme/app_theme.dart';
import 'package:kamelscan/navigation/shells/kamel_nav_bar.dart';

/// Menu bawah pada ukuran huruf sistem BESAR.
///
/// 🔴 Cacat yang dijawab berkas ini hanya muncul pada perangkat yang
/// memperbesar hurufnya — dan itu sebabnya ia lolos: HP uji Product Owner
/// memakai ukuran normal.
///
/// `KamelNavBar` menggantikan `NavigationBar` bawaan Material (revisi tampilan
/// 31 Agustus 2026) dan mematok tinggi 58 dp. Ikon 25 + jarak 4 menyisakan
/// 29 dp untuk label. `labelSmall` 11 sp pada setelan sistem 200% tumbuh
/// menjadi sekitar 31 dp — meluber, dan garis kuning-hitam `RenderFlex`
/// terpampang di menu bawah pada SETIAP layar sekaligus.
///
/// `NavigationBar` yang digantikannya menjepit skala labelnya sendiri, jadi
/// cacat ini lahir bersama penggantinya.
///
/// ⚠️ `expect(tester.takeException(), isNull)` adalah baris yang menangkapnya.
/// Tanpa itu tesnya lulus sambil layarnya bergaris kuning-hitam (aturan 19
/// prompt serah terima).
void main() {
  const items = [
    KamelNavItem(
      label: 'Beranda',
      icon: Icons.cottage_outlined,
      activeIcon: Icons.cottage_rounded,
    ),
    KamelNavItem(
      label: 'Pengaturan',
      icon: Icons.tune_outlined,
      activeIcon: Icons.tune_rounded,
    ),
    KamelNavItem(
      label: 'Akun',
      icon: Icons.account_circle_outlined,
      activeIcon: Icons.account_circle_rounded,
    ),
  ];

  Future<void> pasang(WidgetTester tester, double skala) {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    return tester.pumpWidget(
      MaterialApp(
        // 🔴 Tema sungguhan, bukan bawaan Flutter. Percobaan pertama pada M.12
        // memakai tema bawaan dan LULUS, sehingga susunan yang rusak sempat
        // dinyatakan baik-baik saja (aturan 18).
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(skala)),
            child: Scaffold(
              bottomNavigationBar: KamelNavBar(
                items: items,
                currentIndex: 0,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('ukuran huruf normal tergambar tanpa galat', (tester) async {
    await pasang(tester, 1.0);
    expect(tester.takeException(), isNull);
    expect(find.text('Beranda'), findsOneWidget);
  });

  testWidgets('🔴 huruf sistem 200% TIDAK meluberkan menu bawah',
      (tester) async {
    // Nilai inilah yang merusak sebelum skalanya dijepit.
    await pasang(tester, 2.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('🔴 bahkan pada 300% — setelan aksesibilitas paling ekstrem',
      (tester) async {
    await pasang(tester, 3.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('labelnya tetap tergambar, bukan disembunyikan', (tester) async {
    // Menjepit skala BUKAN berarti membuang labelnya. Menu bawah tanpa tulisan
    // memaksa orang menghafal ikon — persis yang dihindari revisi tampilan.
    await pasang(tester, 2.0);
    for (final item in items) {
      expect(find.text(item.label), findsOneWidget, reason: item.label);
    }
  });

  testWidgets('🔴 label ikut membesar, hanya dibatasi', (tester) async {
    // Kalau skalanya dijepit ke 1.0, pembesaran huruf sistem tidak berguna
    // sama sekali bagi yang membutuhkannya.
    await pasang(tester, 1.0);
    final kecil = tester.getSize(find.text('Beranda')).height;

    await pasang(tester, 2.0);
    final besar = tester.getSize(find.text('Beranda')).height;

    expect(besar, greaterThan(kecil),
        reason: 'label tidak ikut membesar sama sekali');
  });
}
