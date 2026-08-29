import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/models/admin_tenant_row.dart';
import 'package:kamelscan/core/models/enums.dart';
import 'package:kamelscan/core/theme/app_theme.dart';
import 'package:kamelscan/core/utils/app_failure.dart';
import 'package:kamelscan/core/widgets/app_state_views.dart';
import 'package:kamelscan/l10n/generated/app_localizations.dart';
import 'package:kamelscan/pages/admin/users/admin_users_page.dart';
import 'package:kamelscan/pages/admin/users/admin_users_view_model.dart';

/// Kelola Pengguna (Bab 11.2).
///
/// 🔴 Dirender dengan `AppTheme` sungguhan. Percobaan pertama pada M.12
/// memakai tema bawaan Flutter dan **lulus**, sehingga susunan yang rusak
/// sempat dinyatakan baik-baik saja — tombol bertema proyek ini menuntut lebar
/// tak terhingga, dan hanya tema inilah yang membuatnya meluber.
///
/// ⚠️ `expect(tester.takeException(), isNull)` ada di hampir setiap tes di
/// sini dengan sengaja. Tanpa baris itu, tes tata letak lulus sambil layarnya
/// bergaris kuning-hitam.
void main() {
  AdminTenantRow baris(
    String id, {
    String? nama = 'Toko Kamel',
    String? email = 'owner@contoh.com',
    TierPlan tier = TierPlan.standar,
    TenantStatus status = TenantStatus.active,
    DateTime? akhir,
    int video = 128,
    int token = 72,
    bool admin = false,
    DateTime? akhirToken,
  }) => AdminTenantRow(
    id: id,
    businessName: nama,
    ownerEmail: email,
    tierPlan: tier,
    status: status,
    createdAt: DateTime(2026, 5, 12),
    periodEnd: akhir ?? DateTime(2026, 9, 25),
    shopCount: 3,
    packerCount: 4,
    videoCount: video,
    tokenBalance: token,
    ownerIsAdmin: admin,
    tokenPeriodEnd: akhirToken ?? DateTime(2026, 9, 25),
  );

  AdminUsersData data({
    int rows = 3,
    String query = '',
    TenantStatus? status,
    String? selectedId,
    List<AdminTenantRow>? isi,
  }) => AdminUsersData(
    all: isi ?? [for (var i = 0; i < rows; i++) baris('t$i')],
    query: query,
    status: status,
    selectedId: selectedId,
  );

  late _VmPalsu vm;

  Future<void> pasang(
    WidgetTester tester, {
    required double lebar,
    AdminUsersData? isi,
    AppFailure? gagal,
    // ⚠️ `ListView` panel membangun anaknya secara malas. Pada 900 px tombol
    // aksi paling bawah jatuh di luar layar dan TIDAK PERNAH dibangun, dan
    // tesnya gagal dengan "No element" — pesan yang sama sekali tidak menyebut
    // sebabnya. Tes yang menyentuh tombol wajib meninggikan jendelanya.
    double tinggi = 900,
  }) async {
    tester.view.physicalSize = Size(lebar, tinggi);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    vm = _VmPalsu(isi: isi, gagal: gagal);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminUsersViewModelProvider.overrideWith(() => vm)],
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
          home: const AdminUsersPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Bentuk tabel di layar lebar', () {
    testWidgets('kesepuluh kolom tampil pada 1400', (tester) async {
      await pasang(tester, lebar: 1400, isi: data());

      expect(find.text('Nama Usaha'), findsOneWidget);
      expect(find.text('Email Pemilik'), findsOneWidget);
      expect(find.text('Daftar'), findsOneWidget);
      expect(find.text('Akhir Periode'), findsOneWidget);
      expect(find.text('Toko'), findsOneWidget);
      expect(find.text('Packer'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
      expect(find.text('Token'), findsOneWidget);

      // "Paket" dan "Status" muncul DUA kali dan itu benar: sekali sebagai
      // judul kolom, sekali sebagai label menu saringan di atasnya. Keduanya
      // menyaring hal yang sama, jadi menamainya berbeda justru menyesatkan.
      expect(find.text('Paket'), findsNWidgets(2));
      expect(find.text('Status'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('🔴 kolom dibuang, bukan dipersempit, saat ruang menyusut', (
      tester,
    ) async {
      await pasang(tester, lebar: 1050, isi: data());

      // Sepuluh kolom yang dipaksa muat menyisakan ± 87 px per kolom, dan nama
      // usaha — satu-satunya isi yang harus terbaca utuh — akan berakhir
      // sebagai "Toko Ma…".
      expect(find.text('Toko'), findsNothing);
      expect(find.text('Packer'), findsNothing);
      expect(find.text('Email Pemilik'), findsNothing);

      // Yang wajib bertahan selama tabelnya masih tabel: keempat kolom yang
      // dipakai memutuskan sesuatu tentang seorang pelanggan.
      expect(find.text('Nama Usaha'), findsOneWidget);
      expect(find.text('Akhir Periode'), findsOneWidget);
      expect(find.text('Paket'), findsNWidgets(2));
      expect(find.text('Status'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('nama usaha tetap utuh, tidak terpotong', (tester) async {
      await pasang(tester, lebar: 1100, isi: data(rows: 1));
      expect(find.text('Toko Kamel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Layar sempit — tabel berubah jadi kartu', () {
    testWidgets('di bawah 1024 tidak ada judul kolom lagi', (tester) async {
      await pasang(tester, lebar: 900, isi: data());

      // 🔴 1024, bukan 768 seperti Riwayat: tabel ini punya sepuluh kolom dan
      // panelnya 380 px. Pada 900 px yang tersisa untuk tabelnya tinggal 520,
      // dan yang tampak bukan tabel lagi melainkan potongan kolom.
      expect(find.text('Nama Usaha'), findsNothing);
      expect(find.text('Akhir Periode'), findsNothing);

      // Kartunya tetap membawa nama, paket, dan status.
      expect(find.text('Toko Kamel'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tepat di 1024 masih berbentuk tabel', (tester) async {
      await pasang(tester, lebar: 1024, isi: data());
      expect(find.text('Nama Usaha'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bilah saringan tidak meluber pada 420', (tester) async {
      // Kolom cari 280 px, dua menu turun 170 px, dan sebuah tombol —
      // berdampingan di dalam `Wrap`. Bentuk yang sudah dua kali meluber di
      // proyek ini (M.12, M.17).
      await pasang(
        tester,
        lebar: 420,
        isi: data(query: 'kamel', status: TenantStatus.active),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Empat kondisi Bab 3.4', () {
    testWidgets('gagal menampilkan pesan manusia, bukan daftar kosong', (
      tester,
    ) async {
      // 🔴 Yang bukan admin sampai di sini dengan galat izin, dan itu memang
      // yang benar. Daftar kosong akan terbaca sebagai "platform ini belum
      // punya pelanggan" — kalimat yang salah dan terlihat masuk akal.
      await pasang(tester, lebar: 1400, gagal: AppFailure.permissionDenied);

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('Nama Usaha'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'kosong tanpa saringan berkata platform belum punya pelanggan',
      (tester) async {
        await pasang(tester, lebar: 1400, isi: data(rows: 0));

        expect(find.byType(AppEmptyState), findsOneWidget);
        expect(find.text('Belum ada pelanggan'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('🔴 kosong DENGAN saringan berkata lain', (tester) async {
      // Membedakan keduanya bukan kemewahan: saringan yang tidak sengaja
      // tertinggal aktif membuat halaman terlihat seperti platform yang
      // kehilangan seluruh pelanggannya.
      await pasang(tester, lebar: 1400, isi: data(rows: 0, query: 'zzz'));

      expect(find.text('Tidak ada yang cocok'), findsOneWidget);
      expect(find.text('Belum ada pelanggan'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('berisi menampilkan jumlah baris yang sedang tampil', (
      tester,
    ) async {
      await pasang(tester, lebar: 1400, isi: data(rows: 3));
      expect(find.text('3 pelanggan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Memilih baris', () {
    testWidgets('menekan baris di layar lebar meminta panel dibuka', (
      tester,
    ) async {
      await pasang(tester, lebar: 1400, isi: data(rows: 2));

      await tester.tap(find.text('Toko Kamel').first);
      await tester.pumpAndSettle();

      expect(vm.dipilih, 't0');
      expect(tester.takeException(), isNull);
    });

    testWidgets('panel samping menampilkan angka pemakaian', (tester) async {
      await pasang(tester, lebar: 1400, isi: data(rows: 2, selectedId: 't1'));

      expect(find.text('Detail Pelanggan'), findsOneWidget);
      // ⚠️ Keterangan ini WAJIB ikut: angka video menghitung yang pernah
      // direkam, bukan yang masih tersimpan. Selisih yang tidak dijelaskan
      // terbaca sebagai kerusakan (O.16).
      expect(
        find.text('Termasuk yang sudah dihapus dan kedaluwarsa'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('🔴 panel tidak ikut muncul di layar sempit', (tester) async {
      // Panel 380 px pada layar 900 px hanya menyisakan 520 px — dua-duanya
      // jadi tidak terbaca. Di lebar itu detailnya dibuka sebagai lembar
      // bawah, bukan panel.
      await pasang(tester, lebar: 900, isi: data(rows: 2, selectedId: 't1'));
      expect(find.text('Detail Pelanggan'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('🔴 Baris tenant milik akun admin sendiri', () {
    // Setiap akun yang mendaftar memperoleh satu tenant, termasuk yang
    // belakangan dinaikkan menjadi admin. Product Owner menemukannya di layar
    // 29 Agustus 2026: emailnya sendiri berdiri di tabel sebagai pelanggan
    // uji coba, lengkap dengan tombol Tangguhkan yang mengenai akunnya.

    testWidgets('ditandai dengan lencana, bukan disembunyikan', (tester) async {
      await pasang(
        tester,
        lebar: 1400,
        isi: data(
          isi: [
            baris('t0', nama: 'Toko Kamel'),
            baris('t1', nama: 'Punya Saya', admin: true),
          ],
        ),
      );

      // Barisnya TETAP ada — keputusan Product Owner. Baris yang hilang tanpa
      // penjelasan membuat orang mencari-cari.
      expect(find.text('Punya Saya'), findsOneWidget);
      expect(find.text('Akun Admin'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('🔴 ketiga tombol aksinya mati', (tester) async {
      await pasang(
        tester,
        lebar: 1400,
        tinggi: 1400,
        isi: data(
          selectedId: 't1',
          isi: [
            baris('t0'),
            baris('t1', nama: 'Punya Saya', admin: true),
          ],
        ),
      );

      // Menangguhkan diri sendiri tidak punya kegunaan apa pun, dan akibatnya
      // baru terasa saat admin memakai akunnya sebagai pengguna biasa.
      for (final label in ['Perpanjang periode', 'Atur token', 'Tangguhkan']) {
        final tombol = tester.widget<ButtonStyleButton>(
          find.ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          ),
        );
        expect(tombol.onPressed, isNull, reason: 'tombol "$label" harus mati');
      }

      // Dan alasannya tertulis. Tombol mati tanpa penjelasan terbaca sebagai
      // kerusakan, dan yang menemuinya akan mencoba lagi lewat SQL Editor —
      // persis jalan yang paling berbahaya.
      expect(
        find.textContaining('tidak menangguhkan atau mengubah akun Anda'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('pelanggan biasa tombolnya tetap hidup', (tester) async {
      await pasang(
        tester,
        lebar: 1400,
        tinggi: 1400,
        isi: data(selectedId: 't0', isi: [baris('t0')]),
      );

      final tombol = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Tangguhkan'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(tombol.onPressed, isNotNull);
      expect(find.text('Akun Admin'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Dialog atur token', () {
    // 🔴 Dibatasi ke dalam dialog. Kolom cari di halaman belakangnya juga
    // bertipe `TextField`, dan `find.byType(TextField).first` mengenai yang
    // itu — tesnya lalu mengetik ke kolom yang salah dan gagal dengan pesan
    // yang tidak menyebut sebabnya sama sekali.
    Finder kolom(int i) => find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        )
        .at(i);

    Future<void> bukaDialog(
      WidgetTester tester, {
      required AdminTenantRow untuk,
    }) async {
      await pasang(
        tester,
        lebar: 1400,
        tinggi: 1400,
        isi: data(selectedId: untuk.id, isi: [untuk]),
      );
      await tester.tap(find.text('Atur token'));
      await tester.pumpAndSettle();
    }

    testWidgets('🔴 tombol simpan mati sampai alasannya terisi', (
      tester,
    ) async {
      // Bab 11.2: "dengan alasan wajib". Penjagaan sesungguhnya ada di server
      // (REASON_REQUIRED); yang di layar hanya membuat penolakannya terjadi
      // sebelum tombol ditekan, bukan sesudah.
      await bukaDialog(tester, untuk: baris('t0', token: 100));

      ButtonStyleButton simpan() => tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Simpan'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );

      expect(simpan().onPressed, isNull);

      await tester.enterText(kolom(0), '81');
      await tester.pumpAndSettle();
      // Angka saja belum cukup.
      expect(simpan().onPressed, isNull);

      await tester.enterText(kolom(1), 'Bonus HUT RI');
      await tester.pumpAndSettle();
      expect(simpan().onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('🔴 keterangan di bawah kolom Alasan tidak boleh terpotong', (
      tester,
    ) async {
      // Terlihat di layar Product Owner 29 Agustus 2026: "Wajib diisi.
      // Tercatat per…". `helperText` bawaannya dibatasi SATU baris, dan yang
      // hilang justru bagian yang menjelaskan kenapa alasannya wajib —
      // sehingga kolomnya terbaca sebagai kerewelan belaka.
      //
      // Tidak ada galat apa pun untuk cacat semacam ini; ia hanya memotong
      // kalimat. Karena itu yang diperiksa adalah setelannya, bukan gambarnya.
      await bukaDialog(tester, untuk: baris('t0'));

      final alasan = tester.widget<TextField>(kolom(1));
      expect(alasan.decoration?.helperText, isNotNull);
      expect(
        alasan.decoration?.helperMaxLines,
        greaterThan(1),
        reason: 'keterangan alasan butuh lebih dari satu baris',
      );
    });

    testWidgets('saldo sesudahnya ditulis sebelum ditekan', (tester) async {
      await bukaDialog(tester, untuk: baris('t0', token: 997));

      await tester.enterText(kolom(0), '81');
      await tester.pumpAndSettle();

      expect(find.text('Saldo 997 → 1.078'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('🔴 pengurangan melebihi saldo dikatakan berhenti di nol', (
      tester,
    ) async {
      // Server menjepit saldo di nol dan buku besar mencatat selisih yang
      // BENAR-BENAR terjadi. Tanpa kalimat ini Admin mengira pengurangannya
      // gagal separuh.
      await bukaDialog(tester, untuk: baris('t0', token: 50));

      await tester.tap(find.text('Kurangi'));
      await tester.enterText(kolom(0), '200');
      await tester.pumpAndSettle();

      expect(find.text('Saldo 50 → 0'), findsOneWidget);
      expect(find.textContaining('berhenti di 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // 🔴 Tiga keadaan, tiga tes TERPISAH — bukan satu tes berisi tiga bagian.
    //
    // `pumpWidget` memakai ulang pohon elemen yang tipenya sama, sehingga
    // `Navigator`-nya bertahan beserta dialog yang masih terbuka dari bagian
    // sebelumnya. Bagian kedua lalu gagal menekan tombol yang tertutup dialog
    // lama, dengan pesan yang tidak menyebut sebabnya sama sekali.
    //
    // Ketiga kalimatnya sengaja berbeda: menggabungkannya menjadi satu membuat
    // salah satunya selalu bohong.

    testWidgets('pelanggan aktif — memakai tanggal reset DOMPET', (
      tester,
    ) async {
      // Bukan `tenants.period_end`. Keduanya berbeda sesudah bulan pertama:
      // cron menyetel ulang periode dompet tiap reset, sementara periode
      // langganan hanya bergerak saat membayar atau saat Admin memperpanjang.
      await bukaDialog(
        tester,
        untuk: baris(
          't0',
          akhir: DateTime(2026, 12, 31),
          akhirToken: DateTime(2026, 9, 25),
        ),
      );
      await tester.enterText(kolom(0), '81');
      await tester.pumpAndSettle();

      // Dibatasi ke DALAM dialog: "31 Des 2026" memang muncul di tabel dan di
      // kolom Akhir Periode, dan itu benar.
      Finder diDialog(String teks) => find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining(teks),
      );

      expect(diDialog('25 Sep 2026'), findsOneWidget);
      expect(diDialog('31 Des'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uji coba — tidak pernah direset, jadi tidak hangus', (
      tester,
    ) async {
      await bukaDialog(
        tester,
        untuk: baris('t0', status: TenantStatus.trial, akhirToken: null),
      );
      await tester.enterText(kolom(0), '81');
      await tester.pumpAndSettle();

      expect(find.textContaining('tidak hangus'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ditangguhkan — hangus pada reset pertama setelah aktif lagi', (
      tester,
    ) async {
      await bukaDialog(
        tester,
        untuk: baris('t0', status: TenantStatus.suspended),
      );
      await tester.enterText(kolom(0), '81');
      await tester.pumpAndSettle();

      expect(find.textContaining('setelah ia diaktifkan lagi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Pemberian token serentak', () {
    testWidgets('menyebut berapa pelanggan aktif yang kena', (tester) async {
      await pasang(
        tester,
        lebar: 1400,
        isi: data(
          isi: [
            baris('a', status: TenantStatus.active),
            baris('b', status: TenantStatus.active),
            baris('c', status: TenantStatus.trial),
            baris('d', status: TenantStatus.suspended),
          ],
        ),
      );

      await tester.tap(find.byIcon(Icons.card_giftcard_outlined));
      await tester.pumpAndSettle();

      // Dua, bukan empat. Uji coba dan yang ditangguhkan sengaja tidak ikut.
      expect(
        find.textContaining('2 pelanggan berstatus Aktif'),
        findsOneWidget,
      );
      expect(find.textContaining('tidak ikut kebagian'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('🔴 tombolnya mati bila tidak ada pelanggan aktif', (
      tester,
    ) async {
      // Dialog yang terbuka lalu berkata "0 pelanggan" hanya membuang waktu
      // orang yang menekannya.
      await pasang(
        tester,
        lebar: 1400,
        isi: data(isi: [baris('c', status: TenantStatus.trial)]),
      );

      final tombol = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.card_giftcard_outlined),
          matching: find.byType(IconButton),
        ),
      );
      expect(tombol.onPressed, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'jumlah aktif dihitung dari SELURUH baris, bukan yang tersaring',
      (tester) async {
        // Tombolnya memang mengenai semua pelanggan aktif. Menuliskan angka
        // hasil saringan akan menjanjikan sesuatu yang tidak dilakukannya.
        await pasang(
          tester,
          lebar: 1400,
          isi: AdminUsersData(
            all: [
              baris('a', nama: 'Alfa', status: TenantStatus.active),
              baris('b', nama: 'Beta', status: TenantStatus.active),
            ],
            query: 'alfa',
          ),
        );

        expect(find.text('1 pelanggan'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.card_giftcard_outlined));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('2 pelanggan berstatus Aktif'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Menyaring dan mengurutkan di dalam aplikasi', () {
    test('saringan status membuang yang tidak cocok', () {
      final d = AdminUsersData(
        all: [
          baris('a', status: TenantStatus.active),
          baris('b', status: TenantStatus.suspended),
        ],
        status: TenantStatus.suspended,
      );

      expect(d.items.map((r) => r.id), ['b']);
      expect(d.hasFilter, isTrue);
    });

    test('pencarian mengenai nama usaha ATAU email', () {
      final d = AdminUsersData(
        all: [
          baris('a', nama: 'Toko Melati', email: 'a@contoh.com'),
          baris('b', nama: 'Toko Mawar', email: 'melati@contoh.com'),
          baris('c', nama: 'Toko Anggrek', email: 'c@contoh.com'),
        ],
      );

      // Yang mencari belum tentu ingat versi mana yang tercatat, jadi keduanya
      // ikut dicari.
      expect(d.copyWith(query: 'melati').items.map((r) => r.id), ['a', 'b']);
    });

    test('🔴 tenant tanpa period_end berkumpul di satu ujung', () {
      // `period_end` NULL bukan data yang lupa diisi — ia berarti masa uji
      // coba, yang memang tidak punya batas waktu (Bab 7.5). Tersebar acak di
      // tengah daftar, ia terbaca sebagai baris rusak.
      final d = AdminUsersData(
        all: [
          baris('a', akhir: DateTime(2026, 9, 25)),
          baris('b', akhir: DateTime(2026, 12, 1)),
          const AdminTenantRow(id: 'trial', businessName: 'Baru'),
        ],
        sort: AdminTenantSort.period,
      );

      expect(d.items.map((r) => r.id), ['b', 'a', 'trial']);
      expect(d.copyWith(ascending: true).items.map((r) => r.id), [
        'trial',
        'a',
        'b',
      ]);
    });

    test('baris terpilih hilang dengan tenang bila sudah tidak ada', () {
      final d = AdminUsersData(all: [baris('a')], selectedId: 'sudah-hilang');
      expect(d.selected, isNull);
    });
  });

  group('🔴 Aturan perpanjangan periode — keputusan dagang, bukan teknis', () {
    test('disambung dari akhir periode yang masih berjalan', () {
      // Keputusan Product Owner 29 Agustus 2026. BERBEDA dari pembayaran
      // otomatis (migrasi 28), yang selalu menghitung ulang 30 hari dari hari
      // pembayaran — dan perbedaan itu disengaja.
      final kini = DateTime(2026, 8, 29);
      final r = baris('a', akhir: DateTime(2026, 9, 25));

      expect(Perpanjangan.dasar(r, kini), DateTime(2026, 9, 25));
    });

    test('periode yang sudah lewat dihitung dari hari ini', () {
      final kini = DateTime(2026, 8, 29);
      final r = baris('a', akhir: DateTime(2026, 7, 1));

      expect(Perpanjangan.dasar(r, kini), kini);
    });

    test('uji coba tanpa periode dihitung dari hari ini', () {
      final kini = DateTime(2026, 8, 29);
      const r = AdminTenantRow(id: 'a');

      expect(Perpanjangan.dasar(r, kini), kini);
    });

    test('🔴 31 Januari + 1 bulan menjadi 28 Februari, bukan 3 Maret', () {
      // `DateTime(2026, 2, 31)` diterjemahkan Dart menjadi 3 Maret tanpa satu
      // pun galat: pelanggan mendapat tiga hari lebih, dan tidak ada yang
      // menyadarinya sampai seseorang menghitung dengan kalender.
      expect(
        Perpanjangan.tambahBulan(DateTime(2026, 1, 31), 1),
        DateTime(2026, 2, 28),
      );
      // Tahun kabisat tetap dapat 29.
      expect(
        Perpanjangan.tambahBulan(DateTime(2028, 1, 31), 1),
        DateTime(2028, 2, 29),
      );
      // 31 Mei + 1 bulan = 30 Juni.
      expect(
        Perpanjangan.tambahBulan(DateTime(2026, 5, 31), 1),
        DateTime(2026, 6, 30),
      );
    });

    test('perpanjangan melewati pergantian tahun', () {
      expect(
        Perpanjangan.tambahBulan(DateTime(2026, 9, 25), 12),
        DateTime(2027, 9, 25),
      );
      expect(
        Perpanjangan.tambahBulan(DateTime(2026, 11, 30), 3),
        DateTime(2027, 2, 28),
      );
    });

    test('🔴 memperpanjang TIDAK mencabut penangguhan', () {
      // Penangguhan datang dari alasan di luar pembayaran. Mencabutnya diam-
      // diam berarti Admin mengira pelanggan itu masih terkunci padahal sudah
      // merekam lagi.
      expect(Perpanjangan.aktifkan(TenantStatus.suspended), isFalse);

      // Sebaliknya `expired` dan `trial` wajib ikut aktif: tanpa itu
      // periodenya panjang tetapi pelanggannya tetap tidak dapat merekam
      // (Bab 7.6) — benar menurut database, mustahil dipahami dari layar.
      expect(Perpanjangan.aktifkan(TenantStatus.expired), isTrue);
      expect(Perpanjangan.aktifkan(TenantStatus.trial), isTrue);

      // Yang sudah aktif tidak perlu disentuh statusnya.
      expect(Perpanjangan.aktifkan(TenantStatus.active), isFalse);
    });
  });
}

class _VmPalsu extends AdminUsersViewModel {
  _VmPalsu({this.isi, this.gagal});

  final AdminUsersData? isi;
  final AppFailure? gagal;

  AdminTenantSort? diurutkan;
  String? dipilih;

  @override
  Future<AdminUsersData> build() async {
    if (gagal != null) throw gagal!;
    return isi!;
  }

  @override
  void sortBy(AdminTenantSort kolom) => diurutkan = kolom;

  @override
  void select(String? id) => dipilih = id;
}
