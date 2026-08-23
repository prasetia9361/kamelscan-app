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

  /// Bab 9.6 butir 1 — ubah nama, nomor HP, username, dan foto profil.
  static const String editProfile = '/account/edit';
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

  /// Layar kamera membawa ketiga pilihan Bab 8.2 di **query**, bukan `extra`.
  ///
  /// Alasannya bukan gaya: `extra` hilang begitu aplikasi di-restart atau rute
  /// dipulihkan, dan layar kamera akan terbuka tanpa tahu kamera, mode, maupun
  /// toko mana yang dipilih — lalu gagal dengan cara yang membingungkan.
  /// [shopName] ikut dibawa karena watermark memerlukannya (Bab 8.5) dan
  /// gudang sering tanpa sinyal — menanyakannya ulang ke server saat memproses
  /// video akan gagal justru di tempat aplikasi ini dipakai.
  /// [typeWire] menerima `VideoType.wire` — `packing` atau `return`. Ia ikut
  /// dibawa di query dengan alasan yang sama seperti yang lain: rute yang
  /// dipulihkan tanpa tipe akan menyimpan video return **sebagai packing**, dan
  /// tabrakan dengan indeks `uq_resi_per_tenant_type` baru terlihat jauh
  /// kemudian, saat packer ditolak "resi sudah pernah direkam".
  static String recordCameraOf({
    required String cameraName,
    required String triggerWire,
    required String shopId,
    required String typeWire,
    String shopName = '',
  }) =>
      Uri(
        path: recordCamera,
        queryParameters: {
          'camera': cameraName,
          'mode': triggerWire,
          'shop': shopId,
          'type': typeWire,
          if (shopName.isNotEmpty) 'shop_name': shopName,
        },
      ).toString();

  /// Layar setup dengan jenis paket yang sudah terpilih (Bab 9.2 — menu
  /// *Rekam Paket Packing* / *Rekam Paket Return* di Beranda).
  static String recordSetupOf({required String typeWire}) =>
      Uri(path: recordSetup, queryParameters: {'type': typeWire}).toString();

  /// Riwayat yang sudah tersaring menurut tipe video (Bab 9.2 — kartu
  /// monitoring dapat ditekan).
  ///
  /// Filternya dikirim lewat **query**, dengan alasan yang sama seperti
  /// [recordCameraOf]: `extra` hilang saat rute dipulihkan, dan Riwayat akan
  /// terbuka tanpa filter tanpa ada yang menyadarinya. [typeWire] menerima
  /// `VideoType.wire` agar berkas ini tidak perlu mengenal model.
  static String historyOf({String? typeWire}) => typeWire == null
      ? history
      : Uri(path: history, queryParameters: {'type': typeWire}).toString();

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
