import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kamelscan/core/config/tier_config.dart';
import 'package:kamelscan/core/models/app_user.dart';
import 'package:kamelscan/core/models/enums.dart';
import 'package:kamelscan/core/models/tenant.dart';
import 'package:kamelscan/core/providers/session_provider.dart';
import 'package:kamelscan/core/theme/app_theme.dart';
import 'package:kamelscan/l10n/generated/app_localizations.dart';
import 'package:kamelscan/navigation/route_names.dart';
import 'package:kamelscan/navigation/shells/web_shell.dart';

/// Rangka web pada dua sisi titik henti Bab 10.3.
///
/// 🔴 Tesnya memakai `AppTheme` sungguhan, dan itu bukan kerewelan. Percobaan
/// pertama pada cacat M.12 memakai tema bawaan Flutter dan **lulus**, sehingga
/// susunan yang rusak sempat dinyatakan baik-baik saja. Tema proyek ini punya
/// `filledButtonTheme` dengan `minimumSize: Size.fromHeight(...)` — lebar
/// minimum tak terhingga — dan itu hanya terlihat bila temanya ikut dipasang.
///
/// Bilah atas Bab 10.3 adalah `Row` berisi kolom teks, chip, dan nama
/// pengguna: bentuk yang persis sama dengan yang sudah dua kali rusak
/// (M.12 dan M.17). Karena itu ia dirender sungguhan di sini, bukan ditiru.
void main() {
  const user = AppUser(
    id: 'u1',
    tenantId: 't1',
    email: 'owner@contoh.com',
    fullName: 'Budi Santoso',
    role: UserRole.owner,
  );

  const sesi = SessionContext(
    user: user,
    tenant: Tenant(id: 't1', ownerId: 'u1'),
    tierCatalog: TierCatalog.fallback,
  );

  /// Router seadanya: satu cabang untuk tiap menu, isinya hanya penanda.
  /// Yang diuji rangkanya, bukan halamannya.
  GoRouter buatRouter() => GoRouter(
        initialLocation: Routes.webDashboard,
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) =>
                WebShell(navigationShell: shell, location: state.uri.path),
            branches: [
              for (final m in WebMenu.values)
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: m.path,
                      builder: (_, _) => Text('isi ${m.name}'),
                    ),
                  ],
                ),
            ],
          ),
        ],
      );

  Future<void> pasang(WidgetTester tester, {required double lebar}) async {
    tester.view.physicalSize = Size(lebar, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentRoleProvider.overrideWithValue(UserRole.owner),
          sessionProvider.overrideWith(() => _SesiPalsu(sesi)),
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
          routerConfig: buatRouter(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Layar lebar — sidebar menempel di kiri', () {
    testWidgets('ketujuh menu terlihat sekaligus', (tester) async {
      await pasang(tester, lebar: 1400);

      expect(find.text('Dasbor'), findsOneWidget);
      expect(find.text('Toko'), findsOneWidget);
      expect(find.text('Riwayat'), findsOneWidget);
      expect(find.text('Packer'), findsOneWidget);
      expect(find.text('Pembayaran'), findsOneWidget);
      expect(find.text('Pengaturan'), findsOneWidget);
      expect(find.text('Tutorial'), findsOneWidget);
    });

    testWidgets('tidak ada tombol laci — sidebarnya memang sudah kelihatan',
        (tester) async {
      await pasang(tester, lebar: 1400);
      expect(find.byIcon(Icons.menu), findsNothing);
    });

    testWidgets('bilah atas memuat kolom cari dan nama pengguna sekaligus',
        (tester) async {
      await pasang(tester, lebar: 1400);

      // Inilah yang hilang pada M.17: kolom teks tergencet habis oleh
      // tetangganya di dalam Row, dan yang tersisa cuma ikon.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Layar sempit — sidebar jadi laci', () {
    /// Tepat di bawah 1024, titik henti Bab 10.3.
    const sempit = 900.0;

    testWidgets('menu tidak lagi menempel di badan halaman', (tester) async {
      await pasang(tester, lebar: sempit);

      expect(find.text('Toko'), findsNothing);
      expect(find.text('Packer'), findsNothing);
      expect(find.text('Tutorial'), findsNothing);
    });

    testWidgets('tombol laci muncul menggantikannya', (tester) async {
      await pasang(tester, lebar: sempit);
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('laci dibuka memunculkan ketujuh menu itu lagi',
        (tester) async {
      await pasang(tester, lebar: sempit);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.text('Dasbor'), findsOneWidget);
      expect(find.text('Toko'), findsOneWidget);
      expect(find.text('Packer'), findsOneWidget);
      expect(find.text('Tutorial'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bilah atas tetap muat, tidak ada yang meluber',
        (tester) async {
      await pasang(tester, lebar: sempit);

      expect(find.byType(TextField), findsOneWidget);
      // `takeException` menangkap luberan RenderFlex. Bila bilah atasnya
      // melebihi lebar layar, ia tidak diam — ia melempar di sini.
      expect(tester.takeException(), isNull);
    });
  });

  group('Titik hentinya persis di 1024', () {
    testWidgets('1024 masih memakai sidebar menempel', (tester) async {
      await pasang(tester, lebar: WebShell.drawerBreakpoint);
      expect(find.byIcon(Icons.menu), findsNothing);
    });

    testWidgets('1023 sudah memakai laci', (tester) async {
      await pasang(tester, lebar: WebShell.drawerBreakpoint - 1);
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });
  });
}

class _SesiPalsu extends Session {
  _SesiPalsu(this._nilai);

  final SessionContext? _nilai;

  @override
  Future<SessionContext?> build() async => _nilai;
}
