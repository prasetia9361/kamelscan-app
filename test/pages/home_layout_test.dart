import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kamelscan/pages/home/widgets/monitoring_band.dart';
import 'package:kamelscan/pages/home/widgets/record_action_row.dart';

/// 🔴 Beranda kosong sesudah revisi tampilan — 1 September 2026.
///
/// Product Owner mengirim tangkapan layar: di bawah PACKING/RETURN tidak ada
/// apa-apa. Petak token hilang menyisakan garis progresnya saja, dan seluruh
/// menu Rekam Packing/Return/Pembayaran/Tutorial tidak tergambar sama sekali.
///
/// Sebabnya satu baris, dan terulang di dua tempat:
///
/// ```dart
/// Row(crossAxisAlignment: CrossAxisAlignment.stretch, …)
/// ```
///
/// Kedua Row itu anak `ListView`, jadi tingginya **tidak terbatas**. `stretch`
/// memberi anaknya batasan tinggi setinggi Row-nya — dan tak hingga bukan
/// tinggi yang sah. `RenderFlex` melempar *"BoxConstraints forces an infinite
/// height"* saat tata letak, dan yang berhenti bukan cuma baris itu: seluruh
/// sisa `ListView` tidak pernah selesai diukur.
///
/// Versi lama tidak pernah kena karena `_MonitoringRow` dibungkus
/// `SizedBox(height: 138)`. Tinggi tetap itu dibuang bersama kartu lamanya,
/// tetapi `stretch`-nya ikut terbawa — pembatasnya hilang, permintaannya
/// tidak.
///
/// ⚠️ Kenapa tes ini ada, dan kenapa ia menguji **penanda sesudahnya**:
/// `flutter analyze` bersih dan 538 tes lulus saat cacat ini dikirim. Tidak
/// ada satu pun tes widget yang pernah menggambar Beranda, jadi tidak ada yang
/// bisa gagal. Galat tata letak juga tidak terlihat dari kode — hanya dari
/// menggambarnya pada layar berukuran nyata. Yang ditegaskan tiap tes di sini
/// adalah bahwa isi **sesudah** widgetnya masih tergambar, karena persis itu
/// yang hilang dari layar Product Owner.
void main() {
  /// 402 × 874 dp — ukuran yang dipakai desainer, di tengah rentang Android
  /// kelas menengah (Redmi Note 9 = 393 × 851, Pixel 8 = 412 × 892).
  void pakaiLayarHp(WidgetTester tester) {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget bungkus(Widget diuji) => MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              diuji,
              const SizedBox(height: 18),
              const Text('SESUDAHNYA'),
            ],
          ),
        ),
      );

  group('MonitoringBand di dalam ListView', () {
    testWidgets('tergambar tanpa galat tata letak', (tester) async {
      pakaiLayarHp(tester);
      await tester.pumpWidget(bungkus(_band()));

      expect(tester.takeException(), isNull);
    });

    testWidgets('🔴 isi sesudahnya tetap tergambar', (tester) async {
      pakaiLayarHp(tester);
      await tester.pumpWidget(bungkus(_band()));

      expect(find.text('SESUDAHNYA'), findsOneWidget);
    });

    testWidgets('ketiga angka terlihat sekaligus (Bab 9.2)', (tester) async {
      pakaiLayarHp(tester);
      await tester.pumpWidget(bungkus(_band()));

      // Bab 9.2 & keputusan Product Owner 18 Agustus 2026: packing, return,
      // dan saldo token wajib terlihat bersamaan tanpa gulir.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('73'), findsOneWidget);
    });
  });

  group('Kartu Rekam berdampingan di dalam ListView', () {
    Widget duaKartu({bool locked = false}) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: RecordActionCard(
                label: 'Rekam Packing',
                subtitle: 'Bukti sebelum dikirim',
                icon: Icons.inventory_2_rounded,
                startLabel: 'Mulai',
                background: const Color(0xFF0D5EA6),
                foreground: const Color(0xFFFFFFFF),
                locked: locked,
                lockedLabel: 'Token habis',
                onTap: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RecordActionCard(
                label: 'Rekam Return',
                subtitle: 'Bukti saat kembali',
                icon: Icons.move_to_inbox_rounded,
                startLabel: 'Mulai',
                background: const Color(0xFFEDE4F6),
                foreground: const Color(0xFF32164A),
                locked: locked,
                lockedLabel: 'Token habis',
                onTap: () {},
              ),
            ),
          ],
        );

    testWidgets('🔴 isi sesudahnya tetap tergambar', (tester) async {
      pakaiLayarHp(tester);
      await tester.pumpWidget(
        bungkus(IntrinsicHeight(child: duaKartu())),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('SESUDAHNYA'), findsOneWidget);
    });

    testWidgets('kedua kartu bertinggi sama', (tester) async {
      pakaiLayarHp(tester);
      await tester.pumpWidget(
        bungkus(IntrinsicHeight(child: duaKartu())),
      );

      // Itulah yang diminta `CrossAxisAlignment.stretch`, dan itu sebabnya
      // pembungkusnya `IntrinsicHeight` alih-alih dibuang begitu saja.
      final kartu = tester.widgetList<Material>(
        find.descendant(
          of: find.byType(RecordActionCard),
          matching: find.byType(Material),
        ),
      );
      expect(kartu, isNotEmpty);

      final tinggi = tester
          .getSize(find.byType(RecordActionCard).first)
          .height;
      final tinggiKedua =
          tester.getSize(find.byType(RecordActionCard).last).height;
      expect(tinggi, tinggiKedua);
    });

    testWidgets('Bab 7.3 — terkunci tetap tergambar dan dapat ditekan',
        (tester) async {
      pakaiLayarHp(tester);
      var ditekan = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: RecordActionCard(
                          label: 'Rekam Packing',
                          subtitle: 'Bukti sebelum dikirim',
                          icon: Icons.inventory_2_rounded,
                          startLabel: 'Mulai',
                          background: const Color(0xFF0D5EA6),
                          foreground: const Color(0xFFFFFFFF),
                          locked: true,
                          lockedLabel: 'Token habis',
                          onTap: () => ditekan++,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // Abu-abu, tetapi TETAP dapat ditekan — tombol mati tanpa penjelasan
      // adalah cara tercepat membuat pengguna mengira aplikasinya rusak.
      expect(find.text('Token habis'), findsOneWidget);
      await tester.tap(find.byType(RecordActionCard));
      expect(ditekan, 1);
    });
  });

  group('Baris Pembayaran & Tutorial', () {
    testWidgets('tergambar tanpa keterangan opsional', (tester) async {
      pakaiLayarHp(tester);
      await tester.pumpWidget(
        bungkus(
          RecordSecondaryTile(
            label: 'Pembayaran',
            icon: Icons.wallet_rounded,
            accent: const Color(0xFF1E7145),
            onTap: () {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Pembayaran'), findsOneWidget);
      expect(find.text('SESUDAHNYA'), findsOneWidget);
    });
  });
}

MonitoringBand _band() => MonitoringBand(
      packingLabel: 'Packing',
      packingCount: 1,
      packingColor: const Color(0xFF0D5EA6),
      packingBackground: const Color(0xFFD6E6F7),
      returnLabel: 'Return',
      returnCount: 0,
      returnColor: const Color(0xFF5B2C87),
      returnBackground: const Color(0xFFEDE4F6),
      tokenLabel: 'Saldo token',
      tokenValue: 73,
      tokenColor: const Color(0xFF1E7145),
      tokenBackground: const Color(0xFFDDF0E6),
      tokenTotal: 100,
      tokenRatio: 0.73,
      tokenMeta: 'Sisa 73%',
      numberFormatter: (v) => '$v',
    );
