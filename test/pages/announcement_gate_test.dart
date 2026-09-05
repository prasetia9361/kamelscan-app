import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kamelscan/core/models/announcement.dart';
import 'package:kamelscan/core/providers/announcement_provider.dart';
import 'package:kamelscan/core/theme/app_theme.dart';
import 'package:kamelscan/core/widgets/announcement_gate.dart';
import 'package:kamelscan/l10n/generated/app_localizations.dart';

/// Iklan & pengumuman saat login (migrasi 50), diminta Product Owner
/// 5 September 2026.
///
/// 🔴 Yang diuji di sini adalah satu-satunya hal yang tidak dapat dibuktikan
/// `analyze` maupun tes model: **apakah dialognya benar-benar tergambar, dan
/// apakah yang mengunci benar-benar tidak punya jalan keluar.** Perbedaan
/// antara "pengumuman wajib update" dan "seluruh pelanggan terkurung" adalah
/// ada-tidaknya satu tanda silang di layar.
///
/// ⚠️ 402 × 874 dp — ukuran yang dipakai desainer, di tengah rentang Android
/// kelas menengah (Redmi Note 9 = 393 × 851, Pixel 8 = 412 × 892).
void main() {
  void pakaiLayarHp(WidgetTester tester) {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// Merangkai gerbang di atas satu layar seadanya, dengan daftar pengumuman
  /// yang sudah ditentukan.
  ///
  /// Providernya digantikan, bukan Supabase-nya dipalsukan: yang diuji layar,
  /// dan layar tidak pernah tahu daftarnya datang dari mana.
  Future<void> pasang(
    WidgetTester tester,
    List<Announcement> daftar,
  ) async {
    pakaiLayarHp(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAnnouncementsProvider.overrideWith((ref) async => daftar),
        ],
        child: MaterialApp(
          locale: const Locale('id'),
          supportedLocales: AppL10n.supportedLocales,
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Tema aslinya, bukan tema bawaan: dialognya membaca `AppColors`
          // lewat `Theme.of(context).extension<AppColors>()!`, dan tanpa tema
          // ini baris itu melempar.
          theme: AppTheme.light,
          home: const AnnouncementGate(
            child: Scaffold(body: Center(child: Text('BERANDA'))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Announcement buat({
    String id = 'a1',
    String title = 'Ada event akhir bulan',
    String body = 'Diskon token sampai 30 September.',
    AnnouncementKind kind = AnnouncementKind.normal,
    String? actionUrl,
    String? actionLabel,
  }) =>
      Announcement(
        id: id,
        title: title,
        body: body,
        kind: kind,
        actionUrl: actionUrl,
        actionLabel: actionLabel,
        createdAt: DateTime(2026, 9, 5),
      );

  testWidgets('tanpa pengumuman, layarnya tidak diganggu apa pun',
      (tester) async {
    await pasang(tester, const []);

    expect(find.text('BERANDA'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  group('Pengumuman biasa', () {
    testWidgets('🔴 judul, isi, dan tanda silangnya tergambar', (tester) async {
      await pasang(tester, [buat()]);

      expect(find.text('Ada event akhir bulan'), findsOneWidget);
      expect(find.text('Diskon token sampai 30 September.'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('tombol aksinya memakai teks dari Admin', (tester) async {
      await pasang(tester, [
        buat(
          actionUrl: 'https://contoh.test/event',
          actionLabel: 'Lihat detail',
        ),
      ]);

      expect(find.text('Lihat detail'), findsOneWidget);
    });

    testWidgets('tanpa teks tombol, dipakai kata bawaan', (tester) async {
      await pasang(tester, [buat(actionUrl: 'https://contoh.test/event')]);

      expect(find.text('Buka'), findsOneWidget);
    });

    testWidgets('tanpa tautan, tidak ada tombol aksi sama sekali',
        (tester) async {
      await pasang(tester, [buat()]);

      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('Pengumuman penting', () {
    List<Announcement> wajibUpdate() => [
          buat(
            id: 'update',
            title: 'Versi baru KamelScan',
            body: 'Perbarui aplikasi untuk melanjutkan.',
            kind: AnnouncementKind.important,
            actionUrl: 'https://play.google.com/store/apps/details?id=x',
            actionLabel: 'Perbarui sekarang',
          ),
        ];

    testWidgets('🔴 TIDAK punya tanda silang', (tester) async {
      await pasang(tester, wajibUpdate());

      expect(find.text('Versi baru KamelScan'), findsOneWidget);
      // Inilah bedanya dengan pengumuman biasa, dan satu-satunya yang
      // membuatnya benar-benar mengunci.
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('memberi tahu kenapa tidak ada jalan keluar', (tester) async {
      await pasang(tester, wajibUpdate());

      // Tanpa penanda ini orang akan mencari tanda silang yang memang tidak
      // ada, dan menyimpulkan aplikasinya rusak.
      expect(find.text('Wajib diperbarui'), findsOneWidget);
    });

    testWidgets('tombol aksinya ada — satu-satunya yang dapat ditekan',
        (tester) async {
      await pasang(tester, wajibUpdate());

      expect(find.text('Perbarui sekarang'), findsOneWidget);
    });

    testWidgets('🔴 mengetuk latar tidak menutupnya', (tester) async {
      await pasang(tester, wajibUpdate());

      // Jalan keluar yang tidak terlihat sama sekali, dan justru yang paling
      // mudah dilakukan tanpa sengaja.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Versi baru KamelScan'), findsOneWidget);
    });

    testWidgets('yang mengunci muncul lebih dulu daripada yang biasa',
        (tester) async {
      await pasang(tester, [
        buat(id: 'event'),
        ...wajibUpdate(),
      ]);

      expect(find.text('Versi baru KamelScan'), findsOneWidget);
      expect(find.text('Ada event akhir bulan'), findsNothing);
    });
  });
}
