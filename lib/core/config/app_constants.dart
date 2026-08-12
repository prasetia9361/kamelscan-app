/// Konstanta aplikasi: durasi, limit, dan key penyimpanan lokal.
///
/// Aturan: angka yang **dapat diubah Admin tanpa rilis** (harga, kuota,
/// retensi, durasi video) TIDAK ada di sini — itu milik `platform_settings`
/// dan dibaca lewat [TierConfig]. Yang ada di sini hanya angka teknis klien.
library;

class AppConstants {
  const AppConstants._();

  static const String appName = 'KamelScan';

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

  // ---------- Nama Edge Function ----------
  static const String fnGetUploadUrl = 'get-upload-url';
  static const String fnGetVideoUrl = 'get-video-url';
  static const String fnCreatePublicLink = 'create-public-link';
  static const String fnCreatePacker = 'create-packer';
  static const String fnResolveUsername = 'resolve-username';
  static const String fnMidtransCharge = 'midtrans-charge';

  // ---------- Nama tugas WorkManager ----------
  static const String taskUploadQueue = 'kamelscan.uploadQueue';
  static const String taskRetentionCheck = 'kamelscan.retentionCheck';
}
