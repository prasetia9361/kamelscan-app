import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/models/enums.dart';
import 'package:kamelscan/core/models/history_item.dart';
import 'package:kamelscan/core/models/package_video.dart';
import 'package:kamelscan/core/repositories/video_repository.dart';
import 'package:kamelscan/core/theme/app_theme.dart';
import 'package:kamelscan/core/utils/app_failure.dart';
import 'package:kamelscan/core/widgets/app_state_views.dart';
import 'package:kamelscan/l10n/generated/app_localizations.dart';
import 'package:kamelscan/navigation/shells/web_shell.dart';
import 'package:kamelscan/pages/web/history/web_history_page.dart';
import 'package:kamelscan/pages/web/history/web_history_view_model.dart';

/// Tabel Riwayat web (Bab 10.5).
///
/// 🔴 Dirender dengan `AppTheme` sungguhan. Bilah saringan berisi kolom teks,
/// dua menu turun, dan sebuah tombol berdampingan — bentuk yang sudah dua kali
/// meluber di proyek ini (M.12, M.17), dan tema proyek inilah yang membuatnya
/// meluber: tombol bertema menuntut lebar tak terhingga.
void main() {
  const typeWire = '';

  HistoryItem item(String id, String resi, {int? durasi = 42}) => HistoryItem(
        video: PackageVideo(
          id: id,
          tenantId: 't1',
          shopId: 's1',
          userId: 'u1',
          resiCode: resi,
          type: VideoType.packing,
          scanDate: DateTime(2026, 8, 26, 14, 30),
          expiresAt: DateTime(2026, 11, 26),
          status: VideoStatus.uploaded,
          durationSeconds: durasi,
        ),
        shopName: 'Toko Kamel',
        marketName: 'Shopee',
        recorderName: 'Budi Santoso',
      );

  WebHistoryData data({
    int total = 431,
    int page = 0,
    int rows = 3,
    VideoFilter filter = const VideoFilter(),
    HistorySort sort = HistorySort.date,
    bool ascending = false,
  }) =>
      WebHistoryData(
        items: [
          for (var i = 0; i < rows; i++) item('v$i', 'JX00000000$i'),
        ],
        total: total,
        page: page,
        filter: filter,
        sort: sort,
        ascending: ascending,
      );

  late _VmPalsu vm;

  Future<void> pasang(
    WidgetTester tester, {
    required double lebar,
    WebHistoryData? isi,
    AppFailure? gagal,
  }) async {
    tester.view.physicalSize = Size(lebar, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    vm = _VmPalsu(isi: isi, gagal: gagal);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          webHistoryViewModelProvider(typeWire).overrideWith(() => vm),
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
          home: const Scaffold(body: WebHistoryPage(typeWire: typeWire)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Bentuk tabel di layar lebar', () {
    testWidgets('ketujuh kolom tampil pada 1400', (tester) async {
      await pasang(tester, lebar: 1400, isi: data());

      expect(find.text('Resi'), findsOneWidget);
      expect(find.text('Toko'), findsOneWidget);
      expect(find.text('Packer'), findsOneWidget);
      expect(find.text('Durasi'), findsOneWidget);
      expect(find.text('Aksi'), findsOneWidget);

      // "Tanggal" juga dua kali — judul kolom dan label saringan rentang
      // tanggal di atasnya, sama seperti Tipe dan Status.
      expect(find.text('Tanggal'), findsNWidgets(2));

      // "Tipe" dan "Status" muncul DUA kali dan itu benar: sekali sebagai
      // judul kolom, sekali sebagai label menu saringan di atasnya. Keduanya
      // menyaring hal yang sama, jadi menamainya berbeda justru menyesatkan.
      expect(find.text('Tipe'), findsNWidgets(2));
      expect(find.text('Status'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('🔴 kolom dibuang, bukan dipersempit, saat ruang menyusut',
        (tester) async {
      await pasang(tester, lebar: 950, isi: data());

      // Tujuh kolom yang dipaksa muat menyisakan ± 100 px per kolom, dan nomor
      // resi — satu-satunya isi yang tidak boleh terpotong — akan berakhir
      // sebagai "JX12…".
      expect(find.text('Packer'), findsNothing);
      expect(find.text('Durasi'), findsNothing);

      // Yang wajib bertahan sampai kapan pun tabelnya masih tabel.
      expect(find.text('Tanggal'), findsNWidgets(2));
      expect(find.text('Resi'), findsOneWidget);
      expect(find.text('Status'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('nomor resi tetap utuh, tidak terpotong', (tester) async {
      await pasang(tester, lebar: 950, isi: data(rows: 1));
      expect(find.text('JX000000000'), findsOneWidget);
    });
  });

  group('Judul kolom yang dapat diurutkan', () {
    testWidgets('menekan "Resi" meminta pengurutan menurut resi',
        (tester) async {
      await pasang(tester, lebar: 1400, isi: data());

      await tester.tap(find.text('Resi'));
      await tester.pumpAndSettle();

      expect(vm.diurutkan, HistorySort.resi);
    });

    testWidgets('🔴 kolom Toko TIDAK dapat ditekan', (tester) async {
      await pasang(tester, lebar: 1400, isi: data());

      await tester.tap(find.text('Toko'));
      await tester.pumpAndSettle();

      // Nama toko datang dari tabel tetangga; mengurutkannya di server belum
      // pernah dibuktikan pada proyek ini, dan bila salah server hanya
      // mengabaikannya tanpa pesan. Judul yang dapat ditekan tetapi diam saja
      // lebih membingungkan daripada judul biasa.
      expect(vm.diurutkan, isNull);
    });

    testWidgets('panah arah hanya muncul pada kolom yang sedang aktif',
        (tester) async {
      await pasang(
        tester,
        lebar: 1400,
        isi: data(sort: HistorySort.resi, ascending: true),
      );

      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
    });
  });

  group('Halaman bernomor', () {
    testWidgets('menyebut rentang baris, bukan hanya nomor halaman',
        (tester) async {
      await pasang(tester, lebar: 1400, isi: data(total: 431, rows: 25));

      // "1–25 dari 431" menjawab pertanyaan yang benar-benar diajukan orang
      // saat menelusuri bukti: berapa banyak lagi yang tersisa.
      expect(find.text('Menampilkan 1–25 dari 431 video'), findsOneWidget);

      // Nomor halaman digambar, bukan sekadar "halaman 1 dari 18".
      expect(find.text('1'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('…'), findsOneWidget);
    });

    testWidgets('tombol mundur mati di halaman pertama', (tester) async {
      await pasang(tester, lebar: 1400, isi: data(page: 0, rows: 25));

      final mundur = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.chevron_left),
          matching: find.byType(IconButton),
        ),
      );
      expect(mundur.onPressed, isNull);
    });

    testWidgets('tombol maju mati di halaman terakhir', (tester) async {
      // 30 baris, 25 per halaman → halaman 1 (indeks 1) adalah yang terakhir.
      await pasang(tester, lebar: 1400, isi: data(total: 30, page: 1, rows: 5));

      final maju = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.chevron_right),
          matching: find.byType(IconButton),
        ),
      );
      expect(maju.onPressed, isNull);
      expect(find.text('Menampilkan 26–30 dari 30 video'), findsOneWidget);
    });
  });

  group('Layar sempit — tabel berubah jadi kartu', () {
    testWidgets('di bawah 768 tidak ada judul kolom lagi', (tester) async {
      await pasang(
        tester,
        lebar: WebShell.cardBreakpoint - 1,
        isi: data(),
      );

      // Yang tersisa hanya label saringan, bukan judul kolom.
      expect(find.text('Tanggal'), findsOneWidget);
      expect(find.text('Packer'), findsNothing);
      expect(find.text('Aksi'), findsNothing);
      // Resinya justru harus tetap ada — ia isi kartunya.
      expect(find.text('JX000000000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tepat di 768 masih berbentuk tabel', (tester) async {
      await pasang(tester, lebar: WebShell.cardBreakpoint, isi: data());
      expect(find.text('Tanggal'), findsNWidgets(2));
    });

    testWidgets('bilah saringan tidak meluber pada 420', (tester) async {
      await pasang(tester, lebar: 420, isi: data());
      expect(tester.takeException(), isNull);
    });
  });

  group('Empat kondisi Bab 3.4', () {
    testWidgets('kosong tanpa saringan mengajak merekam', (tester) async {
      await pasang(tester, lebar: 1400, isi: data(rows: 0, total: 0));

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('Belum ada rekaman'), findsOneWidget);
    });

    testWidgets('kosong DENGAN saringan berkata lain', (tester) async {
      await pasang(
        tester,
        lebar: 1400,
        isi: data(
          rows: 0,
          total: 0,
          filter: const VideoFilter(resiQuery: 'JX999'),
        ),
      );

      // Dua kalimat yang berbeda untuk dua sebab yang berbeda. "Belum ada
      // rekaman" pada pencarian yang tidak ketemu membuat Owner mengira
      // seluruh datanya hilang.
      expect(find.text('Tidak ada yang cocok'), findsOneWidget);
    });

    testWidgets('gagal menampilkan pesan manusia', (tester) async {
      await pasang(tester, lebar: 1400, gagal: AppFailure.network);
      expect(find.byType(AppErrorView), findsOneWidget);
    });
  });

  group('Memilih baris', () {
    testWidgets('menekan baris di layar lebar membuka panel', (tester) async {
      await pasang(tester, lebar: 1400, isi: data(rows: 1));

      await tester.tap(find.text('JX000000000'));
      await tester.pumpAndSettle();

      expect(vm.dipilih, 'v0');
    });
  });
}

/// ViewModel palsu yang **mencatat** perintah alih-alih menjalankannya.
///
/// `select` sengaja tidak mengubah keadaan: bila ia membuka panel sungguhan,
/// tesnya ikut membangun `VideoDetailPage` beserta ViewModel-nya, dan itu
/// menyentuh Supabase. Yang diuji di sini penyambungannya, bukan isi panelnya.
class _VmPalsu extends WebHistoryViewModel {
  _VmPalsu({this.isi, this.gagal});

  final WebHistoryData? isi;
  final AppFailure? gagal;

  HistorySort? diurutkan;
  String? dipilih;

  @override
  Future<WebHistoryData> build(String typeWire) async {
    if (gagal != null) throw gagal!;
    return isi!;
  }

  @override
  Future<void> sortBy(HistorySort kolom) async => diurutkan = kolom;

  @override
  void select(String? id) => dipilih = id;
}
