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
/// 🔴 Memakai `AppTheme` sungguhan, bukan tema bawaan Flutter. Percobaan
/// pertama pada cacat M.12 memakai tema bawaan dan **lulus**, sehingga susunan
/// yang rusak sempat dinyatakan baik-baik saja. Kepala halaman ini berisi judul
/// dan `SegmentedButton` bersebelahan — bentuk yang persis sama dengan yang
/// sudah dua kali meluber di proyek ini (M.12 dan M.17).
void main() {
  DailyStats contoh({
    int packing = 12,
    int retur = 3,
    int packingLalu = 10,
    int returLalu = 2,
    int hari = 3,
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
      });

  Future<void> pasang(
    WidgetTester tester, {
    required double lebar,
    DailyStats? stats,
    AppFailure? gagal,
  }) async {
    tester.view.physicalSize = Size(lebar, 1000);
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
    testWidgets('empat kartu ringkasan dan grafiknya tergambar',
        (tester) async {
      await pasang(tester, lebar: 1400, stats: contoh());

      expect(find.text('Video Packing'), findsWidgets);
      expect(find.text('Video Return'), findsWidgets);
      expect(find.text('Total Video'), findsOneWidget);
      expect(find.text('Rata-rata / Hari'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rata-rata ditulis dengan satu desimal, tidak dibulatkan',
        (tester) async {
      // 11 video / 3 hari = 3,666… Dibulatkan menjadi "4", dan tenant yang
      // merekam 3,7 per hari tampak sama dengan yang merekam 4,4.
      await pasang(tester, lebar: 1400, stats: contoh(packing: 8, retur: 3));
      expect(find.text('3,7'), findsOneWidget);
    });

    testWidgets('kenaikan memakai panah, bukan warna saja', (tester) async {
      await pasang(tester, lebar: 1400, stats: contoh());

      // §7 palet: makna tidak pernah disampaikan hanya lewat warna.
      expect(find.byIcon(Icons.arrow_upward_rounded), findsWidgets);
      expect(find.textContaining('20%'), findsOneWidget);
    });

    testWidgets('periode sebelumnya nol menulis "belum ada pembanding"',
        (tester) async {
      await pasang(
        tester,
        lebar: 1400,
        stats: contoh(packingLalu: 0, returLalu: 0),
      );

      // Bukan "naik 100%". Tiga kartu pembanding + kartu rata-rata yang
      // memang tidak pernah membandingkan.
      expect(find.text('Belum ada pembanding'), findsNWidgets(4));
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    });
  });

  group('Kondisi kosong', () {
    testWidgets('grafik diganti ajakan, tetapi pemilih rentang TETAP ada',
        (tester) async {
      await pasang(
        tester,
        lebar: 1400,
        stats: contoh(packing: 0, retur: 0, packingLalu: 0, returLalu: 0),
      );

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);

      // 🔴 Inilah yang membedakannya dari layar kosong biasa. Sebab tersering
      // dasbor kosong adalah rentang 7 hari yang kebetulan sepi — layar yang
      // menyembunyikan tombol 30/90 hari menutup satu-satunya jalan keluar.
      expect(find.byType(SegmentedButton<int>), findsOneWidget);
      expect(find.text('90 hari'), findsOneWidget);
    });
  });

  group('Kondisi gagal', () {
    testWidgets('menampilkan pesan manusia, bukan pesan mentah server',
        (tester) async {
      await pasang(tester, lebar: 1400, gagal: AppFailure.network);

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
      // Kepala halaman tetap berdiri: pemilih rentangnya masih dapat dipakai
      // mencoba rentang lain tanpa memuat ulang seluruh halaman.
      expect(find.byType(SegmentedButton<int>), findsOneWidget);
    });
  });

  group('Layar sempit — kartu turun ke baris berikutnya', () {
    testWidgets('tidak ada yang meluber pada lebar 700', (tester) async {
      await pasang(tester, lebar: 700, stats: contoh());

      // `takeException` menangkap luberan RenderFlex. Bila kepala halaman atau
      // kartunya melebihi lebar layar, ia tidak diam — ia melempar di sini.
      expect(tester.takeException(), isNull);
      expect(find.text('Total Video'), findsOneWidget);
    });

    testWidgets('tidak ada yang meluber pada lebar 420', (tester) async {
      await pasang(tester, lebar: 420, stats: contoh());

      expect(tester.takeException(), isNull);
      expect(find.byType(SegmentedButton<int>), findsOneWidget);
    });
  });

  group('Sumbu grafik', () {
    test('batas atas dibulatkan ke kelipatan empat', () {
      // Supaya keempat garis bantunya jatuh pada bilangan bulat. Sumbu
      // berlabel "2,5 video" membuat pembaca bertanya apa artinya setengah
      // video.
      expect(DailyChartAxis.maxYFor(7), 8);
      expect(DailyChartAxis.maxYFor(8), 8);
      expect(DailyChartAxis.maxYFor(9), 12);
    });

    test('rentang tanpa rekaman tetap punya sumbu, tidak runtuh ke nol', () {
      expect(DailyChartAxis.maxYFor(0), 4);
      expect(DailyChartAxis.maxYFor(-1), 4);
    });

    test('label tanggal dijarangkan agar tidak saling menimpa', () {
      // Rentang terpendek memberi label pada setiap hari; yang panjang
      // dijarangkan sampai muat tujuh label.
      expect(DailyChartAxis.labelStepFor(7), 1);
      expect(DailyChartAxis.labelStepFor(30), 5);
      expect(DailyChartAxis.labelStepFor(90), 13);
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
