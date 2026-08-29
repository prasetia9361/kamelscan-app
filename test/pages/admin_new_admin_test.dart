import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/theme/app_theme.dart';
import 'package:kamelscan/l10n/generated/app_localizations.dart';
import 'package:kamelscan/pages/admin/settings/admin_new_admin_page.dart';

/// Panduan membuat akun Admin (Bab 2.2).
///
/// 🔴 Bab 2.2 melarang jalur menjadi admin dari dalam aplikasi: *"Dibuat manual
/// di database, tidak ada jalur registrasi menjadi admin dari aplikasi."*
/// Halaman ini karena itu hanya menyusun perintah SQL, dan tes pertama di
/// bawah menjaga agar tidak ada yang mengubahnya menjadi tombol "Buat" suatu
/// hari nanti karena terasa lebih praktis.
void main() {
  Future<void> pasang(WidgetTester tester, {double tinggi = 2400}) async {
    tester.view.physicalSize = Size(1000, tinggi);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
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
        home: const AdminNewAdminPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Satu-satunya kolom teks di halaman ini adalah email.
  final kolomEmail = find.byType(TextField);

  group('🔴 Halaman ini tidak boleh membuat akun', () {
    testWidgets('tidak ada kolom kata sandi, dan alasannya tertulis', (
      tester,
    ) async {
      // Membuat admin menuntut kredensial Supabase Dashboard yang terpisah
      // dari login aplikasi. Kalau satu akun admin dibobol, penyerangnya tidak
      // dapat mencetak admin baru untuk bertahan di dalam.
      await pasang(tester);

      // Hanya SATU kolom: email. Tidak ada nama, tidak ada kata sandi.
      expect(kolomEmail, findsOneWidget);

      expect(
        find.textContaining('tidak ada jalur menjadi admin dari dalam'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('memperingatkan agar Dashboard tidak dibagikan', (
      tester,
    ) async {
      await pasang(tester);
      expect(
        find.textContaining('Jangan berikan akses Supabase Dashboard'),
        findsOneWidget,
      );
    });
  });

  group('Perintah SQL yang disusun', () {
    testWidgets('belum muncul sebelum emailnya diisi', (tester) async {
      // Perintah yang muncul dengan email kosong akan mengenai SELURUH baris
      // `users` bila ada yang menempelnya tanpa membaca.
      await pasang(tester);

      expect(find.textContaining('update public.users'), findsNothing);
      expect(find.textContaining('Isi emailnya lebih dulu'), findsOneWidget);
    });

    testWidgets('🔴 memeriksa dulu, baru mengubah — dua blok terpisah', (
      tester,
    ) async {
      // `update` yang langsung dijalankan tanpa melihat namanya dapat
      // menaikkan orang yang keliru menjadi admin platform, dan tidak ada
      // galat apa pun yang muncul.
      await pasang(tester);
      await tester.enterText(kolomEmail, 'budi@contoh.com');
      await tester.pumpAndSettle();

      expect(
        find.textContaining('select id, email, full_name'),
        findsOneWidget,
      );
      expect(find.textContaining("set role = 'admin'"), findsOneWidget);

      // Urutannya dikatakan, bukan hanya diurutkan.
      expect(find.textContaining('TEPAT SATU baris'), findsOneWidget);
    });

    testWidgets('emailnya ikut masuk ke perintahnya', (tester) async {
      await pasang(tester);
      await tester.enterText(kolomEmail, 'budi@contoh.com');
      await tester.pumpAndSettle();

      expect(
        find.textContaining("normalize_email('budi@contoh.com')"),
        findsWidgets,
      );
    });

    testWidgets('🔴 tanda kutip di dalam email tidak memutus perintahnya', (
      tester,
    ) async {
      // `o'brien@contoh.com` adalah alamat yang sah. Satu tanda kutip yang
      // lolos akan memutus perintah SQL di tengah — dan ini perintah yang
      // ditempel ke SQL Editor produksi.
      await pasang(tester);
      await tester.enterText(kolomEmail, "o'brien@contoh.com");
      await tester.pumpAndSettle();

      expect(
        find.textContaining("normalize_email('o''brien@contoh.com')"),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('menyediakan perintah pembatalan bila salah orang', (
      tester,
    ) async {
      await pasang(tester);
      await tester.enterText(kolomEmail, 'budi@contoh.com');
      await tester.pumpAndSettle();

      expect(find.textContaining("set role = 'owner'"), findsOneWidget);
    });
  });

  group('Dua jebakan P.3 wajib tertulis', () {
    testWidgets('alias Gmail ditolak', (tester) async {
      // `normalize_email` membuang segala yang setelah + untuk domain gmail,
      // jadi nama+admin@gmail.com dianggap sama persis dengan nama@gmail.com.
      // Aturan anti-penyalahgunaan Bab 7.5 mengenai pemiliknya sendiri.
      await pasang(tester);
      expect(find.textContaining('alias Gmail'), findsOneWidget);
    });

    testWidgets('wajib keluar-masuk sesudah perannya diubah', (tester) async {
      // Perannya dibawa di dalam JWT. Sebelum keluar-masuk, gejalanya terlihat
      // persis seperti perintah SQL-nya gagal — padahal berhasil.
      await pasang(tester);
      await tester.enterText(kolomEmail, 'budi@contoh.com');
      await tester.pumpAndSettle();

      expect(find.textContaining('keluar lalu masuk lagi'), findsWidgets);
    });
  });
}
