import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kamelscan/core/theme/app_theme.dart';
import 'package:kamelscan/l10n/generated/app_localizations.dart';
import 'package:kamelscan/pages/payment/plan_page.dart';
import 'package:kamelscan/pages/payment/plan_view_model.dart';

/// Rangka halaman Pembayaran di HP — perbaikan navigasi 5 September 2026.
///
/// 🔴 Sampai hari itu halaman ini hidup DI DALAM cabang Akun dan menumpang
/// Scaffold milik rangka mobile. Sejak Pembayaran dipindahkan ke luar rangka
/// — supaya berhenti menumpuk di cabang Beranda saat di-`push` dari sana — ia
/// tidak lagi punya siapa pun yang menyediakan latar maupun tombol kembali,
/// jadi keduanya dipasang di dalam halamannya sendiri.
///
/// ⚠️ Kekeliruan di sini tidak menghasilkan galat apa pun. Yang terjadi hanya
/// halaman tanpa latar dan **tanpa satu pun jalan kembali ke Beranda** — dan
/// itu hanya terlihat dengan menggambarnya pada layar berukuran nyata.
///
/// 402 × 874 dp — ukuran yang dipakai desainer, di tengah rentang Android
/// kelas menengah (Redmi Note 9 = 393 × 851, Pixel 8 = 412 × 892).
void main() {
  testWidgets('🔴 punya Scaffold, kepala halaman, dan tombol kembali sendiri',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [planViewModelProvider.overrideWith(_VmMenunggu.new)],
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
          // Halaman sebelumnya, supaya ada yang dapat dituju tombol kembali —
          // persis seperti Beranda di aplikasi sungguhan.
          home: const _Beranda(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('BUKA PEMBAYARAN'));
    // ⚠️ `pump` berjangka, bukan `pumpAndSettle`. Selagi paketnya dimuat,
    // halaman ini menampilkan `AppListSkeleton` — animasi kilau yang berulang
    // selamanya, sehingga `pumpAndSettle` tidak pernah selesai menunggu.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(Scaffold), findsWidgets);
    expect(find.text('Pembayaran'), findsOneWidget);

    // Inilah yang hilang kalau Scaffold-nya lupa dipasang: satu-satunya jalan
    // kembali ke Beranda.
    expect(find.byType(BackButton), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('BUKA PEMBAYARAN'), findsOneWidget);
  });
}

class _Beranda extends StatelessWidget {
  const _Beranda();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PlanPage()),
            ),
            child: const Text('BUKA PEMBAYARAN'),
          ),
        ),
      );
}

/// Isi halamannya sengaja tidak pernah selesai dimuat.
///
/// Yang diuji rangkanya, bukan isinya: kepala halaman dan tombol kembali harus
/// sudah tergambar bahkan selagi paketnya masih diambil dari server — justru
/// pada saat itulah orang paling mungkin ingin membatalkan dan kembali.
class _VmMenunggu extends PlanViewModel {
  @override
  Future<PlanData> build() => Completer<PlanData>().future;
}
