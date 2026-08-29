import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kamelscan/core/models/enums.dart';
import 'package:kamelscan/core/models/pending_payment.dart';
import 'package:kamelscan/core/models/subscription.dart';
import 'package:kamelscan/core/theme/app_theme.dart';
import 'package:kamelscan/l10n/generated/app_localizations.dart';
import 'package:kamelscan/navigation/route_names.dart';
import 'package:kamelscan/pages/account/widgets/logout_button.dart';
import 'package:kamelscan/pages/admin/dashboard/admin_dashboard_page.dart';
import 'package:kamelscan/pages/admin/payments/admin_payments_view_model.dart';

/// Halaman pembuka panel Admin (Bab 11).
///
/// 🔴 Dua hal yang diuji di sini keduanya lahir dari cacat yang dialami
/// Product Owner sendiri pada 28 Agustus 2026:
///
///   1. Panel admin **tidak dapat dicapai**. Halaman Verifikasi Pembayaran
///      sudah selesai dibangun, tetapi tidak ada satu pun tautan menuju ke
///      sana — hanya dapat dibuka dengan mengetik alamatnya.
///   2. Admin **terkurung**. Rute admin berdiri di luar rangka aplikasi
///      sehingga tidak ada menu bawah maupun sidebar, sementara penjagaan rute
///      melempar balik siapa pun yang sudah masuk. Tanpa tombol Keluar, tidak
///      ada jalan kembali ke akun sendiri selain membersihkan simpanan
///      peramban.
void main() {
  PendingPayment contoh(String id) => PendingPayment(
        businessName: 'Sarang Sarung',
        subscription: Subscription(
          id: id,
          tenantId: 't1',
          plan: TierPlan.standar,
          amount: 99627,
          proofUrl: 't1/$id.jpg',
          createdAt: DateTime(2026, 8, 22),
        ),
      );

  late String alamat;

  Future<void> pasang(
    WidgetTester tester, {
    required List<PendingPayment> menunggu,
  }) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    alamat = Routes.adminDashboard;

    final router = GoRouter(
      initialLocation: Routes.adminDashboard,
      routes: [
        GoRoute(
          path: Routes.adminDashboard,
          builder: (_, _) => const AdminDashboardPage(),
          routes: [
            GoRoute(
              path: 'payments',
              builder: (_, _) => const Scaffold(body: Text('halaman bayar')),
            ),
            GoRoute(
              path: 'stats',
              builder: (_, _) => const Scaffold(body: Text('halaman angka')),
            ),
          ],
        ),
      ],
    );
    router.routerDelegate.addListener(() {
      alamat = router.state.uri.path;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminPaymentsViewModelProvider.overrideWith(() => _VmPalsu(menunggu)),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('id'),
          supportedLocales: AppL10n.supportedLocales,
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('🔴 Panelnya dapat dicapai', () {
    testWidgets('menu Verifikasi Pembayaran ada dan dapat ditekan',
        (tester) async {
      await pasang(tester, menunggu: [contoh('a')]);

      expect(find.text('Verifikasi Pembayaran'), findsOneWidget);

      await tester.tap(find.text('Verifikasi Pembayaran'));
      await tester.pumpAndSettle();

      expect(alamat, Routes.adminPayments);
    });

    testWidgets('jumlah yang menunggu ditulis di menunya', (tester) async {
      // Inilah satu-satunya pekerjaan admin yang punya tenggat: uang sudah
      // masuk ke rekening dan pelanggannya sedang menunggu. Menyembunyikan
      // angkanya sampai halaman dibuka membuat tenggat itu tak terlihat.
      await pasang(tester, menunggu: [contoh('a'), contoh('b')]);

      expect(find.text('2 menunggu verifikasi'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('tanpa antrean, menunya berkata tidak ada yang menunggu',
        (tester) async {
      await pasang(tester, menunggu: const []);

      expect(find.text('Tidak ada yang menunggu'), findsOneWidget);
      // Lencana angka tidak muncul saat nol — lencana "0" hanya menarik mata
      // ke pekerjaan yang tidak ada.
      expect(find.text('0'), findsNothing);
    });
  });

  group('🔴 Admin tidak boleh terkurung', () {
    testWidgets('tombol Keluar selalu ada di panel admin', (tester) async {
      await pasang(tester, menunggu: const []);

      // Rute admin tidak punya menu bawah maupun sidebar, dan penjagaan rute
      // melempar balik siapa pun yang sudah masuk. Ini satu-satunya jalan
      // kembali ke akun sendiri.
      expect(find.byType(LogoutButton), findsOneWidget);
    });
  });

  group('Dasbor Platform dapat dicapai', () {
    testWidgets('menunya ada dan berpindah ke halaman angka', (tester) async {
      await pasang(tester, menunggu: const []);

      expect(find.text('Dasbor Platform'), findsOneWidget);

      await tester.tap(find.text('Dasbor Platform'));
      await tester.pumpAndSettle();

      expect(alamat, Routes.adminStats);
    });
  });

  group('Menu yang belum jadi tetap ditampilkan', () {
    testWidgets('ditulis apa adanya "Belum dikerjakan", bukan disembunyikan',
        (tester) async {
      // Menyembunyikannya membuat panel admin terlihat hanya punya satu
      // halaman, dan orang berikutnya akan mengira sisanya memang tidak
      // direncanakan.
      await pasang(tester, menunggu: const []);

      expect(find.text('Kelola Pengguna'), findsOneWidget);
      expect(find.text('Belum dikerjakan'), findsOneWidget);
    });

    testWidgets('🔴 SATU menu pengguna, bukan dua', (tester) async {
      // Sampai 29 Agustus 2026 ada "Kelola Pengguna" DAN "Daftar Pelanggan" —
      // keduanya karangan, bukan dari dokumen. Bab 11.2 hanya menyebut satu
      // halaman. Menu yang tidak ada di spesifikasi membuat orang berikutnya
      // membangun dua halaman untuk pekerjaan yang satu.
      await pasang(tester, menunggu: const []);
      expect(find.text('Daftar Pelanggan'), findsNothing);
    });

    testWidgets('menekannya tidak berpindah ke mana pun', (tester) async {
      await pasang(tester, menunggu: const []);

      await tester.tap(find.text('Kelola Pengguna'));
      await tester.pumpAndSettle();

      expect(alamat, Routes.adminDashboard);
      expect(tester.takeException(), isNull);
    });
  });
}

class _VmPalsu extends AdminPaymentsViewModel {
  _VmPalsu(this._daftar);

  final List<PendingPayment> _daftar;

  @override
  Future<List<PendingPayment>> build() async => _daftar;
}
