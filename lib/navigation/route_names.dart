/// Konstanta rute. 🔴 Bab 3.2 — **jangan pernah menulis path sebagai string
/// literal** di widget. Salah ketik satu huruf hanya ketahuan saat runtime.
class Routes {
  const Routes._();

  // ---------- Publik ----------
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String verifyEmail = '/verify-email';
  static const String forgotPassword = '/forgot-password';

  /// Ganti password. Juga menjadi tujuan paksa bagi packer yang masih memakai
  /// password sementara (Bab 6.7) — karena itu ia **tidak** masuk daftar
  /// [public]: pengguna harus sudah login untuk sampai ke sini.
  static const String changePassword = '/change-password';

  /// Bab 6.2 — tujuan paksa bagi pengguna yang masuk lewat Google tanpa pernah
  /// mengisi nomor HP maupun menyetujui S&K.
  ///
  /// Sama seperti [changePassword], **tidak** masuk daftar [public]: hanya
  /// dapat dicapai setelah login, dan tidak dapat dilewati.
  static const String completeProfile = '/complete-profile';

  /// Halaman bukti publik yang dibuka pihak marketplace tanpa login.
  static const String publicVideo = '/v/:token';

  // ---------- Terlindungi (mobile shell) ----------
  static const String home = '/home';
  static const String history = '/history';
  static const String videoDetail = '/history/:id';
  static const String shops = '/shops';
  static const String shopForm = '/shops/form';
  static const String shopEdit = '/shops/form/:id';
  static const String account = '/account';
  static const String packers = '/account/packers';
  static const String settings = '/settings';
  static const String watermark = '/settings/watermark';
  static const String payment = '/payment';
  static const String checkout = '/payment/checkout';
  static const String tutorial = '/tutorial';

  // ---------- Perekaman (mobile saja) ----------
  static const String recordSetup = '/record';
  static const String recordCamera = '/record/camera';
  static const String recordResult = '/record/result';

  // ---------- Admin ----------
  static const String adminDashboard = '/admin';
  static const String adminUsers = '/admin/users';
  static const String adminPayments = '/admin/payments';

  // ---------- Web ----------
  static const String webDashboard = '/dashboard';

  // ---------- Pembentuk path berparameter ----------

  static String videoDetailOf(String id) => '/history/$id';
  static String shopEditOf(String id) => '/shops/form/$id';
  static String publicVideoOf(String token) => '/v/$token';

  /// Rute yang boleh diakses tanpa sesi login.
  static const Set<String> public = {
    splash,
    login,
    register,
    verifyEmail,
    forgotPassword,
  };

  static bool isPublic(String location) {
    if (public.contains(location)) return true;
    // Tautan bukti publik selalu terbuka sampai `public_expires_at` habis
    // (Bab 7.6) — termasuk saat langganan pemiliknya sudah berakhir.
    return location.startsWith('/v/');
  }
}
