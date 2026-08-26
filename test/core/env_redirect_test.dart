import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/config/env.dart';

/// Alamat tujuan sesudah Google dan sesudah tautan email (Bab 6.5 & Bab 10).
///
/// 🔴 Tes ini lahir dari cacat yang hidup berminggu-minggu **dengan komentar
/// yang menjanjikan hal yang tidak dikerjakan kodenya**: `oauthRedirectUrl`
/// bertuliskan *"mobile memakai deep link, web memakai URL halaman"*, tetapi
/// implementasinya selalu mengembalikan deep link.
///
/// Tidak ada yang bisa membantahnya karena `Env.kIsWebPlatform` adalah
/// konstanta waktu kompilasi — pada `flutter test` nilainya selalu `false`,
/// jadi cabang web tidak pernah dijalankan satu kali pun. Itu sebabnya kedua
/// cabangnya kini berupa fungsi yang menerima `isWeb`.
void main() {
  group('Tujuan sesudah kembali dari Google', () {
    test('di HP memakai deep link aplikasi', () {
      final url = Env.oauthRedirectFor(isWeb: false);

      expect(url, startsWith('${Env.authRedirectScheme}://'));
      expect(url, 'id.kamelscan.app://login-callback');
    });

    test('🔴 di web memakai alamat halaman, BUKAN skema deep link', () {
      final url = Env.oauthRedirectFor(isWeb: true);

      // Inilah cacatnya. Peramban tidak mengerti `id.kamelscan.app://`, dan
      // alamat yang tidak cocok dengan daftar Redirect URLs **tidak
      // menghasilkan pesan galat apa pun** — Supabase diam-diam memakai
      // Site URL. Tombol Google-nya seolah "tidak terjadi apa-apa".
      expect(url, isNot(contains('://login-callback')));
      expect(url, startsWith('http'));
      expect(url, endsWith('/auth/callback'));
    });

    test('alamat web dibangun dari WEB_APP_BASE_URL, bukan ditulis mati', () {
      // Kalau suatu hari domainnya pindah, satu tempat saja yang berubah.
      expect(
        Env.oauthRedirectFor(isWeb: true),
        '${Env.webAppBaseUrl}/auth/callback',
      );
    });
  });

  group('Tujuan tautan verifikasi email dan reset password', () {
    test('di HP sama dengan tujuan Google — sama-sama deep link', () {
      expect(
        Env.emailVerifyRedirectFor(isWeb: false),
        Env.oauthRedirectFor(isWeb: false),
      );
    });

    test('di web mendarat di halaman yang sama pula', () {
      // Halaman itu menunggu sesi terbentuk lalu menyerahkan tujuannya kepada
      // penjagaan rute — perilaku yang dibutuhkan kedua alur.
      expect(
        Env.emailVerifyRedirectFor(isWeb: true),
        Env.oauthRedirectFor(isWeb: true),
      );
    });
  });

  group('Alamat webnya harus tercakup daftar izin Supabase', () {
    test('berada di bawah WEB_APP_BASE_URL, bukan di domain lain', () {
      // Daftar izin memakai pola `https://kamelscan.com/app/**`. Alamat yang
      // keluar dari sana akan ditolak diam-diam — jebakan yang sudah tiga kali
      // memakan waktu di proyek ini.
      expect(
        Env.oauthRedirectFor(isWeb: true),
        startsWith(Env.webAppBaseUrl),
      );
    });

    test('bukan localhost saat WEB_APP_BASE_URL diisi domain sungguhan', () {
      // Penjaga terhadap build yang lupa `--dart-define-from-file`: bawaan
      // `Env.webAppBaseUrl` adalah localhost, dan aplikasi yang terbit dengan
      // nilai itu mengirim tautan yang tidak dapat dibuka siapa pun kecuali
      // di laptop yang membangunnya. Sudah terjadi 25 Agustus 2026.
      if (Env.webAppBaseUrl.contains('localhost')) {
        // Build uji tanpa env — tidak ada yang bisa dibuktikan di sini.
        return;
      }
      expect(Env.oauthRedirectFor(isWeb: true), isNot(contains('localhost')));
    });
  });
}
