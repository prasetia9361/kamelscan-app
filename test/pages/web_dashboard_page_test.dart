import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/models/daily_stats.dart';
import 'package:kamelscan/core/theme/app_theme.dart';
import 'package:kamelscan/core/utils/app_failure.dart';
import 'package:kamelscan/core/widgets/app_state_views.dart';
import 'package:kamelscan/l10n/generated/app_localizations.dart';
import 'package:kamelscan/pages/web/dashboard/web_dashboard_page.dart';
import 'package:kamelscan/pages/web/dashboard/web_dashboard_view_model.dart';

/// Dasbor web (Bab 10.4) — empat kondisi Bab 3.4 dan dua lebar layar.
///
/// 🔴 Memakai `AppTheme` sungguhan. Percobaan pertama pada cacat M.12 memakai
/// tema bawaan Flutter dan **lulus**, sehingga susunan yang rusak sempat
/// dinyatakan baik-baik saja. Kepala halaman ini berisi judul dan
/// `SegmentedButton` bersebelahan — bentuk yang persis sama dengan yang sudah
/// dua kali meluber di proyek ini (M.12 dan M.17).
void main() {
  DailyStats contoh({
    int packing = 12,
    int retur = 3,
    int packingLalu = 10,
    int returLalu = 2,
    int hari = 3,
    int saldo = 800,
    int kuota = 1000,
    bool adaDompet = true,
    int menunggu = 0,
    Duration? umurTertua,
    List<int> token = const [4, 0, 6],
  }) =>
      DailyStats.fromJson({
        'days': hari,
        'start_date': '2026-08-24',
        'end_date': '2026-08-26',
        'series': [
          {'date': '2026-08-24', 'packing': 5, 'return': 1},
          {'date': '2026-08-25', 'packing': 0, 'return': 0},
          {'date': '2026-08-26', 'packing': 7, 'return': 2},
        ],
        'total': {'packing': packing, 'return': retur},
        'previous': {'packing': packingLalu, 'return': returLalu},
        'token_series': [
          for (var i = 0; i < token.length; i++)
            {'date': '2026-08-${24 + i}', 'used': token[i]},
        ],
        'pending': {
          'count': menunggu,
          'oldest_at': umurTertua == null
              ? null
              : DateTime.now().subtract(umurTertua).toIso8601String(),
        },
        if (adaDompet) 'wallet': {'balance': saldo, 'quota': kuota},
      });

  Future<void> pasang(
    WidgetTester tester, {
    required double lebar,
    DailyStats? stats,
    AppFailure? gagal,
    double tinggi = 1400,
  }) async {
    tester.view.physicalSize = Size(lebar, tinggi);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          webDashboardViewModelProvider
              .overrideWith(() => _VmPalsu(stats: stats, gagal: gagal)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('id'),
          supportedLocales: AppL10n.supportedLocales,
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: WebDashboardPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Kondisi berisi', () {
    testWidgets('empat kartu ringkasan sesuai rancangan desainer',
        (tester) async {
      await pasang(tester, lebar: 1400, stats: contoh());

      expect(find.text('Video Packing'), findsWidgets);
      expect(find.text('Video Return'), findsWidgets);

      // 🔴 Dua kartu terakhir MENYIMPANG dari Bab 10.4, dan itu disengaja:
      // dokumen meminta keempatnya membandingkan dengan periode sebelumnya,
      // sedangkan Token dan Menunggu Unggah adalah keadaan SAAT INI — angka
      // yang tidak punya "periode lalu" untuk dibandingkan.
      expect(find.text('Token Tersedia'), findsOneWidget);
      expect(find.text('Menunggu Unggah'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('grafiknya batang, bukan garis', (tester) async {
      await pasang(tester, lebar: 1400, stats: contoh());

      // Rancangan desainer memakai batang bertumpuk supaya packing dan retur
      // satu hari terbaca sebagai satu hari, bukan dua garis yang harus
      // dijumlahkan sendiri oleh pembacanya.
      expect(find.byType(BarChart), findsWidgets);
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('ringkasan total ditulis di bawah grafiknya', (tester) async {
      await pasang(tester, lebar: 1400, stats: contoh());

      expect(find.text('Total 3 hari: 15 video'), findsOneWidget);
      expect(find.text('(Packing 12 · Retur 3)'), findsOneWidget);
    });

    testWidgets('pemilih rentang punya pilihan Kustom', (tester) async {
      await pasang(tester, lebar: 1400, stats: contoh());

      expect(find.text('7 hari'), findsOneWidget);
      expect(find.text('90 hari'), findsOneWidget);
      expect(find.text('Kustom'), findsOneWidget);
    });
  });

  group('Kartu Token Tersedia', () {
    testWidgets('menulis perkiraan sisa hari pada laju sekarang',
        (tester) async {
      // 10 token terpakai dalam 3 hari = 3,33/hari. Saldo 800 -> 240 hari.
      await pasang(
        tester,
        lebar: 1400,
        stats: contoh(saldo: 800, token: [4, 0, 6]),
      );
      expect(find.textContaining('Cukup ± 240 hari'), findsOneWidget);
    });

    testWidgets('laju nol tidak menghasilkan "cukup ∞ hari"', (tester) async {
      await pasang(
        tester,
        lebar: 1400,
        stats: contoh(token: [0, 0, 0]),
      );
      expect(find.text('Belum cukup data untuk memperkirakan'), findsOneWidget);
    });

    testWidgets('🔴 kuota menipis mengubah KATA, bukan hanya warna',
        (tester) async {
      // Palet §7: makna tidak pernah disampaikan lewat warna saja. Bilah yang
      // berubah oranye tanpa satu kata pun adalah bentuk paling murni dari
      // pelanggaran itu.
      await pasang(tester, lebar: 1400, stats: contoh(saldo: 100));
      expect(find.text('Token menipis'), findsOneWidget);
    });

    testWidgets('saldo nol berkata habis, bukan menipis', (tester) async {
      await pasang(tester, lebar: 1400, stats: contoh(saldo: 0));
      expect(find.text('Token habis'), findsOneWidget);
    });

    testWidgets('dompet yang belum ada berbeda dari saldo nol', (tester) async {
      // Dua keadaan yang berbeda: yang pertama tidak boleh menyuruh Owner
      // membeli token yang sebenarnya sudah ia punya.
      await pasang(tester, lebar: 1400, stats: contoh(adaDompet: false));
      expect(find.text('Dompet token belum terbentuk'), findsOneWidget);
      expect(find.text('Token habis'), findsNothing);
    });
  });

  group('Kartu Menunggu Unggah', () {
    testWidgets('antrean kosong berkata begitu', (tester) async {
      await pasang(tester, lebar: 1400, stats: contoh(menunggu: 0));
      expect(find.text('Tidak ada yang menunggu'), findsOneWidget);
    });

    testWidgets('menyebut umur yang tertua, bukan yang terbaru',
        (tester) async {
      await pasang(
        tester,
        lebar: 1400,
        stats: contoh(menunggu: 4, umurTertua: const Duration(hours: 2)),
      );
      expect(find.text('Tertua menunggu 2 jam'), findsOneWidget);
    });

    testWidgets('lewat enam jam berubah jadi peringatan', (tester) async {
      await pasang(
        tester,
        lebar: 1400,
        stats: contoh(menunggu: 1, umurTertua: const Duration(hours: 7)),
      );
      expect(find.text('Ada yang tersangkut lebih dari 6 jam'), findsOneWidget);
    });
  });

  group('Kondisi kosong dan gagal', () {
    testWidgets('grafik diganti ajakan, pemilih rentang TETAP ada',
        (tester) async {
      await pasang(
        tester,
        lebar: 1400,
        stats: contoh(packing: 0, retur: 0, packingLalu: 0, returLalu: 0),
      );

      expect(find.byType(AppEmptyState), findsOneWidget);
      // 🔴 Sebab tersering dasbor kosong adalah rentang 7 hari yang kebetulan
      // sepi — layar yang menyembunyikan tombol 30/90 menutup jalan keluarnya.
      expect(find.text('90 hari'), findsOneWidget);
    });

    testWidgets('gagal menampilkan pesan manusia', (tester) async {
      await pasang(tester, lebar: 1400, gagal: AppFailure.network);
      expect(find.byType(AppErrorView), findsOneWidget);
    });
  });

  group('Layar sempit', () {
    testWidgets('tidak ada yang meluber pada 700', (tester) async {
      await pasang(tester, lebar: 700, stats: contoh());
      expect(tester.takeException(), isNull);
    });

    testWidgets('tidak ada yang meluber pada 420', (tester) async {
      await pasang(tester, lebar: 420, stats: contoh());
      expect(tester.takeException(), isNull);
    });
  });

  group('Sumbu grafik', () {
    test('batas atas dibulatkan ke kelipatan empat', () {
      expect(DailyChartAxis.maxYFor(7), 8);
      expect(DailyChartAxis.maxYFor(8), 8);
      expect(DailyChartAxis.maxYFor(9), 12);
    });

    test('rentang tanpa rekaman tetap punya sumbu, tidak runtuh ke nol', () {
      expect(DailyChartAxis.maxYFor(0), 4);
      expect(DailyChartAxis.maxYFor(-1), 4);
    });

    test('label tanggal dijarangkan agar tidak saling menimpa', () {
      expect(DailyChartAxis.labelStepFor(7), 1);
      expect(DailyChartAxis.labelStepFor(30), 5);
      expect(DailyChartAxis.labelStepFor(90), 13);
    });
  });

  group('Pengelompokan mingguan pada rentang panjang', () {
    List<DailyPoint> deret(int n) => [
          for (var i = 0; i < n; i++)
            DailyPoint(
              date: DateTime(2026, 6, 1).add(Duration(days: i)),
              packing: 1,
              returnCount: 1,
            ),
        ];

    test('rentang pendek dibiarkan harian', () {
      expect(WebDashboardPage.groupIfNeeded(deret(7)).length, 7);
      expect(WebDashboardPage.groupIfNeeded(deret(30)).length, 30);
    });

    test('🔴 90 hari dikelompokkan jadi 13 batang', () {
      // Rancangan desainer butir 3: 90 batang tidak muat walau di layar
      // lebar, dan batang selebar 6 px hanya terlihat seperti kabut.
      final hasil = WebDashboardPage.groupIfNeeded(deret(90));
      expect(hasil.length, 13);
    });

    test('tidak ada hari yang hilang saat dikelompokkan', () {
      final hasil = WebDashboardPage.groupIfNeeded(deret(90));
      final jumlah = hasil.fold<int>(0, (a, p) => a + p.total);
      // 90 hari x (1 packing + 1 retur).
      expect(jumlah, 180);
    });

    test('tanggalnya AWAL kelompok, bukan akhirnya', () {
      // Menuliskan tanggal akhir membuat batang pertama seolah mewakili
      // minggu yang belum terjadi.
      final hasil = WebDashboardPage.groupIfNeeded(deret(90));
      expect(hasil.first.date, DateTime(2026, 6, 1));
      expect(hasil[1].date, DateTime(2026, 6, 8));
    });

    test('sisa hari yang tidak genap seminggu tetap ikut', () {
      // 90 = 12 x 7 + 6. Kelompok terakhir berisi enam hari.
      final hasil = WebDashboardPage.groupIfNeeded(deret(90));
      expect(hasil.last.total, 12);
    });
  });
}

class _VmPalsu extends WebDashboardViewModel {
  _VmPalsu({this.stats, this.gagal});

  final DailyStats? stats;
  final AppFailure? gagal;

  @override
  Future<DailyStats> build() async {
    if (gagal != null) throw gagal!;
    return stats!;
  }
}
