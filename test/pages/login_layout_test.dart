import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kamelscan/core/theme/app_theme.dart';
import 'package:kamelscan/l10n/generated/app_localizations.dart';
import 'package:kamelscan/pages/auth/widgets/auth_scaffold.dart';

/// Kepala bermerek layar Masuk (revisi tampilan, 1 September 2026).
///
/// ⚠️ Yang diuji bukan "logonya bagus", melainkan bahwa layarnya **tergambar
/// pada layar HP yang sebenarnya** dan isi sesudah kepalanya tidak hilang.
/// Cacat Beranda 1 September lolos justru karena tidak ada tes yang pernah
/// menggambar layarnya pada ukuran nyata.
void main() {
  Future<void> pasang(WidgetTester tester, {Size ukuran = const Size(402, 874)}) {
    tester.view.physicalSize = ukuran;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('id'),
        localizationsDelegates: const [
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppL10n.supportedLocales,
        home: AuthScaffold(
          showBack: false,
          header: const AuthBrandHeader(tagline: 'Bukti video setiap paket'),
          centerTitle: true,
          title: 'Masuk ke KamelScan',
          subtitle: 'Rekam bukti packing, selesaikan sengketa.',
          children: [
            const TextField(key: Key('identifier')),
            const SizedBox(height: 16),
            FilledButton(onPressed: () {}, child: const Text('Masuk')),
          ],
        ),
      ),
    );
  }

  testWidgets('tergambar tanpa galat tata letak', (tester) async {
    await pasang(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('🔴 isi sesudah kepala tetap tergambar', (tester) async {
    await pasang(tester);

    expect(find.text('Masuk ke KamelScan'), findsOneWidget);
    expect(find.byKey(const Key('identifier')), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });

  testWidgets('logo dan tagline ada', (tester) async {
    await pasang(tester);

    expect(find.byType(Image), findsOneWidget);
    // Widget yang menaikkan hurufnya, jadi yang dicari versi kapitalnya.
    expect(find.text('BUKTI VIDEO SETIAP PAKET'), findsOneWidget);
  });

  testWidgets('🔴 pada 360 dp — layar tersempit yang wajar — tidak meluber',
      (tester) async {
    // 360 dp adalah kasus terburuk yang wajar dipakai packer. Kepala bermerek
    // menambah tinggi, dan layar Masuk memang yang paling padat.
    await pasang(tester, ukuran: const Size(360, 640));

    expect(tester.takeException(), isNull);
    expect(find.text('Masuk ke KamelScan'), findsOneWidget);
  });
}
