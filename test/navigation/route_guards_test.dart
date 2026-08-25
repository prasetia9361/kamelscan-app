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
    bool resetPending = false,
  }) =>
      ProviderContainer(
        overrides: [
          isSignedInProvider.overrideWithValue(signedIn),
          currentRoleProvider.overrideWithValue(role),
          mustChangePasswordProvider.overrideWithValue(mustChangePassword),
          needsProfileCompletionProvider.overrideWithValue(needsProfile),
          passwordResetPendingProvider.overrideWith(
            () => _PemulihanPalsu(resetPending),
          ),
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

  /// Bab 6.8 — tautan *Lupa password* menghasilkan sesi yang sah, jadi tanpa
  /// penjagaan ini pengguna mendarat di Beranda dalam keadaan sudah masuk dan
  /// tidak pernah diminta membuat password baru. Persis itulah yang dilaporkan
  /// 24 Agustus 2026: tautan diklik, aplikasi terbuka, tidak ada apa-apa.
  group('Tautan Lupa password', () {
    test('dari mana pun dilempar ke layar password baru', () {
      final c = wadah(signedIn: true, role: UserRole.owner, resetPending: true);
      addTearDown(c.dispose);

      expect(tujuan(c, Routes.home), Routes.resetPassword);
      expect(tujuan(c, Routes.login), Routes.resetPassword);
      expect(tujuan(c, Routes.forgotPassword), Routes.resetPassword);
    });

    test('layar password baru sendiri tidak dialihkan -- tidak ada putaran', () {
      final c = wadah(signedIn: true, role: UserRole.owner, resetPending: true);
      addTearDown(c.dispose);

      expect(tujuan(c, Routes.resetPassword), isNull);
    });

    test('mendahului paksaan ganti password dan lengkapi profil', () {
      final c = wadah(
        signedIn: true,
        role: UserRole.owner,
        mustChangePassword: true,
        needsProfile: true,
        resetPending: true,
      );
      addTearDown(c.dispose);

      expect(tujuan(c, Routes.home), Routes.resetPassword);
    });

    test('sesudah selesai, layarnya tidak dapat dibuka lagi', () {
      final c = wadah(signedIn: true, role: UserRole.owner);
      addTearDown(c.dispose);

      expect(tujuan(c, Routes.resetPassword), Routes.home);
    });

    test('belum login tetap dilempar ke Masuk, bukan ke layar password baru',
        () {
      final c = wadah(signedIn: false, resetPending: true);
      addTearDown(c.dispose);

      expect(tujuan(c, Routes.home), Routes.login);
    });
  });

  /// 🔴 Bab 10: tempat peramban mendarat sesudah tautan email ditekan di web.
  ///
  /// `Env.emailVerifyRedirectUrl` mengirim `.../auth/callback` sejak Bab 10.2,
  /// tetapi alamat itu tidak pernah punya rute maupun izin. Akibatnya bukan
  /// sekadar salah layar: karena ia **bukan** halaman publik, guard membiarkan
  /// pengguna yang sudah masuk tetap di sana (`return null` pada cabang peran),
  /// dan GoRouter menjatuhkannya ke `errorBuilder`. Pengguna tersangkut di
  /// "halaman tidak ditemukan" tanpa satu pun jalan keluar.
  group('Tautan email di web mendarat di /auth/callback', () {
    test('belum login, dibiarkan menunggu — bukan dilempar ke Masuk', () {
      final c = wadah(signedIn: false);
      addTearDown(c.dispose);

      // Inilah baris yang menjaga cacatnya. Bila `authCallback` suatu hari
      // keluar dari daftar publik, tautannya akan dilempar ke layar Masuk
      // sebelum sempat ditukar — dan gejalanya tautan yang "tidak melakukan
      // apa-apa", persis seperti sebelum Bab 10.
      expect(tujuan(c, Routes.authCallback), isNull);
    });

    test('tautan Lupa password membawanya ke layar password baru', () {
      final c = wadah(signedIn: true, role: UserRole.owner, resetPending: true);
      addTearDown(c.dispose);

      expect(tujuan(c, Routes.authCallback), Routes.resetPassword);
    });

    test('tautan verifikasi: selagi peran belum diketahui, ke layar pembuka',
        () {
      final c = wadah(signedIn: true, role: null);
      addTearDown(c.dispose);

      expect(tujuan(c, Routes.authCallback), Routes.splash);
    });

    test('tautan verifikasi: sesudah sesi siap, ke Beranda', () {
      final c = wadah(signedIn: true, role: UserRole.owner);
      addTearDown(c.dispose);

      expect(tujuan(c, Routes.authCallback), Routes.home);
    });

    test('tidak pernah berakhir sebagai halaman tidak ditemukan', () {
      // Empat keadaan yang mungkin dialami pengguna saat mendarat di sini.
      // Tidak satu pun boleh berhenti di alamat itu sesudah sesinya jadi —
      // hanya keadaan "belum login" yang boleh tinggal, karena tautannya
      // memang sedang ditukar.
      for (final keadaan in [
        (signedIn: true, role: UserRole.owner),
        (signedIn: true, role: UserRole.packer),
        (signedIn: true, role: UserRole.admin),
        (signedIn: true, role: null),
      ]) {
        final c = wadah(signedIn: keadaan.signedIn, role: keadaan.role);
        addTearDown(c.dispose);

        expect(
          tujuan(c, Routes.authCallback),
          isNotNull,
          reason: 'peran ${keadaan.role} tertinggal di /auth/callback',
        );
      }
    });
  });

  /// 🔴 Cacat 24 Agustus 2026: Lengkapi Profil tidak pernah ditinggalkan.
  ///
  /// Guard-nya sendiri sudah benar — beri ia nilai yang segar dan ia menjawab
  /// `/home`. Yang rusak adalah **tidak ada yang menyuruhnya menghitung
  /// ulang**. Karena itu tes ini tidak memeriksa jawaban guard, melainkan
  /// memeriksa apakah GoRouter diberi tahu.
  ///
  /// Tanpa `_ref.listen(needsProfileCompletionProvider, ...)`, tes ini gagal
  /// dan aplikasinya membeku di layar itu sampai ditutup paksa.
  group('GoRouter diberi tahu saat penjagaan berubah', () {
    Future<int> hitungPemberitahuan(
      ProviderContainer c,
      NotifierProvider<_Saklar, bool> saklar,
    ) async {
      final refresh = GoRouterRefreshNotifier(c.read(_refProvider));
      addTearDown(refresh.dispose);

      var jumlah = 0;
      refresh.addListener(() => jumlah++);

      c.read(saklar.notifier).ubah(false);
      // Riverpod menyampaikan perubahan lewat penjadwalnya, bukan seketika.
      await Future<void>.delayed(Duration.zero);
      return jumlah;
    }

    test('profil selesai dilengkapi memicu perhitungan ulang', () async {
      final c = ProviderContainer(
        overrides: [
          isSignedInProvider.overrideWithValue(true),
          currentRoleProvider.overrideWithValue(UserRole.owner),
          mustChangePasswordProvider.overrideWithValue(false),
          passwordResetPendingProvider.overrideWith(() => _PemulihanPalsu(false)),
          needsProfileCompletionProvider
              .overrideWith((ref) => ref.watch(_saklarProfil)),
        ],
      );
      addTearDown(c.dispose);

      expect(await hitungPemberitahuan(c, _saklarProfil), greaterThan(0));
    });

    test('password sementara selesai diganti memicu perhitungan ulang',
        () async {
      final c = ProviderContainer(
        overrides: [
          isSignedInProvider.overrideWithValue(true),
          currentRoleProvider.overrideWithValue(UserRole.packer),
          needsProfileCompletionProvider.overrideWithValue(false),
          passwordResetPendingProvider.overrideWith(() => _PemulihanPalsu(false)),
          mustChangePasswordProvider
              .overrideWith((ref) => ref.watch(_saklarPassword)),
        ],
      );
      addTearDown(c.dispose);

      expect(await hitungPemberitahuan(c, _saklarPassword), greaterThan(0));
    });
  });
}

/// Saklar yang dapat dibalik dari tes, menggantikan provider sungguhan yang
/// nilainya berasal dari sesi.
class _Saklar extends Notifier<bool> {
  @override
  bool build() => true;

  void ubah(bool nilai) => state = nilai;
}

final _saklarProfil = NotifierProvider<_Saklar, bool>(_Saklar.new);
final _saklarPassword = NotifierProvider<_Saklar, bool>(_Saklar.new);

/// Penyedia sekali pakai untuk memperoleh `Ref` yang sah.
final _refProvider = Provider<Ref>((ref) => ref);

/// `passwordResetPendingProvider` sungguhan membaca `ValueNotifier` global di
/// `SupabaseService`. Menyetelnya dari tes berarti meninggalkan keadaan yang
/// bocor ke berkas tes lain, jadi di sini ia diganti seluruhnya.
class _PemulihanPalsu extends PasswordResetPending {
  _PemulihanPalsu(this._nilai);

  final bool _nilai;

  @override
  bool build() => _nilai;
}
