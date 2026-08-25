import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/navigation/route_names.dart';
import 'package:kamelscan/navigation/shells/web_shell.dart';

/// Sidebar web (Bab 10.3) — urutan menu, pembatasan peran, dan menu mana yang
/// menyala untuk sebuah alamat.
///
/// 🔴 Dipisah sebagai fungsi murni dengan alasan yang sama seperti
/// `MobileShell.branchesFor`: daftar yang meleset satu baris mengirim pengguna
/// ke halaman lain **tanpa menimbulkan error apa pun**, dan hanya ketahuan
/// dengan mencobanya satu per satu di peramban.
///
/// Yang membuat versi web lebih rawan: tiga menunya — Beranda, Packer, dan
/// Pembayaran — tidak berdiri sebagai akar cabangnya sendiri. Menghitung menu
/// yang menyala dari `navigationShell.currentIndex` karena itu **salah**, dan
/// salahnya diam: membuka Packer akan menyalakan menu Akun.
void main() {
  group('Urutan menu mengikuti Bab 10.3', () {
    test('Owner melihat tujuh menu, berurutan', () {
      expect(WebShell.menuFor(isOwner: true), [
        WebMenu.dashboard,
        WebMenu.shops,
        WebMenu.history,
        WebMenu.packers,
        WebMenu.payment,
        WebMenu.settings,
        WebMenu.tutorial,
      ]);
    });

    test('Packer tidak melihat Toko, Packer, maupun Pembayaran', () {
      final menu = WebShell.menuFor(isOwner: false);

      expect(menu, [
        WebMenu.dashboard,
        WebMenu.history,
        WebMenu.settings,
        WebMenu.tutorial,
      ]);
      // Bab 2.2 — bukan sekadar dinonaktifkan, memang tidak ada.
      expect(menu, isNot(contains(WebMenu.shops)));
      expect(menu, isNot(contains(WebMenu.packers)));
      expect(menu, isNot(contains(WebMenu.payment)));
    });

    test('tiap menu muncul tepat sekali', () {
      final menu = WebShell.menuFor(isOwner: true);
      expect(menu.toSet().length, menu.length);
    });
  });

  /// 🔴 Pencocokan menurut awalan hanya aman selama tidak ada alamat menu yang
  /// menjadi awalan alamat menu lain. Tes ini yang menjaganya: menambah menu
  /// baru berawalan sama — misalnya `/settings` dan `/settings-lanjutan` —
  /// akan menyalakan menu yang keliru tanpa satu pun pesan.
  test('tidak ada alamat menu yang menjadi awalan alamat menu lain', () {
    for (final a in WebMenu.values) {
      for (final b in WebMenu.values) {
        if (a == b) continue;
        expect(
          b.path.startsWith(a.path),
          isFalse,
          reason: '${b.path} berawalan ${a.path}',
        );
      }
    }
  });

  group('Menu yang menyala dihitung dari alamat', () {
    final menuOwner = WebShell.menuFor(isOwner: true);

    int? nyala(String location) =>
        WebShell.selectedIndexOf(menu: menuOwner, location: location);

    test('akar tiap menu menyalakan dirinya sendiri', () {
      expect(nyala(Routes.webDashboard), 0);
      expect(nyala(Routes.shops), 1);
      expect(nyala(Routes.history), 2);
      expect(nyala(Routes.packers), 3);
      expect(nyala(Routes.payment), 4);
      expect(nyala(Routes.settings), 5);
      expect(nyala(Routes.tutorial), 6);
    });

    test('halaman anak menyalakan induknya', () {
      expect(nyala('/shops/form/123'), 1);
      expect(nyala('/history/abc-def'), 2);
      expect(nyala('/payment/checkout'), 4);
      expect(nyala('/settings/watermark'), 5);
    });

    test('Packer dan Akun tidak tertukar walaupun satu cabang', () {
      // Inilah yang tidak dapat dibedakan `navigationShell.currentIndex`:
      // keduanya cabang 3. Alamatnya berbeda, dan itu yang dipakai.
      expect(nyala(Routes.packers), 3);
      expect(nyala(Routes.account), isNull);
    });

    test('alamat di luar menu tidak menyalakan apa pun', () {
      expect(nyala(Routes.account), isNull);
      expect(nyala('/account/edit'), isNull);
      expect(nyala(Routes.adminDashboard), isNull);
    });

    test('nomornya mengikuti daftar peran, bukan urutan enum', () {
      // Packer tidak punya Toko, jadi Riwayat naik dari posisi 2 ke posisi 1.
      // Memakai `WebMenu.values.indexOf` di sini akan meleset satu, dan
      // menyalakan menu tetangganya.
      final menuPacker = WebShell.menuFor(isOwner: false);
      expect(
        WebShell.selectedIndexOf(
          menu: menuPacker,
          location: Routes.history,
        ),
        1,
      );
    });
  });
}
