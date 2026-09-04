import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/config/tier_config.dart';
import 'package:kamelscan/core/models/app_user.dart';
import 'package:kamelscan/core/models/enums.dart';
import 'package:kamelscan/core/models/tenant.dart';
import 'package:kamelscan/core/providers/repository_providers.dart';
import 'package:kamelscan/core/providers/session_provider.dart';
import 'package:kamelscan/core/repositories/account_deletion_repository.dart';
import 'package:kamelscan/core/theme/app_theme.dart';
import 'package:kamelscan/core/utils/result.dart';
import 'package:kamelscan/l10n/generated/app_localizations.dart';
import 'package:kamelscan/pages/account/delete_account_page.dart';

/// Layar konfirmasi hapus akun (Bab 9.6, migrasi 37).
///
/// 🔴 Ini satu-satunya tombol di seluruh aplikasi yang tidak punya tombol
/// urung. Yang diuji di sini bukan bahwa ia berfungsi — melainkan bahwa ia
/// **tidak dapat ditekan tanpa sengaja**, dan bahwa kalimat yang dibaca
/// pemiliknya sebelum menekan mengatakan hal yang benar tentang akunnya
/// sendiri.
void main() {
  const user = AppUser(
    id: 'u1',
    tenantId: 't1',
    email: 'owner@contoh.com',
    fullName: 'Budi Santoso',
    role: UserRole.owner,
  );

  SessionContext sesi({
    String? namaUsaha = 'Sarang Sarung',
    TenantStatus status = TenantStatus.active,
  }) => SessionContext(
    user: user,
    tenant: Tenant(
      id: 't1',
      ownerId: 'u1',
      status: status,
      businessName: namaUsaha,
    ),
    tierCatalog: TierCatalog.fallback,
  );

  Future<void> buka(
    WidgetTester tester, {
    SessionContext? konteks,
    _RepoPalsu? repo,
  }) async {
    // Layar HP: layar konfirmasi ini paling sering dibuka dari HP, dan lebar
    // sempit itulah yang membuat susunan pecah bila memang akan pecah.
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _SesiPalsu(konteks ?? sesi())),
          accountDeletionRepositoryProvider.overrideWithValue(
            repo ?? _RepoPalsu(),
          ),
        ],
        child: MaterialApp(
          // 🔴 `AppTheme` sungguhan, bukan tema bawaan Flutter. Tema proyek ini
          // punya `filledButtonTheme` dengan `minimumSize: Size.fromHeight(...)`
          // — lebar minimum tak terhingga — dan cacat M.12/M.17 hanya terlihat
          // bila temanya ikut dipasang.
          theme: AppTheme.light,
          locale: const Locale('id'),
          supportedLocales: AppL10n.supportedLocales,
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const DeleteAccountPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  FilledButton tombolHapus(WidgetTester tester) => tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Hapus akun saya'),
  );

  group('Tombolnya terkunci sampai nama usahanya diketik ulang', () {
    testWidgets('mati saat layar baru dibuka', (tester) async {
      await buka(tester);
      expect(tombolHapus(tester).onPressed, isNull);
    });

    testWidgets('tetap mati untuk ketikan yang hampir benar', (tester) async {
      await buka(tester);

      await tester.enterText(find.byType(TextField), 'Sarang Sarun');
      await tester.pump();

      expect(tombolHapus(tester).onPressed, isNull);
    });

    testWidgets('hidup saat namanya cocok', (tester) async {
      await buka(tester);

      await tester.enterText(find.byType(TextField), 'Sarang Sarung');
      await tester.pump();

      expect(tombolHapus(tester).onPressed, isNotNull);
    });

    // Nama usaha diketik pemiliknya sendiri, bukan disalin. Menuntut huruf
    // besar-kecilnya persis sama hanya menghukum orang yang sudah benar.
    testWidgets('huruf besar-kecil tidak dipersoalkan', (tester) async {
      await buka(tester);

      await tester.enterText(find.byType(TextField), '  sarang sarung  ');
      await tester.pump();

      expect(tombolHapus(tester).onPressed, isNotNull);
    });

    // 🔴 Cacat yang paling mudah lolos di layar ini. Dengan nama usaha kosong,
    // `''.trim() == ''.trim()` bernilai benar — tombolnya hidup sebelum
    // seorang pun mengetik satu huruf, tepat pada tombol yang tidak dapat
    // diurungkan. Nama usaha memang boleh kosong: kolomnya nullable dan
    // pendaftaran lewat Google tidak pernah menanyakannya.
    testWidgets('nama usaha kosong tidak membuka tombolnya', (tester) async {
      await buka(tester, konteks: sesi(namaUsaha: null));

      expect(tombolHapus(tester).onPressed, isNull);

      // Emailnya yang dipakai sebagai gantinya.
      await tester.enterText(find.byType(TextField), 'owner@contoh.com');
      await tester.pump();

      expect(tombolHapus(tester).onPressed, isNotNull);
    });
  });

  group('Kalimat tenggangnya mengikuti keadaan akunnya', () {
    testWidgets('akun berbayar diberi tahu tenggang 7 hari', (tester) async {
      await buka(tester);

      expect(find.textContaining('7 hari'), findsOneWidget);
      expect(find.textContaining('masa uji coba'), findsNothing);
    });

    // Menjanjikan "dapat dibatalkan dalam 7 hari" kepada pemilik akun trial
    // adalah janji yang tidak dapat ditepati siapa pun: datanya sudah musnah
    // sebelum layarnya sempat tertutup.
    testWidgets('akun trial diberi tahu tidak ada tenggang', (tester) async {
      await buka(tester, konteks: sesi(status: TenantStatus.trial));

      expect(find.textContaining('masa uji coba'), findsOneWidget);
      expect(find.textContaining('7 hari'), findsNothing);
    });
  });

  group('Yang hilang disebutkan sebelum ditekan, bukan sesudah', () {
    testWidgets('tautan berbagi ke pembeli ikut disebut', (tester) async {
      await buka(tester);

      // Owner mengirimkan tautan ini ke pembeli sebagai bukti. Tautannya mati
      // bersama akunnya, dan hanya Owner yang dapat menimbang akibat itu.
      expect(find.textContaining('tautan berbagi'), findsOneWidget);
      expect(find.textContaining('tidak dikembalikan'), findsOneWidget);
    });

    testWidgets('susunannya tidak pecah di layar HP', (tester) async {
      await buka(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('Nama usaha yang diketik dikirim apa adanya ke server', () {
    testWidgets('servernya yang mencocokkan, bukan hanya layar', (
      tester,
    ) async {
      final repo = _RepoPalsu();
      await buka(tester, repo: repo);

      await tester.enterText(find.byType(TextField), '  sarang sarung  ');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus akun saya'));
      await tester.pump();

      // Dikirim tanpa spasi pinggir, tetapi apa adanya selebihnya — verifikasi
      // sungguhannya ada di `request_account_deletion()` (migrasi 37), dan
      // layar ini tidak boleh berpura-pura menggantikannya.
      expect(repo.diminta, 'sarang sarung');
    });
  });

  group('Tenant.daysUntilPurge', () {
    // `inDays` memotong ke bawah, sehingga sisa 6 jam terbaca "0 hari" — angka
    // yang membuat pemiliknya menyangka kesempatan membatalkan sudah habis
    // padahal masih ada.
    test('membulatkan ke atas', () {
      final t = Tenant(
        id: 't1',
        ownerId: 'u1',
        deletionRequestedAt: DateTime(2026, 8, 31),
        deletionPurgeAfter: DateTime(2026, 9, 7, 6),
      );

      expect(t.daysUntilPurge(now: DateTime(2026, 9, 7)), 1);
      expect(t.daysUntilPurge(now: DateTime(2026, 9, 1)), 7);
    });

    test('tidak pernah negatif', () {
      final t = Tenant(
        id: 't1',
        ownerId: 'u1',
        deletionRequestedAt: DateTime(2026, 1, 1),
        deletionPurgeAfter: DateTime(2026, 1, 8),
      );

      expect(t.daysUntilPurge(now: DateTime(2026, 2, 1)), 0);
    });

    test('null bila tidak ada permintaan hapus', () {
      const t = Tenant(id: 't1', ownerId: 'u1');

      expect(t.daysUntilPurge(), isNull);
      expect(t.isDeletionPending, isFalse);
    });
  });
}

class _SesiPalsu extends Session {
  _SesiPalsu(this._nilai);
  final SessionContext? _nilai;

  @override
  Future<SessionContext?> build() async => _nilai;
}

class _RepoPalsu implements AccountDeletionRepository {
  String? diminta;

  @override
  Future<Result<DeletionOutcome>> requestDeletion(String confirmation) async {
    diminta = confirmation;
    return const Result.ok(DeletionOutcome.dijadwalkan);
  }

  @override
  Future<Result<void>> cancelDeletion() async => okVoid;
}
