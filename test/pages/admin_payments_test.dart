import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/models/enums.dart';
import 'package:kamelscan/core/models/pending_payment.dart';
import 'package:kamelscan/core/models/subscription.dart';
import 'package:kamelscan/core/theme/app_theme.dart';
import 'package:kamelscan/core/utils/app_failure.dart';
import 'package:kamelscan/core/widgets/app_state_views.dart';
import 'package:kamelscan/l10n/generated/app_localizations.dart';
import 'package:kamelscan/pages/admin/payments/admin_payments_page.dart';
import 'package:kamelscan/pages/admin/payments/admin_payments_view_model.dart';

/// Verifikasi pembayaran Admin (Bab 12.2).
///
/// 🔴 Ini satu-satunya layar yang menyentuh **uang sungguhan**, dan
/// persetujuannya tidak dapat dibatalkan. Yang diuji di sini karena itu bukan
/// keindahannya melainkan **penjagaannya**: tidak ada jalan menyetujui tanpa
/// melewati dialog yang menyebut nama usaha dan paketnya.
void main() {
  PendingPayment contoh({
    String id = 'sub1',
    String? nama = 'Sarang Sarung',
    TierPlan plan = TierPlan.standar,
    num jumlah = 99627,
    String? bukti = 't1/sub1.jpg',
  }) =>
      PendingPayment(
        businessName: nama,
        subscription: Subscription(
          id: id,
          tenantId: 't1-0b5ae403-panjang-sekali',
          plan: plan,
          amount: jumlah,
          proofUrl: bukti,
          createdAt: DateTime(2026, 8, 22, 9, 50),
        ),
      );

  late _VmPalsu vm;

  Future<void> pasang(
    WidgetTester tester, {
    List<PendingPayment>? daftar,
    AppFailure? gagal,
    double lebar = 900,
  }) async {
    tester.view.physicalSize = Size(lebar, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    vm = _VmPalsu(daftar: daftar, gagal: gagal);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminPaymentsViewModelProvider.overrideWith(() => vm),
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
          home: const AdminPaymentsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Empat kondisi Bab 3.4', () {
    testWidgets('kosong berkata tidak ada yang menunggu', (tester) async {
      await pasang(tester, daftar: const []);

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('Tidak ada pembayaran menunggu'), findsOneWidget);
    });

    testWidgets('gagal menampilkan pesan manusia', (tester) async {
      await pasang(tester, gagal: AppFailure.network);
      expect(find.byType(AppErrorView), findsOneWidget);
    });

    testWidgets('berisi menampilkan nama usaha, nominal, dan tanggalnya',
        (tester) async {
      await pasang(tester, daftar: [contoh()]);

      expect(find.text('Sarang Sarung'), findsOneWidget);
      // Nominalnya yang dicocokkan dengan mutasi rekening — sering berbeda
      // beberapa ratus rupiah karena kode unik transfer.
      expect(find.text('Rp 99.627'), findsOneWidget);
      expect(find.textContaining('Menunggu sejak'), findsOneWidget);
    });
  });

  group('🔴 Penjagaan sebelum uang berpindah', () {
    testWidgets('menekan Setujui TIDAK langsung menyetujui', (tester) async {
      await pasang(tester, daftar: [contoh()]);

      await tester.tap(find.widgetWithText(FilledButton, 'Setujui'));
      await tester.pumpAndSettle();

      // Yang muncul dialog, bukan persetujuan.
      expect(vm.disetujui, isEmpty);
      expect(find.text('Setujui pembayaran ini?'), findsOneWidget);
    });

    testWidgets('dialognya menyebut NAMA USAHA dan paketnya', (tester) async {
      // Satu-satunya penjagaan terhadap menyetujui baris yang salah adalah
      // melihat namanya tertulis ulang sebelum menekan.
      await pasang(tester, daftar: [contoh(nama: 'Sarang Sarung')]);

      await tester.tap(find.widgetWithText(FilledButton, 'Setujui'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sarang Sarung'), findsWidgets);
      expect(find.textContaining('Standar'), findsWidgets);
      // Dikatakan apa adanya bahwa tidak ada jalan kembali.
      expect(find.textContaining('Tidak ada tombol pembatalan'), findsOneWidget);
    });

    testWidgets('membatalkan dialog tidak menyetujui apa pun', (tester) async {
      await pasang(tester, daftar: [contoh()]);

      await tester.tap(find.widgetWithText(FilledButton, 'Setujui'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Batal'));
      await tester.pumpAndSettle();

      expect(vm.disetujui, isEmpty);
    });

    testWidgets('menekan Setujui di dialog barulah menyetujui', (tester) async {
      await pasang(tester, daftar: [contoh(id: 'sub-uang')]);

      await tester.tap(find.widgetWithText(FilledButton, 'Setujui'));
      await tester.pumpAndSettle();
      // Tombol di dalam dialog, bukan yang di kartu.
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Setujui'),
      ));
      await tester.pumpAndSettle();

      expect(vm.disetujui, ['sub-uang']);
    });
  });

  group('Penolakan mengatakan akibatnya apa adanya', () {
    testWidgets('dialognya menyebut uang tidak dikembalikan', (tester) async {
      await pasang(tester, daftar: [contoh()]);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Tolak'));
      await tester.pumpAndSettle();

      // Dialog yang menyembunyikan ini membuat Admin mengira keduanya sudah
      // diurus aplikasi.
      expect(
        find.textContaining('tidak mengembalikan uang'),
        findsOneWidget,
      );
      expect(vm.ditolak, isEmpty);
    });
  });

  group('Nama usaha yang kosong', () {
    testWidgets('jatuh ke potongan id, bukan baris tanpa identitas',
        (tester) async {
      await pasang(tester, daftar: [contoh(nama: null)]);

      // Lebih baik sepotong id daripada kartu tanpa satu pun penanda siapa
      // yang membayar.
      expect(find.text('t1-0b5ae'), findsOneWidget);
    });

    test('label memakai nama usaha bila ada', () {
      expect(contoh(nama: 'Toko Berkah').label, 'Toko Berkah');
      expect(contoh(nama: '   ').label, 't1-0b5ae');
    });
  });

  group('Tanpa bukti transfer', () {
    testWidgets('tombol lihat bukti tidak melakukan apa-apa bila jalurnya kosong',
        (tester) async {
      // Baris tanpa bukti seharusnya tidak pernah sampai ke sini — kuerinya
      // menyaring `proof_url is not null`. Ini penjagaan lapis kedua.
      await pasang(tester, daftar: [contoh(bukti: null)]);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Lihat bukti transfer'));
      await tester.pumpAndSettle();

      expect(vm.buktiDiminta, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}

/// ViewModel palsu yang **mencatat** perintah alih-alih menjalankannya.
///
/// Tidak satu pun metodenya menyentuh jaringan: yang diuji di berkas ini
/// penjagaan sebelum uang berpindah, bukan perpindahannya.
class _VmPalsu extends AdminPaymentsViewModel {
  _VmPalsu({this.daftar, this.gagal});

  final List<PendingPayment>? daftar;
  final AppFailure? gagal;

  final List<String> disetujui = [];
  final List<String> ditolak = [];
  final List<String> buktiDiminta = [];

  @override
  Future<List<PendingPayment>> build() async {
    if (gagal != null) throw gagal!;
    return daftar!;
  }

  @override
  Future<AppFailure?> approve(String subscriptionId) async {
    disetujui.add(subscriptionId);
    return null;
  }

  @override
  Future<AppFailure?> reject(String subscriptionId) async {
    ditolak.add(subscriptionId);
    return null;
  }

  @override
  Future<String?> proofUrl(String path) async {
    buktiDiminta.add(path);
    return null;
  }

  @override
  Future<void> refresh() async {}
}
