import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/models/enums.dart';
import 'package:kamelscan/core/providers/auth_provider.dart';
import 'package:kamelscan/core/providers/session_provider.dart';
import 'package:kamelscan/navigation/route_guards.dart';
import 'package:kamelscan/navigation/route_names.dart';

/// Ke mana pengguna dikirim sesudah menekan Masuk (Bab 3.2).
///
/// 🔴 Berkas ini lahir dari cacat yang butuh **empat ronde** untuk ditemukan,
/// dan baru terpecahkan 22 Agustus 2026 ketika aplikasinya dikemudikan lewat
/// kabel dan jejaknya dibaca langsung dari perangkat.
///
/// Gejalanya: sesudah packer login, badan Beranda kosong sama sekali; menekan
/// menu lain lalu kembali membuat isinya muncul. Kadang terjadi, kadang tidak.
///
/// Sebabnya ada di sini. Sesaat setelah tombol Masuk ditekan, `isSignedIn`
/// sudah `true` sementara `sessionProvider` baru mulai memuat profil, tenant,
/// katalog tier, dan dompet — sehingga `currentRole` masih null. Guard lama
/// tetap mengirim pengguna ke Beranda pada detik itu, dan Beranda dibangun di
/// atas sesi yang belum ada:
///
///     SHELL cabang=0 tab=0 role=null
///     HOME  vm mulai · sesi=AsyncLoading role=null
///     HOME  bangun · AsyncLoading error=true
///     SPLASH mulai · isSignedIn=true          <- splash baru jalan SESUDAHNYA
///     HOME  vm keadaan -> AsyncData
///     HOME  vm dibuang                        <- datanya sampai ke halaman yang
///                                                sudah tidak ada penontonnya
///
/// Tiga dari empat siklus berakhir kosong; yang satu lolos hanya karena
/// datanya kebetulan tiba sebelum pembuangan. Itulah sebabnya cacat ini kadang
/// muncul kadang tidak, dan mengapa "sekali coba berhasil" tidak pernah cukup
/// untuk menyatakannya beres.
void main() {
  ProviderContainer wadah({
    required bool signedIn,
    UserRole? role,
    bool mustChangePassword = false,
    bool needsProfile = false,
  }) =>
      ProviderContainer(
        overrides: [
          isSignedInProvider.overrideWithValue(signedIn),
          currentRoleProvider.overrideWithValue(role),
          mustChangePasswordProvider.overrideWithValue(mustChangePassword),
          needsProfileCompletionProvider.overrideWithValue(needsProfile),
        ],
      );

  String? tujuan(ProviderContainer c, String dari) =>
      RouteGuards(c.read(_refProvider)).redirect(dari);

  group('Sesudah Masuk, selagi sesi belum siap', () {
    test('dikirim ke layar pembuka, BUKAN ke Beranda', () {
      final c = wadah(signedIn: true, role: null);
      addTearDown(c.dispose);

      // Inilah baris yang menjaga cacatnya. Bila suatu hari ia kembali
      // mengembalikan `/home`, Beranda akan kembali dibangun di atas sesi yang
      // belum ada -- dan gejalanya tidak akan terlihat pada percobaan pertama.
      expect(tujuan(c, Routes.login), Routes.splash);
    });

    test('berlaku juga dari halaman daftar dan lupa kata sandi', () {
      final c = wadah(signedIn: true, role: null);
      addTearDown(c.dispose);

      expect(tujuan(c, Routes.register), Routes.splash);
      expect(tujuan(c, Routes.forgotPassword), Routes.splash);
    });

    test('layar pembuka sendiri tidak pernah dialihkan -- tidak ada putaran', () {
      final c = wadah(signedIn: true, role: null);
      addTearDown(c.dispose);

      expect(tujuan(c, Routes.splash), isNull);
    });
  });

  group('Sesudah sesi siap, tujuannya seperti semula', () {
    test('Owner ke Beranda', () {
      final c = wadah(signedIn: true, role: UserRole.owner);
      addTearDown(c.dispose);

      expect(tujuan(c, Routes.login), Routes.home);
    });

    test('Packer ke Beranda', () {
      final c = wadah(signedIn: true, role: UserRole.packer);
      addTearDown(c.dispose);

      expect(tujuan(c, Routes.login), Routes.home);
    });

    test('Admin ke dasbor admin, bukan Beranda', () {
      final c = wadah(signedIn: true, role: UserRole.admin);
      addTearDown(c.dispose);

      expect(tujuan(c, Routes.login), Routes.adminDashboard);
    });
  });

  group('Penjagaan lain tidak ikut berubah', () {
    test('belum login, halaman terlindungi dilempar ke Masuk', () {
      final c = wadah(signedIn: false);
      addTearDown(c.dispose);

      expect(tujuan(c, Routes.home), Routes.login);
    });

    test('belum login, halaman publik dibiarkan', () {
      final c = wadah(signedIn: false);
      addTearDown(c.dispose);

      expect(tujuan(c, Routes.login), isNull);
    });

    test('password sementara wajib diganti lebih dulu', () {
      final c = wadah(
        signedIn: true,
        role: UserRole.packer,
        mustChangePassword: true,
      );
      addTearDown(c.dispose);

      expect(tujuan(c, Routes.home), Routes.changePassword);
    });

    test('packer tidak boleh masuk halaman milik Owner', () {
      final c = wadah(signedIn: true, role: UserRole.packer);
      addTearDown(c.dispose);

      expect(tujuan(c, Routes.shops), Routes.home);
      expect(tujuan(c, Routes.packers), Routes.home);
      expect(tujuan(c, Routes.payment), Routes.home);
    });
  });
}

/// Penyedia sekali pakai untuk memperoleh `Ref` yang sah.
final _refProvider = Provider<Ref>((ref) => ref);
