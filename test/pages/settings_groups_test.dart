import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/pages/settings/settings_page.dart';

/// Kelompok mana yang tampil di Pengaturan (Bab 9.7 + keputusan Bab 10).
///
/// 🔴 Ditulis sebagai fungsi murni justru supaya cabang **web**-nya dapat
/// diuji. `kIsWeb` adalah konstanta waktu kompilasi: pada `flutter test`
/// nilainya selalu `false`, sehingga percabangan yang ditulis langsung di
/// dalam `build` tidak pernah dijalankan pada sisi webnya sekali pun.
///
/// Itu persis yang membuat cacat login Google hidup berminggu-minggu
/// (`DEVIASI_LIBRARY.md` O.14): komentarnya menjanjikan pemisahan mobile/web,
/// kodenya tidak pernah melakukannya, dan tidak ada satu pun tes yang bisa
/// membantahnya.
void main() {
  bool tampil(SettingsGroup g, {required bool isWeb, required bool isOwner}) =>
      SettingsPage.tampil(g, isWeb: isWeb, isOwner: isOwner);

  group('Di HP', () {
    test('Owner melihat keenam kelompok', () {
      for (final g in SettingsGroup.values) {
        expect(
          tampil(g, isWeb: false, isOwner: true),
          isTrue,
          reason: '${g.name} seharusnya tampil di HP bagi Owner',
        );
      }
    });

    test('Packer tidak melihat Merek dan Privasi', () {
      // Keduanya mengubah hal yang berlaku bagi seluruh tenant (Bab 9.7).
      expect(tampil(SettingsGroup.brand, isWeb: false, isOwner: false), isFalse);
      expect(
          tampil(SettingsGroup.privacy, isWeb: false, isOwner: false), isFalse);
    });

    test('Packer tetap melihat Perekaman — itu pengaturan HP-nya sendiri', () {
      expect(
          tampil(SettingsGroup.recording, isWeb: false, isOwner: false), isTrue);
    });
  });

  group('Di web', () {
    test('🔴 Perekaman, Merek, dan Privasi tidak tampil sama sekali', () {
      // Merekam tidak pernah terjadi di web (Bab 10.1). Pengaturan yang tidak
      // dapat berpengaruh apa pun di tempat ia ditampilkan lebih buruk
      // daripada pengaturan yang tidak ada: ia mengundang orang mengubahnya
      // lalu bertanya-tanya kenapa tidak terjadi apa-apa.
      expect(tampil(SettingsGroup.recording, isWeb: true, isOwner: true),
          isFalse);
      expect(tampil(SettingsGroup.brand, isWeb: true, isOwner: true), isFalse);
      expect(tampil(SettingsGroup.privacy, isWeb: true, isOwner: true), isFalse);
    });

    test('peran Owner TIDAK mengembalikannya', () {
      // Penjagaan terhadap "diperbaiki" menjadi `isOwner || !isWeb`, yang
      // terbaca masuk akal dan justru mengembalikan ketiganya bagi Owner.
      for (final owner in [true, false]) {
        expect(tampil(SettingsGroup.recording, isWeb: true, isOwner: owner),
            isFalse);
        expect(
            tampil(SettingsGroup.brand, isWeb: true, isOwner: owner), isFalse);
        expect(tampil(SettingsGroup.privacy, isWeb: true, isOwner: owner),
            isFalse);
      }
    });

    test('Tampilan, Data, dan Info tetap ada', () {
      // Tema dan bahasa berlaku di mana pun aplikasinya dibuka.
      expect(tampil(SettingsGroup.display, isWeb: true, isOwner: true), isTrue);
      expect(tampil(SettingsGroup.data, isWeb: true, isOwner: true), isTrue);
      expect(tampil(SettingsGroup.info, isWeb: true, isOwner: true), isTrue);
    });

    test('packer di web pun hanya melihat tiga kelompok', () {
      final terlihat = [
        for (final g in SettingsGroup.values)
          if (tampil(g, isWeb: true, isOwner: false)) g,
      ];
      expect(terlihat, [
        SettingsGroup.display,
        SettingsGroup.data,
        SettingsGroup.info,
      ]);
    });
  });
}
