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
