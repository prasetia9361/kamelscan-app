import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/navigation/shells/mobile_shell.dart';

/// Pemetaan tombol menu bawah ke cabang GoRouter (Bab 9.1).
///
/// 🔴 Nomor cabang **tidak** sama dengan urutan tombolnya:
///
/// | Cabang | Isi |            | Urutan tombol (Bab 9.1) |
/// |---|---|                   |---|
/// | 0 | Beranda |             | Home · Toko · Riwayat · Setting · Akun |
/// | 1 | Riwayat |
/// | 2 | Toko |
/// | 3 | Akun & Pembayaran |
/// | 4 | Pengaturan |
///
/// Menu Toko **disembunyikan** untuk packer — bukan dinonaktifkan — sehingga
/// seluruh tombol sesudahnya bergeser satu posisi di layar, tetapi tidak di
/// router.
///
/// ⚠️ Kesalahan satu angka di sini tidak menimbulkan error apa pun: packer
/// menekan "Riwayat" lalu mendarat di Pengaturan, dan itu hanya ketahuan
/// dengan mencobanya di perangkat. Karena itu dipisah sebagai fungsi murni.
void main() {
  /// Nomor cabang, agar tesnya terbaca sebagai kalimat.
  const beranda = 0;
  const riwayat = 1;
  const toko = 2;
  const akun = 3;
  const pengaturan = 4;

  group('Owner melihat lima tombol', () {
    final tabs = MobileShell.branchesFor(isOwner: true);

    test('jumlahnya lima', () => expect(tabs.length, 5));

    test('urutannya Home · Toko · Riwayat · Setting · Akun', () {
      expect(tabs, [beranda, toko, riwayat, pengaturan, akun]);
    });

    test('tiap cabang muncul tepat sekali', () {
      expect(tabs.toSet().length, tabs.length);
    });
  });

  group('Packer tidak melihat menu Toko', () {
    final tabs = MobileShell.branchesFor(isOwner: false);

    test('jumlahnya empat', () => expect(tabs.length, 4));

    test('cabang Toko tidak ada sama sekali', () {
      // Bab 9.1 — disembunyikan, bukan dinonaktifkan.
      expect(tabs, isNot(contains(toko)));
    });

    test('urutannya Home · Riwayat · Setting · Akun', () {
      expect(tabs, [beranda, riwayat, pengaturan, akun]);
    });

    test('tombol terakhir tetap Akun, bukan bergeser ke Pengaturan', () {
      // Inilah kesalahan yang paling mungkin terjadi saat menu disembunyikan:
      // daftar tombolnya menyusut, tetapi nomor cabangnya lupa disesuaikan.
      expect(tabs.last, akun);
    });
  });

  group('Kedua peran menunjuk cabang yang sama untuk menu yang sama', () {
    final owner = MobileShell.branchesFor(isOwner: true);
    final packer = MobileShell.branchesFor(isOwner: false);

    test('Beranda selalu tombol pertama', () {
      expect(owner.first, beranda);
      expect(packer.first, beranda);
    });

    test('Pengaturan selalu tepat sebelum Akun', () {
      expect(owner[owner.length - 2], pengaturan);
      expect(packer[packer.length - 2], pengaturan);
    });

    test('daftar packer adalah daftar owner tanpa Toko', () {
      expect(owner.where((b) => b != toko).toList(), packer);
    });
  });
}
