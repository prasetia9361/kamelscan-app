import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kamelscan/core/theme/app_colors.dart';
import 'package:kamelscan/core/theme/app_theme.dart';
import 'package:kamelscan/core/widgets/profile_avatar.dart';

/// Titik status sambungan pada avatar (revisi tampilan, 1 September 2026).
///
/// Maknanya **bukan** "sedang aktif" seperti di aplikasi obrolan. Yang relevan
/// bagi packer hanya satu hal: apakah videonya bisa terkirim. Karena itu
/// keadaan tanpa jaringan berwarna `warning`, bukan `danger` — tanpa jaringan
/// perekaman tetap jalan dan videonya masuk antrean lokal (Bab 8.7). Merah
/// akan membuat packer berhenti merekam padahal tidak perlu.
void main() {
  Future<void> pasang(
    WidgetTester tester, {
    required bool? online,
    ThemeData? theme,
  }) =>
      tester.pumpWidget(
        MaterialApp(
          theme: theme ?? AppTheme.light,
          home: Scaffold(
            body: Center(
              child: ProfileAvatar(
                initials: 'RS',
                seed: 'user-1',
                avatarUrl: null,
                size: 36,
                online: online,
              ),
            ),
          ),
        ),
      );

  /// ⚠️ Bukan sekadar "lingkaran" — `CircleAvatar` sendiri menggambar
  /// `Container` bulat 36×36 untuk latarnya, dan pencari yang hanya melihat
  /// bentuk akan menangkap keduanya. Yang membedakan titik status adalah
  /// **garis tepinya**: ia satu-satunya lingkaran bergaris tepi di sini, dan
  /// garis itu memang alasan ia ada — supaya terbaca di atas foto apa pun.
  Finder titik() => find.byWidgetPredicate((w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).shape == BoxShape.circle &&
      (w.decoration as BoxDecoration).border != null);

  testWidgets('tersambung — titik hijau tergambar', (tester) async {
    await pasang(tester, online: true);

    expect(tester.takeException(), isNull);
    expect(titik(), findsOneWidget);

    final d = tester.widget<Container>(titik()).decoration as BoxDecoration;
    expect(d.color, AppColors.light.success);
  });

  testWidgets('tanpa jaringan — jingga, BUKAN merah', (tester) async {
    await pasang(tester, online: false);

    final d = tester.widget<Container>(titik()).decoration as BoxDecoration;
    expect(d.color, AppColors.light.warning);
    // 🔴 Penjaga makna, bukan sekadar warna: merah menyatakan kegagalan, dan
    // packer yang melihatnya akan berhenti merekam padahal perekaman offline
    // memang dirancang bekerja (Bab 8.7).
    expect(d.color, isNot(AppColors.light.danger));
  });

  testWidgets('status tidak diketahui — tidak ada titik sama sekali',
      (tester) async {
    await pasang(tester, online: null);

    expect(tester.takeException(), isNull);
    expect(titik(), findsNothing);
  });

  testWidgets('🔴 tanpa titik, tema tanpa AppColors tidak membuatnya jatuh',
      (tester) async {
    // Avatar dipakai juga di layar yang temanya belum tentu memasang ekstensi
    // `AppColors`. Jalur tanpa titik tidak boleh menyentuh ekstensi itu.
    await pasang(tester, online: null, theme: ThemeData.light());

    expect(tester.takeException(), isNull);
    expect(find.text('RS'), findsOneWidget);
  });
}
