import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/config/tier_config.dart';
import 'package:kamelscan/core/models/payment_methods.dart';
import 'package:kamelscan/core/models/platform_contact.dart';
import 'package:kamelscan/core/models/promo.dart';
import 'package:kamelscan/core/theme/app_theme.dart';
import 'package:kamelscan/core/utils/app_failure.dart';
import 'package:kamelscan/l10n/generated/app_localizations.dart';
import 'package:kamelscan/pages/admin/settings/admin_contact_page.dart';
import 'package:kamelscan/pages/admin/settings/admin_payment_methods_page.dart';
import 'package:kamelscan/pages/admin/settings/admin_pricing_page.dart';
import 'package:kamelscan/pages/admin/settings/admin_promos_page.dart';
import 'package:kamelscan/pages/admin/settings/admin_settings_view_model.dart';

/// Pengaturan platform Admin (Bab 11.3–11.6).
///
/// 🔴 Keempat halaman ini mengubah aturan yang berlaku bagi **seluruh
/// pelanggan sekaligus**, dan hampir semua kesalahannya tidak menghasilkan
/// galat apa pun — ia hanya membuat angka yang salah dibaca setiap perangkat.
/// Yang diuji di sini adalah persis kesalahan-kesalahan diam itu.
///
/// Dirender dengan `AppTheme` sungguhan (aturan 18).
void main() {
  /// 🔴 Overrides diterima sebagai FUNGSI PEMBUNGKUS, bukan sebagai
  /// `List<Override>`. `flutter_riverpod` 3.3.2 tidak mengekspor tipe
  /// `Override` sama sekali (lihat daftar `show` di `flutter_riverpod.dart`),
  /// jadi tipenya tidak dapat disebut di berkas ini — tetapi di dalam
  /// pembungkusnya ia tersimpulkan sendiri dari literal daftarnya.
  Future<void> pasang(
    WidgetTester tester,
    Widget halaman,
    ProviderScope Function(Widget child) bungkus, {
    double lebar = 1000,
    double tinggi = 1600,
  }) async {
    tester.view.physicalSize = Size(lebar, tinggi);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      bungkus(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('id'),
          supportedLocales: AppL10n.supportedLocales,
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: halaman,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // -------------------------------------------------------------------------
  // 11.6 Metode pembayaran
  // -------------------------------------------------------------------------

  group('Metode pembayaran (Bab 11.6)', () {
    late _VmMetode vm;

    Future<void> buka(WidgetTester tester, PaymentMethods isi) async {
      vm = _VmMetode(isi);
      await pasang(
        tester,
        const AdminPaymentMethodsPage(),
        (child) => ProviderScope(
          overrides: [
            adminPaymentMethodsViewModelProvider.overrideWith(() => vm),
          ],
          child: child,
        ),
      );
    }

    testWidgets('🔴 tidak ada satu pun kolom untuk kunci rahasia Midtrans', (
      tester,
    ) async {
      // Bab 11.6 menuliskannya sebagai larangan. Kunci server Midtrans yang
      // tersimpan di `platform_settings` dapat dipakai menagih atas nama
      // Product Owner oleh siapa pun yang berhasil masuk sebagai admin.
      //
      // Tes ini menjaga agar tidak ada yang menambahkannya "supaya praktis".
      await buka(tester, const PaymentMethods(midtransEnabled: true));

      // Hanya dua sakelar dan tidak ada kolom teks sama sekali di halaman ini.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(Switch), findsNWidgets(2));

      // Dan alasannya tertulis, bukan hanya dihilangkan diam-diam.
      expect(
        find.textContaining('hanya boleh hidup di Edge Function secrets'),
        findsOneWidget,
      );
    });

    testWidgets('🔴 mematikan kedua metode ditanyakan lebih dulu', (
      tester,
    ) async {
      // Mematikan keduanya membuat halaman Pembayaran pelanggan berhenti di
      // "Belum ada metode pembayaran yang aktif" — pendapatan berhenti sampai
      // ada yang menyadarinya.
      await buka(tester, const PaymentMethods(midtransEnabled: false));

      // Transfer manual satu-satunya yang menyala; mematikannya = mematikan
      // semuanya.
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Tidak ada satu pun jalan membeli paket'),
        findsOneWidget,
      );

      // Dibatalkan berarti TIDAK tersimpan.
      await tester.tap(find.widgetWithText(TextButton, 'Batal'));
      await tester.pumpAndSettle();
      expect(vm.disimpan, isEmpty);
    });

    testWidgets('menyalakan Midtrans tidak ditanyakan — bukan keadaan bahaya', (
      tester,
    ) async {
      await buka(tester, const PaymentMethods());

      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      expect(vm.disimpan.single.midtransEnabled, isTrue);
      // Transfer manual tetap menyala — keduanya memang hidup berdampingan
      // (Bab 12.1).
      expect(vm.disimpan.single.manualTransferEnabled, isTrue);
    });

    testWidgets('🔴 transfer manual aktif tanpa rekening diperingatkan merah', (
      tester,
    ) async {
      // Pelanggan akan melihat halaman instruksi transfer tanpa satu pun
      // nomor tujuan — diminta mentransfer entah ke mana.
      await buka(tester, const PaymentMethods());

      expect(
        find.textContaining('belum ada satu pun rekening'),
        findsOneWidget,
      );
    });

    testWidgets('tanpa transfer manual, daftar rekening kosong bukan masalah', (
      tester,
    ) async {
      await buka(
        tester,
        const PaymentMethods(
          manualTransferEnabled: false,
          midtransEnabled: true,
        ),
      );

      expect(find.text('Belum ada rekening.'), findsOneWidget);
      expect(find.textContaining('belum ada satu pun rekening'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // 11.3 Harga & paket
  // -------------------------------------------------------------------------

  group('Harga & paket (Bab 11.3)', () {
    late _VmHarga vm;

    Future<void> buka(WidgetTester tester, {num? biaya}) async {
      vm = _VmHarga(
        AdminPricingData(catalog: TierCatalog.fallback, infraCost: biaya),
      );
      await pasang(
        tester,
        const AdminPricingPage(),
        (child) => ProviderScope(
          overrides: [adminPricingViewModelProvider.overrideWith(() => vm)],
          child: child,
        ),
      );
    }

    testWidgets(
      '🔴 biaya infrastruktur kosong tersimpan sebagai null, bukan 0',
      (tester) async {
        // Nol membuat Dasbor Platform menulis margin = seluruh MRR, yang di
        // layar terbaca sebagai "seluruh pendapatan adalah keuntungan" —
        // kalimat paling menyesatkan yang bisa ditulis dasbor keuangan
        // (migrasi 30 keputusan 3).
        await buka(tester);

        // 🔴 Digulir dulu, BUKAN layar ujinya yang dibesarkan. Sejak paket
        // Bisnis ikut digambar (1 September 2026) halaman ini tiga kartu, dan
        // tombol Simpan jatuh di bawah lipatan layar 1000x1600. Membesarkan
        // layar uji akan membuat tes ini lulus sambil berhenti menangkap
        // persis jenis cacat tata letak yang ia ada untuk menangkapnya.
        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Simpan'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, 'Simpan'),
          ),
        );
        await tester.pumpAndSettle();

        expect(vm.disimpan, hasLength(1));
        expect(vm.disimpan.single.infraCost, isNull);
      },
    );

    testWidgets('biaya yang diisi terbawa apa adanya', (tester) async {
      await buka(tester, biaya: 500000);

      // Tiga kartu paket — tombolnya di bawah lipatan. Lihat keterangan di tes
      // pertama kelompok ini.
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Simpan'),
        ),
      );
      await tester.pumpAndSettle();

      expect(vm.disimpan.single.infraCost, 500000);
    });

    testWidgets(
      '🔴 dialog simpan mengatakan mana yang surut dan mana yang tidak',
      (tester) async {
        // Dua kalimat yang berlawanan dan keduanya benar: harga TIDAK berlaku
        // surut, tetapi batas-batasnya berlaku SEKETIKA. Menyebut salah satunya
        // saja membuat Admin menebak yang lain.
        await buka(tester);

        // Tiga kartu paket — tombolnya di bawah lipatan. Lihat keterangan di
        // tes pertama kelompok ini.
        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Simpan'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
        await tester.pumpAndSettle();

        expect(find.textContaining('tidak ditagih ulang'), findsOneWidget);
        expect(find.textContaining('berlaku seketika'), findsOneWidget);
      },
    );

    testWidgets(
      '🔴 -1 pada maksimal packer dijelaskan, bukan dibiarkan ditebak',
      (tester) async {
        // Tanpa keterangan ini yang mengisinya akan menulis 999 — bekerja,
        // tetapi membuat aturan "tanpa batas" tidak pernah benar-benar ada.
        await buka(tester);
        // 🔴 TIGA, bukan dua. Angka ini adalah jumlah kartu paket yang
        // benar-benar tergambar, dan sampai 1 September 2026 ia berbunyi 2 —
        // mengunci cacat yang membuat paket Bisnis tidak pernah digambar
        // sama sekali. Tes yang lulus itulah yang mempertahankannya.
        expect(
          find.textContaining('Isi -1 untuk tanpa batas'),
          findsNWidgets(3),
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // 11.5 Kontak
  // -------------------------------------------------------------------------

  group('Kontak dukungan (Bab 11.5)', () {
    late _VmKontak vm;

    Future<void> buka(WidgetTester tester, PlatformContact isi) async {
      vm = _VmKontak(isi);
      await pasang(
        tester,
        const AdminContactPage(),
        (child) => ProviderScope(
          overrides: [adminContactViewModelProvider.overrideWith(() => vm)],
          child: child,
        ),
      );
    }

    testWidgets('🔴 nomor lokal 08… diperingatkan sebelum tersimpan', (
      tester,
    ) async {
      // `wa.me/08…` TETAP TERBUKA tetapi tidak menemukan siapa-siapa. Tidak
      // ada galat sama sekali, dan yang menyadarinya adalah pelanggan yang
      // gagal menghubungi — jauh setelah kejadiannya.
      await buka(tester, const PlatformContact(whatsapp: '085113214018'));

      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();

      expect(find.textContaining('tidak diawali 62'), findsOneWidget);
      expect(vm.disimpan, isEmpty);
    });

    testWidgets('nomor internasional tersimpan tanpa ditanya', (tester) async {
      await buka(tester, const PlatformContact(whatsapp: '6285113214018'));

      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();

      expect(vm.disimpan.single.whatsapp, '6285113214018');
    });

    test('aturan bentuk nomor dapat diuji tanpa menggambar apa pun', () {
      expect(
        const PlatformContact(whatsapp: '6285113214018').waLooksInternational,
        isTrue,
      );
      expect(
        const PlatformContact(whatsapp: '085113214018').waLooksInternational,
        isFalse,
      );
      // Terlalu pendek untuk nomor mana pun, walaupun diawali 62.
      expect(
        const PlatformContact(whatsapp: '62851').waLooksInternational,
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  // 11.4 Promo
  // -------------------------------------------------------------------------

  group('Kode promo (Bab 11.4)', () {
    Promo promo({
      String code = 'HEMAT10',
      String type = 'percent',
      num value = 10,
      int used = 0,
      int? maxUses,
    }) => Promo(
      code: code,
      discountType: type,
      discountValue: value,
      validUntil: DateTime(2026, 12, 31),
      usedCount: used,
      maxUses: maxUses,
    );

    late _VmPromo vm;

    Future<void> buka(WidgetTester tester, List<Promo> isi) async {
      vm = _VmPromo(isi);
      await pasang(
        tester,
        const AdminPromosPage(),
        (child) => ProviderScope(
          overrides: [adminPromosViewModelProvider.overrideWith(() => vm)],
          child: child,
        ),
      );
    }

    testWidgets('🔴 potongan nominal melebihi harga terlihat sebelum disimpan', (
      tester,
    ) async {
      // Promo `fixed` Rp 150.000 pada paket Standar Rp 99.000 menghasilkan
      // tagihan NOL — dijepit supaya tidak negatif, tetapi tetap berarti paket
      // dibagikan gratis. Contoh perhitungan membuat itu terlihat sebelum
      // tombol Simpan ditekan.
      await buka(tester, const []);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Kode baru'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nominal'));
      await tester.pumpAndSettle();

      final nilai = find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .at(1);
      await tester.enterText(nilai, '150000');
      await tester.pumpAndSettle();

      expect(find.textContaining('bayar Rp 0'), findsWidgets);
    });

    testWidgets(
      'kode yang sudah dipakai diperingatkan lebih tegas saat dihapus',
      (tester) async {
        // Menghapus kode yang pernah dipakai membuat riwayat pembayaran lama
        // kehilangan satu-satunya keterangan tentang potongannya.
        await buka(tester, [promo(used: 7)]);

        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();

        expect(find.textContaining('sudah dipakai 7 kali'), findsOneWidget);
        expect(
          find.textContaining('Menonaktifkannya lebih baik'),
          findsOneWidget,
        );
      },
    );

    testWidgets('kode yang belum pernah dipakai aman dihapus', (tester) async {
      await buka(tester, [promo()]);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.textContaining('belum pernah dipakai'), findsOneWidget);
    });

    testWidgets('🔴 kode tidak dapat diubah saat menyunting promo yang ada', (
      tester,
    ) async {
      // `code` adalah kunci utama tabelnya. Mengetik kode lain akan membuat
      // baris BARU, bukan mengganti nama — dan yang lama tetap hidup.
      await buka(tester, [promo()]);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      final kode = tester.widget<TextField>(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            )
            .first,
      );
      expect(kode.enabled, isFalse);
      expect(find.textContaining('membuat promo baru'), findsOneWidget);
    });

    testWidgets('daftar kosong mengatakannya, bukan halaman putih', (
      tester,
    ) async {
      await buka(tester, const []);
      expect(find.text('Belum ada kode promo'), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// ViewModel palsu
// ---------------------------------------------------------------------------

class _VmMetode extends AdminPaymentMethodsViewModel {
  _VmMetode(this._isi);

  final PaymentMethods _isi;
  final List<PaymentMethods> disimpan = [];

  @override
  Future<PaymentMethods> build() async => _isi;

  @override
  Future<AppFailure?> save(PaymentMethods methods) async {
    disimpan.add(methods);
    return null;
  }

  @override
  Future<void> refresh() async {}
}

class _VmHarga extends AdminPricingViewModel {
  _VmHarga(this._isi);

  final AdminPricingData _isi;
  final List<({List<TierConfig> tiers, num? infraCost})> disimpan = [];

  @override
  Future<AdminPricingData> build() async => _isi;

  @override
  Future<AppFailure?> save({
    required List<TierConfig> tiers,
    required num? infraCost,
  }) async {
    disimpan.add((tiers: tiers, infraCost: infraCost));
    return null;
  }

  @override
  Future<void> refresh() async {}
}

class _VmKontak extends AdminContactViewModel {
  _VmKontak(this._isi);

  final PlatformContact _isi;
  final List<PlatformContact> disimpan = [];

  @override
  Future<PlatformContact> build() async => _isi;

  @override
  Future<AppFailure?> save(PlatformContact contact) async {
    disimpan.add(contact);
    return null;
  }

  @override
  Future<void> refresh() async {}
}

class _VmPromo extends AdminPromosViewModel {
  _VmPromo(this._isi);

  final List<Promo> _isi;
  final List<Promo> disimpan = [];
  final List<String> dihapus = [];

  @override
  Future<List<Promo>> build() async => _isi;

  @override
  Future<AppFailure?> upsert(Promo promo) async {
    disimpan.add(promo);
    return null;
  }

  @override
  Future<AppFailure?> delete(String code) async {
    dihapus.add(code);
    return null;
  }

  @override
  Future<void> refresh() async {}
}
