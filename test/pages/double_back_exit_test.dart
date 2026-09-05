import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kamelscan/core/widgets/double_back_exit.dart';
import 'package:kamelscan/l10n/generated/app_localizations.dart';

/// Tombol Kembali menutup aplikasi dalam satu ketukan — laporan Product Owner
/// 5 September 2026: *"saat saya tidak sengaja klik kembali aplikasinya
/// langsung keluar"*.
///
/// 🔴 Yang diuji di sini bukan tampilan, melainkan **apa yang dikirim ke
/// sistem**. Satu-satunya perbedaan antara "aplikasi keluar" dan "aplikasi
/// tetap terbuka" adalah satu pesan `SystemNavigator.pop` di kanal platform,
/// dan pesan itu tidak meninggalkan jejak apa pun di layar. Tanpa menyadapnya,
/// tes yang paling teliti sekalipun akan lulus pada dua-duanya.
///
/// ⚠️ 402 × 874 dp — ukuran yang dipakai desainer, di tengah rentang Android
/// kelas menengah (Redmi Note 9 = 393 × 851, Pixel 8 = 412 × 892). Dipakai
/// karena yang muncul pada ketukan pertama adalah SnackBar, dan SnackBar
/// mengambil lebar layar.
void main() {
  /// Setiap `SystemNavigator.pop` yang dikirim widget, terkumpul di sini.
  late List<String> keluar;

  setUp(() {
    keluar = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') keluar.add(call.method);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  void pakaiLayarHp(WidgetTester tester) {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pasang(WidgetTester tester) async {
    pakaiLayarHp(tester);
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('id'),
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: [
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: DoubleBackToExit(
          child: Scaffold(body: Center(child: Text('BERANDA'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Meniru tombol Kembali perangkat, bukan tombol kembali di layar.
  ///
  /// Inilah jalur yang dipakai Android: sistem mengirim `popRoute` lewat kanal
  /// navigasi, dan `PopScope` menyadapnya. Memanggil `Navigator.pop` langsung
  /// akan melewati `PopScope` sama sekali dan menguji sesuatu yang bukan
  /// keluhannya.
  Future<void> tekanKembali(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pump();
  }

  testWidgets('ketukan pertama tidak menutup aplikasi', (tester) async {
    await pasang(tester);
    await tekanKembali(tester);

    expect(keluar, isEmpty);
    expect(find.text('BERANDA'), findsOneWidget);
  });

  testWidgets('🔴 ketukan pertama memberi tahu, dan pesannya tergambar',
      (tester) async {
    await pasang(tester);
    await tekanKembali(tester);
    await tester.pump(const Duration(milliseconds: 300));

    // Menahan diam-diam lebih buruk daripada langsung keluar: yang menekan
    // Kembali dan tidak melihat apa-apa akan menekannya berkali-kali.
    expect(find.text('Tekan sekali lagi untuk keluar dari aplikasi'),
        findsOneWidget);
  });

  testWidgets('ketukan kedua menutup aplikasi', (tester) async {
    await pasang(tester);
    await tekanKembali(tester);
    await tekanKembali(tester);

    expect(keluar, ['SystemNavigator.pop']);
  });

  testWidgets('ketukan kedua yang terlambat tidak menutup aplikasi',
      (tester) async {
    await pasang(tester);
    await tekanKembali(tester);

    // Lewat dari jeda dua detik. Ketukan tak sengaja beberapa detik kemudian
    // adalah persis keluhan yang sedang diperbaiki — ia harus memulai
    // hitungan dari awal, bukan melanjutkan yang lama.
    await tester.pump(const Duration(seconds: 3));
    await tekanKembali(tester);

    expect(keluar, isEmpty);
    expect(find.text('Tekan sekali lagi untuk keluar dari aplikasi'),
        findsOneWidget);
  });

  testWidgets('sesudah jeda lewat, dua ketukan tetap menutup aplikasi',
      (tester) async {
    await pasang(tester);
    await tekanKembali(tester);
    await tester.pump(const Duration(seconds: 3));

    await tekanKembali(tester);
    await tekanKembali(tester);

    expect(keluar, ['SystemNavigator.pop']);
  });
}
