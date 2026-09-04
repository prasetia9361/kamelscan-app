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

  /// Bab 6.8 — layar tujuan tautan *Lupa password*.
  ///
  /// 🔴 Ini yang selama ini tidak ada. Tautan reset menghasilkan sesi yang sah
  /// tetapi tidak ada satu pun layar yang meminta password baru, sehingga
  /// pengguna hanya "tiba-tiba masuk" — atau, bila penukaran tautannya gagal,
  /// terdampar di layar Masuk tanpa pesan apa pun.
  ///
  /// Sama seperti [completeProfile], **tidak** masuk daftar [public]: tautannya
  /// sudah membentuk sesi sebelum layar ini dibuka.
  static const String resetPassword = '/reset-password';

  /// Bab 10 — tempat peramban mendarat sesudah menekan tautan verifikasi email
  /// atau tautan *Lupa password* di **web**.
  ///
  /// 🔴 Ini yang selama ini tidak ada. `Env.emailVerifyRedirectUrl` sudah
  /// mengirim `$webAppBaseUrl/auth/callback` sejak Bab 10.2, tetapi tidak ada
  /// satu pun rute dengan alamat itu — sehingga yang menekan tautannya mendarat
  /// di layar *"halaman tidak ditemukan"* dan **tersangkut di sana selamanya**:
  /// alamat itu bukan halaman publik, jadi penjagaan rute pun tidak
  /// memindahkannya ke mana-mana.
  ///
  /// Di HP alamat ini tidak pernah dipakai — tautannya memakai deep link
  /// `id.kamelscan.app://`. Rutenya tetap didaftarkan untuk kedua target
  /// karena membedakannya hanya menambah cabang yang tidak dapat diuji.
  ///
  /// ⚠️ Masuk daftar [public]. Saat peramban mendarat di sini sesi belum tentu
  /// sudah terbentuk, dan tanpa itu penjagaan rute akan melemparnya ke layar
  /// Masuk sebelum tautannya sempat ditukar.
  static const String authCallback = '/auth/callback';

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

  /// Bab 9.6 — hapus akun, dan layar kunci selama menunggu dimusnahkan.
  static const String deleteAccount = '/account/delete';
  static const String deletionPending = '/deletion-pending';

  /// Bab 9.6 butir 1 — ubah nama, nomor HP, username, dan foto profil.
  static const String editProfile = '/account/edit';
  static const String settings = '/settings';
  static const String payment = '/payment';
  static const String checkout = '/payment/checkout';

  /// Riwayat pembayaran (Bab 7.2) — diminta Product Owner 3 September 2026.
  ///
  /// ⚠️ Anak dari [payment], jadi ia sudah tercakup pola `payment/*` yang ada
  /// di `deploy_web.ps1`. Tidak ada baris baru yang perlu ditambahkan di sana
  /// — dan itu disengaja: rute tingkat atas yang terlupa menjawab 200 sambil
  /// menyajikan halaman landing, bukan 404 (lihat catatan `deploy_web.ps1`).
  ///
  /// 🔴 Berbeda dari [checkout], rute ini TETAP hidup di HP. Bab 12.5 menutup
  /// jalur **membayar**, bukan jalur melihat apa yang sudah dibayar; riwayat
  /// tidak dipersoalkan App Store.
  static const String paymentHistory = '/payment/history';

  /// Tutorial versi **web** — menu sidebar tersendiri (Bab 10.3).
  ///
  /// 🔴 Di HP alamatnya BUKAN ini, melainkan [homeTutorial]. Tutorial di HP
  /// dibuka dari Beranda dan hidup di bawahnya, sehingga punya tombol kembali
  /// dan menu bawah tetap menyala di Beranda. Di web ia sejajar dengan menu
  /// lain karena Bab 10.3 memintanya begitu.
  static const String tutorial = '/tutorial';

  /// Tutorial versi **HP** — anak dari Beranda.
  ///
  /// 🔴 Alamat ini harus ditulis utuh, bukan `'/tutorial'`. GoRouter selalu
  /// menyambung alamat anak ke induknya (`path_utils.dart:108`), tanpa peduli
  /// anaknya diawali garis miring atau tidak. Sebelum 25 Agustus 2026 Beranda
  /// membuka `'/tutorial'` sementara rutenya terdaftar di bawah `/home`,
  /// sehingga yang menekannya mendarat di layar "halaman tidak ditemukan".
  /// Tidak ada tes maupun `analyze` yang menangkapnya.
  static const String homeTutorial = '/home/tutorial';

  // ---------- Perekaman (mobile saja) ----------
  static const String recordSetup = '/record';
  static const String recordCamera = '/record/camera';

  // ---------- Admin ----------
  static const String adminDashboard = '/admin';
  static const String adminUsers = '/admin/users';
  static const String adminPayments = '/admin/payments';

  /// Bab 11.1 — angka ringkasan seluruh platform.
  ///
  /// ⚠️ Satu-satunya layar yang menampilkan data lintas pelanggan.
  /// Penjagaannya ada di server (`get_platform_stats()` menolak yang bukan
  /// admin), bukan hanya di penjagaan rute ini.
  static const String adminStats = '/admin/stats';

  // ---------- Admin: pengaturan platform (Bab 11.3–11.6) ----------
  //
  // 🔴 Keempatnya mengubah aturan yang berlaku bagi SELURUH pelanggan
  // sekaligus, bukan satu pelanggan. Sampai 29 Agustus 2026 semuanya
  // dikerjakan lewat Supabase Dashboard.
  static const String adminPricing = '/admin/pricing';
  static const String adminPromos = '/admin/promos';
  static const String adminPaymentMethods = '/admin/payment-methods';
  static const String adminContact = '/admin/contact';

  /// Bab 9.9 — Admin memasukkan tautan YouTube tiap langkah tutorial.
  ///
  /// Tercakup pola `admin/*` di `deploy_web.ps1`.
  static const String adminTutorials = '/admin/tutorials';

  /// Bab 11.5 — gambar iklan landing page dan kartu paket.
  ///
  /// Tercakup pola `admin/*` di `deploy_web.ps1`.
  static const String adminBanners = '/admin/banners';

  /// Bab 2.2 — panduan membuat akun Admin baru.
  ///
  /// 🔴 Halaman ini TIDAK membuat akun. Bab 2.2 melarang jalur registrasi
  /// menjadi admin dari aplikasi; yang disediakan hanya perintah SQL siap
  /// salin untuk dijalankan di Supabase Dashboard.
  static const String adminNewAdmin = '/admin/new-admin';

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
  /// [query] dipakai kolom *Cari resi* di bilah atas web (Bab 10.3). Ia ikut
  /// lewat **query** dengan alasan yang sama seperti [typeWire]: alamat yang
  /// disegarkan atau dikirim ke rekan kerja harus membuka pencarian yang sama.
  /// Menangani komplain adalah pekerjaan berdua — pencarian yang tidak dapat
  /// ditautkan memaksa orang kedua mengetik ulang nomor resinya.
  static String historyOf({String? typeWire, String? query}) {
    final q = <String, String>{
      'type': ?typeWire,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    };
    return q.isEmpty
        ? history
        : Uri(path: history, queryParameters: q).toString();
  }

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
    authCallback,
  };

  static bool isPublic(String location) {
    if (public.contains(location)) return true;
    // Tautan bukti publik selalu terbuka sampai `public_expires_at` habis
    // (Bab 7.6) — termasuk saat langganan pemiliknya sudah berakhir.
    return location.startsWith('/v/');
  }
}
