import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/models/platform_stats.dart';
import 'package:kamelscan/core/theme/app_theme.dart';
import 'package:kamelscan/core/utils/app_failure.dart';
import 'package:kamelscan/core/widgets/app_state_views.dart';
import 'package:kamelscan/l10n/generated/app_localizations.dart';
import 'package:kamelscan/pages/admin/dashboard/admin_stats_page.dart';
import 'package:kamelscan/pages/admin/dashboard/admin_stats_view_model.dart';

/// Dasbor platform Admin (Bab 11.1).
///
/// 🔴 Yang paling dijaga di sini adalah **kejujuran angkanya**, bukan
/// tampilannya. Dasbor keuangan yang mengarang satu angka lebih merugikan
/// daripada dasbor yang tidak ada — orang mengambil keputusan dagang dari
/// layar ini.
void main() {
  PlatformStats contoh({
    int standar = 3,
    int pro = 1,
    int trial = 12,
    int suspended = 2,
    int baru = 5,
    num mrr = 546000,
    num? biaya,
    num? margin,
    int video = 1284,
    int storage = 5368709120,
  }) =>
      PlatformStats.fromJson({
        'standar_active': standar,
        'pro_active': pro,
        'trial_count': trial,
        'suspended_count': suspended,
        'new_this_month': baru,
        'mrr': mrr,
        'infra_cost': biaya,
        'margin': margin,
        'total_videos': video,
        'storage_bytes': storage,
      });

  Future<void> pasang(
    WidgetTester tester, {
    PlatformStats? stats,
    AppFailure? gagal,
    double lebar = 1200,
  }) async {
    tester.view.physicalSize = Size(lebar, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminStatsViewModelProvider
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
          home: const AdminStatsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('🔴 Angka yang belum diketahui tidak boleh dikarang', () {
    testWidgets('margin tanpa biaya infrastruktur ditulis "—", BUKAN sama '
        'dengan MRR', (tester) async {
      // MRR dikurangi nol menghasilkan angka yang persis sama dengan MRR, dan
      // di layar ia terbaca sebagai "seluruh pendapatan adalah keuntungan".
      // Itu kalimat yang paling tidak boleh dikarang oleh dasbor keuangan.
      await pasang(tester, stats: contoh(mrr: 546000, biaya: null, margin: null));

      expect(find.text('Biaya infrastruktur belum diisi'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      // Rp 546.000 hanya boleh muncul SEKALI, di kartu MRR — bukan juga di
      // kartu margin.
      expect(find.text('Rp 546.000'), findsOneWidget);
    });

    testWidgets('🔴 margin MINUS tidak boleh berwarna hijau', (tester) async {
      // Terlihat pertama kali di layar Product Owner 29 Agustus 2026: margin
      // -Rp 53.000 tertulis dengan warna keberhasilan. Pada dasbor keuangan
      // itu jenis kesalahan yang paling menyesatkan — mata membaca warnanya
      // lebih dulu daripada tanda minusnya.
      await pasang(
        tester,
        stats: contoh(mrr: 447000, biaya: 500000, margin: -53000),
      );

      expect(find.text('-Rp 53.000'), findsOneWidget);

      // Palet §7: makna tidak boleh disampaikan lewat warna saja, jadi
      // ikonnya ikut berubah dan kalimatnya menyebutnya dengan kata.
      expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
      expect(find.text('Rugi — biaya melebihi pendapatan'), findsOneWidget);
    });

    testWidgets('margin positif tetap memakai ikon dan kalimat untung',
        (tester) async {
      await pasang(
        tester,
        stats: contoh(mrr: 900000, biaya: 500000, margin: 400000),
      );

      expect(find.byIcon(Icons.savings_outlined), findsOneWidget);
      expect(find.byIcon(Icons.trending_down_rounded), findsNothing);
      expect(find.text('Rugi — biaya melebihi pendapatan'), findsNothing);
    });

    testWidgets('margin ditampilkan begitu biayanya diisi', (tester) async {
      await pasang(
        tester,
        stats: contoh(mrr: 546000, biaya: 200000, margin: 346000),
      );

      expect(find.text('Rp 346.000'), findsOneWidget);
      expect(find.textContaining('Biaya infrastruktur Rp 200.000'),
          findsOneWidget);
      expect(find.text('Biaya infrastruktur belum diisi'), findsNothing);
    });
  });

  group('🔴 Dua angka yang memang tidak akan cocok wajib dijelaskan', () {
    testWidgets('total video dan penyimpanan masing-masing berketerangan',
        (tester) async {
      // Yang satu menghitung yang PERNAH direkam (termasuk yang sudah
      // dihapus), yang lain yang MASIH tersimpan. Selisih yang tidak
      // dijelaskan terbaca sebagai kerusakan — pelajaran dari dua grafik
      // dasbor web (O.16).
      await pasang(tester, stats: contoh());

      expect(find.text('Termasuk yang sudah dihapus dan kedaluwarsa'),
          findsOneWidget);
      expect(find.text('Hanya video yang masih tersimpan'), findsOneWidget);
    });
  });

  group('Angka pelanggan', () {
    testWidgets('pelanggan berbayar dijumlahkan, rinciannya ikut ditulis',
        (tester) async {
      await pasang(tester, stats: contoh(standar: 3, pro: 1));

      expect(find.text('4'), findsOneWidget);
      expect(find.text('Standar 3 · Pro 1'), findsOneWidget);
    });

    testWidgets('uji coba dihitung terpisah, tidak ikut pelanggan berbayar',
        (tester) async {
      // Tenant uji coba belum membayar sepeser pun; menjumlahkannya ke
      // "pelanggan" membuat angka pendapatan dan angka pelanggan bercerita
      // hal yang berbeda.
      await pasang(tester, stats: contoh(standar: 1, pro: 0, trial: 12));

      expect(find.text('12'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    test('hitungan turunan', () {
      final s = contoh(standar: 3, pro: 1, trial: 12, suspended: 2);
      expect(s.paidActive, 4);
      expect(s.totalTenants, 18);
      expect(s.needsInfraCost, isTrue);
    });

    test('biaya terisi berarti tidak perlu diisi lagi', () {
      expect(contoh(biaya: 200000).needsInfraCost, isFalse);
    });
  });

  group('Empat kondisi Bab 3.4', () {
    testWidgets('gagal menampilkan pesan manusia, bukan dasbor kosong',
        (tester) async {
      // 🔴 Yang bukan admin sampai di sini dengan galat izin — dan itu memang
      // yang benar. Fungsi servernya MENOLAK, bukan mengembalikan nol; angka
      // nol akan tampil sebagai "platform ini belum punya pelanggan".
      await pasang(tester, gagal: AppFailure.permissionDenied);

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });
  });

  group('Layar sempit', () {
    testWidgets('tidak ada yang meluber pada 600', (tester) async {
      await pasang(tester, stats: contoh(), lebar: 600);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tidak ada yang meluber pada 380', (tester) async {
      await pasang(tester, stats: contoh(), lebar: 380);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nominal sembilan digit tidak merusak kartunya',
        (tester) async {
      // Platform yang tumbuh bisa menembusnya. Mengecilkan angka lebih baik
      // daripada memotongnya.
      await pasang(
        tester,
        stats: contoh(mrr: 987654321, biaya: 123456789, margin: 864197532),
        lebar: 380,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

class _VmPalsu extends AdminStatsViewModel {
  _VmPalsu({this.stats, this.gagal});

  final PlatformStats? stats;
  final AppFailure? gagal;

  @override
  Future<PlatformStats> build() async {
    if (gagal != null) throw gagal!;
    return stats!;
  }
}
