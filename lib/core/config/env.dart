/// Konfigurasi lingkungan.
///
/// 🔴 Bab 4.4 — TIDAK ADA key yang boleh ditulis mati di sini. Semua nilai
/// dibaca dari `--dart-define` (atau `--dart-define-from-file=env.dev.json`).
///
/// `SUPABASE_SERVICE_ROLE_KEY` dan `MIDTRANS_SERVER_KEY` **tidak boleh** ada di
/// aplikasi Flutter dalam bentuk apa pun — keduanya hanya hidup di Supabase
/// Edge Function secrets.
library;

enum AppEnv {
  dev,
  staging,
  prod;

  static AppEnv parse(String raw) => switch (raw.toLowerCase()) {
        'prod' || 'production' => AppEnv.prod,
        'staging' || 'stg' => AppEnv.staging,
        _ => AppEnv.dev,
      };
}

class Env {
  const Env._();

  // ---------- Supabase ----------
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  // ---------- Observability ----------
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// Rasio sampling trace Sentry. 1.0 di dev, turunkan di prod agar hemat kuota.
  ///
  /// Dart hanya menyediakan `fromEnvironment` untuk String/int/bool — tidak ada
  /// varian double — jadi nilainya dibaca sebagai teks lalu diurai.
  static const String _sentryTracesRaw =
      String.fromEnvironment('SENTRY_TRACES_SAMPLE_RATE');

  static double get sentryTracesSampleRate =>
      double.tryParse(_sentryTracesRaw)?.clamp(0.0, 1.0) ?? 0.2;

  // ---------- Login Google (Bab 6.5) ----------
  /// Client ID **tipe Web**, dipakai sebagai `serverClientId` di Android.
  ///
  /// ⚠️ Yang masuk ke aplikasi memang yang tipe Web, BUKAN yang tipe Android.
  /// Client Android tidak pernah disebut dari kode: cukup ada di Google Cloud
  /// Console dengan package name + SHA-1 yang cocok, dan Google Play Services
  /// mencocokkannya sendiri. `idToken` yang dihasilkan beraudiens Client ID
  /// Web, dan itulah yang diverifikasi Supabase.
  ///
  /// Bukan rahasia — memang dirancang untuk tampil di klien.
  static const String googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// Client ID khusus iOS. Boleh kosong selama rilis iOS masih ditunda
  /// (Bab 0.2).
  static const String googleIosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  /// Tombol "Masuk dengan Google" disembunyikan bila belum dikonfigurasi,
  /// daripada tampil lalu gagal saat ditekan.
  static bool get googleSignInConfigured => googleWebClientId.isNotEmpty;

  // ---------- Pembayaran ----------
  /// Hanya CLIENT key. Server key milik Edge Function.
  static const String midtransClientKey =
      String.fromEnvironment('MIDTRANS_CLIENT_KEY');

  // ---------- Lain-lain ----------
  static const String _appEnvRaw =
      String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  /// Base URL Flutter Web (aplikasi ada di `/app`, landing page statis di `/`).
  static const String webAppBaseUrl =
      String.fromEnvironment('WEB_APP_BASE_URL', defaultValue: 'http://localhost:8080');

  /// Skema deep link untuk callback OAuth Google di mobile.
  static const String authRedirectScheme = String.fromEnvironment(
    'AUTH_REDIRECT_SCHEME',
    defaultValue: 'id.kamelscan.app',
  );

  static AppEnv get appEnv => AppEnv.parse(_appEnvRaw);

  static bool get isProd => appEnv == AppEnv.prod;
  static bool get isDev => appEnv == AppEnv.dev;

  /// Tujuan tautan verifikasi email dan reset password (Bab 6.4).
  ///
  /// Harus didaftarkan di Supabase Dashboard → Authentication →
  /// URL Configuration → Redirect URLs. Bila tidak terdaftar, Supabase
  /// mengabaikannya dan memakai Site URL — pengguna mendarat di halaman web,
  /// bukan kembali ke aplikasi.
  static String get emailVerifyRedirectUrl =>
      kIsWebPlatform ? '$webAppBaseUrl/auth/callback' : oauthRedirectUrl;

  /// `kIsWeb` tanpa mengimpor Flutter — Env harus tetap bisa diuji tanpa
  /// binding widget.
  static const bool kIsWebPlatform = bool.fromEnvironment('dart.library.js_util');

  /// Callback OAuth: mobile memakai deep link, web memakai URL halaman.
  static String get oauthRedirectUrl =>
      '$authRedirectScheme://login-callback';

  /// Sentry hanya dipasang bila DSN tersedia.
  static bool get sentryEnabled => sentryDsn.isNotEmpty;

  /// Dipanggil di `main()` sebelum apa pun. Gagal cepat lebih baik daripada
  /// layar putih tanpa penjelasan di tangan pengguna.
  static void assertConfigured() {
    final missing = <String>[
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Variabel lingkungan belum diisi: ${missing.join(', ')}.\n'
        'Jalankan dengan: flutter run --dart-define-from-file=env.dev.json',
      );
    }
  }
}
