/// Konstanta aplikasi: durasi, limit, dan key penyimpanan lokal.
///
/// Aturan: angka yang **dapat diubah Admin tanpa rilis** (harga, kuota,
/// retensi, durasi video) TIDAK ada di sini — itu milik `platform_settings`
/// dan dibaca lewat [TierConfig]. Yang ada di sini hanya angka teknis klien.
library;

class AppConstants {
  const AppConstants._();

  static const String appName = 'KamelScan';

  /// Versi dokumen Syarat & Ketentuan yang berlaku (Bab 6.2).
  ///
  /// Disimpan bersama waktu persetujuan di `users.terms_version`. **Naikkan
  /// setiap kali dokumennya direvisi** — pengguna yang menyetujui versi lama
  /// akan otomatis diminta menyetujui lagi.
  ///
  /// Tanpa versi, catatan persetujuan tidak dapat menjawab pertanyaan yang
  /// justru muncul saat sengketa: "pelanggan ini menyetujui isi yang mana?"
  static const String termsVersion = '2026-08-01';

  static const String termsUrl = 'https://kamelscan.com/syarat-ketentuan';
  static const String privacyUrl = 'https://kamelscan.com/kebijakan-privasi';

  /// Kontak dukungan. Sumber kebenarannya adalah `platform_settings.contact`
  /// agar Admin bisa mengubahnya tanpa rilis baru (Bab 5.2); nilai di bawah
  /// hanya cadangan untuk layar error saat perangkat offline dan pengaturan
  /// platform belum pernah tersinkron.
  static const String supportWhatsApp = '6285113214018';
  static const String supportEmail = 'aiotideaproject@gmail.com';

  // ---------- Perekaman ----------
  /// Resolusi dikunci 480p demi biaya storage (Bab 1.3 poin 3).
  static const int recordingHeightPx = 480;

  /// Batas keras di sisi klien. Batas per-tier tetap datang dari TierConfig,
  /// nilai ini hanya jaring pengaman agar timer tidak pernah liar.
  static const Duration hardMaxRecordingDuration = Duration(seconds: 120);

  /// Jeda minimal sebelum kode yang sama boleh dibaca lagi (Bab 4.3).
  static const Duration scanDebounce = Duration(milliseconds: 1500);

  /// Debounce pengecekan resi ganda pada mode input manual (Bab 7.7).
  static const Duration manualResiCheckDebounce = Duration(milliseconds: 500);

  /// Jarak minimal antar-frame yang diserahkan ke ML Kit — ± 8 kali per detik.
  ///
  /// 🔴 Kamera mengirim ± 30 frame per detik, dan sebelumnya **semuanya**
  /// dibaca. Itu pemborosan yang mahal: ML Kit adalah beban CPU terberat di
  /// layar rekam, dan pada Redmi Note 9 ia bersaing langsung dengan encoder
  /// FFmpeg yang mengolah rekaman sebelumnya. Diukur 15 Agustus 2026: saat
  /// keduanya berebut, watermark 30 detik melar dari 19 ke 32 detik — melewati
  /// batas 1,0x, artinya antrean akan menumpuk tanpa henti.
  ///
  /// 8 kali per detik masih jauh lebih cepat daripada packer memindahkan paket,
  /// dan tetap aman untuk aturan pembacaan ganda barcode 1D: jendela
  /// konfirmasinya 5 detik, sedangkan dua pembacaan berjarak ± 125 ms.
  ///
  /// ⚠️ Jangan dinaikkan tanpa mengukur ulang di perangkat. Menjarangkan
  /// terlalu jauh membuat barcode terlewat saat paket digeser cepat.
  static const Duration scanFrameInterval = Duration(milliseconds: 125);

  /// Lama perekaman minimum sebelum pemindaian boleh menghentikannya.
  ///
  /// 🔴 PENYIMPANGAN DARI BAB 8.3.2 — disetujui Product Owner 13 Agustus 2026.
  ///
  /// Bab 8.3.2 menetapkan perekaman berhenti saat resi **BERBEDA** terbaca.
  /// Aturan itu janggal di lapangan: untuk menghentikan rekaman paket
  /// terakhir, packer harus mencari label paket lain — padahal tidak ada lagi
  /// paket berikutnya.
  ///
  /// Aturan yang dipakai:
  ///   1. Pindai pertama  → mulai merekam
  ///   2. 5 detik pertama → pemindaian tidak dapat menghentikan
  ///   3. Setelah 5 detik → pindai resi yang SAMA menghentikan
  ///   4. Resi BERBEDA    → perekaman lanjut, disertai pesan di layar
  ///
  /// Jendela 5 detik sekaligus menutup masalah kamera yang masih menghadap
  /// label sesaat setelah perekaman dimulai.
  ///
  /// ⚠️ Batas ini **tidak berlaku untuk tombol Berhenti**. Bab 8.3.1 menyebut
  /// tombol itu satu-satunya cara berhenti yang pasti berfungsi; mematikannya
  /// selama 5 detik akan menjebak packer yang menyadari salah pindai.
  static const Duration minRecordingBeforeScanStop = Duration(seconds: 5);

  // ---------- Antrian upload ----------
  static const int maxUploadAttempts = 5;
  static const Duration uploadRetryBaseDelay = Duration(seconds: 30);
  static const Duration uploadChunkTimeout = Duration(minutes: 5);

  /// iOS tidak menjamin eksekusi background; ini batas aman `beginBackgroundTask`.
  static const Duration iosBackgroundUploadBudget = Duration(seconds: 30);

  // ---------- UI ----------
  static const Duration snackBarDuration = Duration(seconds: 4);
  static const Duration searchDebounce = Duration(milliseconds: 350);
  static const int historyPageSize = 20;

  /// Baris per halaman pada tabel Riwayat versi web (Bab 10.5).
  ///
  /// Lebih besar daripada [historyPageSize] karena bentuknya berbeda: HP
  /// memakai gulir tak berujung pada kartu setinggi ± 88 px, sedangkan tabel
  /// web menampilkan baris setinggi ± 52 px pada layar yang jauh lebih tinggi.
  /// Dua puluh baris menyisakan setengah layar kosong di bawah tabel.
  static const int webHistoryPageSize = 25;

  /// Ambang indikator token (Bab 7.3).
  static const double tokenWarningRatio = 0.20;
  static const double tokenCriticalRatio = 0.05;

  /// Hari peringatan sebelum langganan berakhir (Bab 7.6).
  static const List<int> subscriptionWarningDays = [7, 3, 1];

  // ---------- Key SharedPreferences / SecureStorage ----------
  static const String prefThemeMode = 'pref_theme_mode';
  static const String prefLanguage = 'pref_language';
  static const String prefVoiceOverEnabled = 'pref_voice_over_enabled';
  static const String prefLastShopId = 'pref_last_shop_id';
  static const String prefTriggerMode = 'pref_trigger_mode';

  /// Bab 8.3.4 — mode Input Manual menyimpan 5 resi terakhir sebagai saran,
  /// membantu saat merekam ulang setelah kegagalan.
  /// Bab 8.7 langkah 1 — "Unggah juga lewat data seluler".
  ///
  /// Disimpan di perangkat, bukan di server: ini preferensi milik satu HP.
  /// Packer dengan kuota data terbatas tidak seharusnya terikat pilihan packer
  /// lain yang memakai HP kantor.
  static const String prefUploadOnCellular = 'pref_upload_on_cellular';

  /// Bab 9.7 — "Rekam dengan suara". Diminta Product Owner 19 Agustus 2026.
  ///
  /// Disimpan di perangkat, bukan di server: keputusan Product Owner pada hari
  /// yang sama, sejalan dengan sakelar data seluler di atas.
  ///
  /// ⚠️ Bawaannya **menyala**. Sampai sakelar ini ada, seluruh video direkam
  /// bersuara selama izin mikrofon diberikan; bawaan mati akan diam-diam
  /// mengubah isi bukti pada perangkat yang sudah dipakai.
  static const String prefMicEnabled = 'pref_mic_enabled';

  /// Salinan lokal `tenant_settings` agar watermark tetap sesuai pengaturan
  /// pelanggan walaupun videonya diproses saat perangkat tanpa sinyal.
  static const String prefTenantSettings = 'pref_tenant_settings';

  static const String prefRecentResi = 'pref_recent_resi';
  static const int recentResiCount = 5;
  static const String prefOnboardingSeen = 'pref_onboarding_seen';
  static const String secureSessionKey = 'secure_supabase_session';

  // ---------- Nama tabel Supabase (hindari string literal berserakan) ----------
  static const String tblTenants = 'tenants';
  static const String tblUsers = 'users';
  static const String tblShops = 'shops';
  static const String tblShopPackers = 'shop_packers';
  static const String tblPackageVideos = 'package_videos';
  static const String tblTokenWallets = 'token_wallets';
  static const String tblTokenLedger = 'token_ledger';
  static const String tblSubscriptions = 'subscriptions';
  static const String tblUserSettings = 'user_settings';
  static const String tblTenantSettings = 'tenant_settings';
  static const String tblPlatformSettings = 'platform_settings';
  static const String tblPromos = 'promos';
  static const String tblTutorials = 'tutorials';
  static const String tblAuditLogs = 'audit_logs';

  // ---------- Bucket Supabase Storage ----------
  //
  // ⚠️ Hanya foto profil. Video bukti TIDAK pernah masuk Supabase Storage —
  // ia langsung ke Cloudflare R2 (Bab 8.7), dan bucket ini publik.
  static const String bucketAvatars = 'avatars';

  /// Bukti transfer manual (Bab 12.2). **Bucket privat** — isinya tangkapan
  /// layar mutasi rekening, dibaca hanya lewat URL bertanda tangan.
  static const String bucketPaymentProofs = 'payment-proofs';

  // ---------- Nama Edge Function ----------
  static const String fnGetUploadUrl = 'get-upload-url';
  static const String fnGetVideoUrl = 'get-video-url';
  static const String fnCreatePublicLink = 'create-public-link';

  /// Satu-satunya Edge Function yang sengaja dapat dipanggil tanpa sesi login.
  /// Yang menjaganya adalah token 160 bit pada tautannya sendiri (Bab 10.6).
  static const String fnGetPublicVideo = 'get-public-video';
  static const String fnCreatePacker = 'create-packer';
  static const String fnDeletePacker = 'delete-packer';
  static const String fnResolveUsername = 'resolve-username';
  /// Membuat tagihan Midtrans Snap dan mengembalikan `redirect_url`
  /// (Bab 12.3).
  ///
  /// ⚠️ Sampai 30 Agustus 2026 konstanta ini bernama `midtrans-charge` dan
  /// tidak dipakai satu baris pun — nama karangan yang tidak pernah cocok
  /// dengan Edge Function mana pun. Namanya kini mengikuti diagram Bab 12.3
  /// dan berkas yang benar-benar ada.
  static const String fnCreatePayment = 'create-payment';

  // ---------- Nama tugas WorkManager ----------
  static const String taskUploadQueue = 'kamelscan.uploadQueue';
  static const String taskRetentionCheck = 'kamelscan.retentionCheck';
}
