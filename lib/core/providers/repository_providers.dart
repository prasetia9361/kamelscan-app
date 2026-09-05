import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/account_deletion_repository.dart';
import '../repositories/admin_repository.dart';
import '../repositories/admin_settings_repository.dart';
import '../repositories/announcement_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/dashboard_repository.dart';
import '../repositories/home_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/shop_repository.dart';
import '../repositories/subscription_repository.dart';
import '../repositories/token_repository.dart';
import '../repositories/tutorial_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/video_repository.dart';
import '../services/auth_service.dart';
import '../services/barcode_frame_reader.dart';
import '../services/camera_service.dart';
import '../services/connectivity_service.dart';
import '../services/local_db_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import '../services/scan_feedback.dart';
import '../services/supabase_service.dart';
import '../services/tts_service.dart';
import '../services/video_processor.dart';
import '../workers/retention_checker.dart';
import '../workers/upload_worker.dart';

part 'repository_providers.g.dart';

/// Titik injeksi tunggal (Bab 3.1 — Riverpod sebagai DI).
///
/// ViewModel membaca provider di sini; **tidak ada** ViewModel yang membuat
/// Repository atau Service sendiri, agar semuanya dapat diganti mock saat uji.

// ---------- Client ----------

@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) => SupabaseService.client;

// ---------- Services ----------

@Riverpod(keepAlive: true)
AuthService authService(Ref ref) => const AuthService();

@Riverpod(keepAlive: true)
ConnectivityService connectivityService(Ref ref) => ConnectivityService();

@Riverpod(keepAlive: true)
LocationService locationService(Ref ref) => const LocationService();

@Riverpod(keepAlive: true)
TtsService ttsService(Ref ref) {
  final service = TtsService();
  ref.onDispose(service.stop);
  return service;
}

@Riverpod(keepAlive: true)
PermissionService permissionService(Ref ref) => const PermissionService();

@Riverpod(keepAlive: true)
ScanFeedback scanFeedback(Ref ref) => const ScanFeedback();

/// Kamera bersifat berat dan eksklusif — dibuang begitu layar rekam ditutup.
@riverpod
CameraService cameraService(Ref ref) {
  final service = CameraService();
  ref.onDispose(service.dispose);
  return service;
}

/// Pemindai ML Kit. Sama seperti kamera: berat, dan sesi ML Kit yang tidak
/// ditutup menahan memori native meski layarnya sudah ditinggalkan.
@riverpod
BarcodeFrameReader barcodeFrameReader(Ref ref) {
  final reader = createBarcodeFrameReader();
  ref.onDispose(reader.close);
  return reader;
}

@Riverpod(keepAlive: true)
VideoProcessor videoProcessor(Ref ref) => createVideoProcessor();

@Riverpod(keepAlive: true)
LocalDbService localDbService(Ref ref) {
  final service = createLocalDbService();
  ref.onDispose(service.close);
  return service;
}

@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) => createNotificationService();

@Riverpod(keepAlive: true)
UploadWorker uploadWorker(Ref ref) => createUploadWorker();

@Riverpod(keepAlive: true)
RetentionChecker retentionChecker(Ref ref) => const RetentionChecker();

// ---------- Repositories ----------

@Riverpod(keepAlive: true)
UserRepository userRepository(Ref ref) =>
    UserRepository(ref.watch(supabaseClientProvider));

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => AuthRepository(
      ref.watch(authServiceProvider),
      ref.watch(userRepositoryProvider),
    );

@Riverpod(keepAlive: true)
ShopRepository shopRepository(Ref ref) =>
    ShopRepository(ref.watch(supabaseClientProvider));

@Riverpod(keepAlive: true)
VideoRepository videoRepository(Ref ref) =>
    VideoRepository(ref.watch(supabaseClientProvider));

@Riverpod(keepAlive: true)
TokenRepository tokenRepository(Ref ref) =>
    TokenRepository(ref.watch(supabaseClientProvider));

@Riverpod(keepAlive: true)
HomeRepository homeRepository(Ref ref) =>
    HomeRepository(ref.watch(supabaseClientProvider));

@Riverpod(keepAlive: true)
DashboardRepository dashboardRepository(Ref ref) =>
    DashboardRepository(ref.watch(supabaseClientProvider));

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(supabaseClientProvider));

@Riverpod(keepAlive: true)
SubscriptionRepository subscriptionRepository(Ref ref) =>
    SubscriptionRepository(ref.watch(supabaseClientProvider));

@Riverpod(keepAlive: true)
AccountDeletionRepository accountDeletionRepository(Ref ref) =>
    AccountDeletionRepository(ref.watch(supabaseClientProvider));

@Riverpod(keepAlive: true)
AdminRepository adminRepository(Ref ref) =>
    AdminRepository(ref.watch(supabaseClientProvider));

/// Pengaturan platform yang dapat diubah Admin (Bab 11.3–11.6).
///
/// Dipisah dari [adminRepository] karena isinya berbeda sifat: yang satu
/// mengubah **pelanggan**, yang ini mengubah **aturan yang berlaku bagi
/// seluruh pelanggan sekaligus**.
@Riverpod(keepAlive: true)
AdminSettingsRepository adminSettingsRepository(Ref ref) =>
    AdminSettingsRepository(ref.watch(supabaseClientProvider));

/// Daftar tutorial yang dilihat Owner dan packer (Bab 9.9).
///
/// Sisi bacanya saja. CRUD milik Admin hidup di [adminSettingsRepository],
/// mengikuti pemisahan yang sudah dipakai promo.
@Riverpod(keepAlive: true)
TutorialRepository tutorialRepository(Ref ref) =>
    TutorialRepository(ref.watch(supabaseClientProvider));

/// Iklan & pengumuman yang muncul sesudah pengguna masuk (migrasi 50).
///
/// Sisi bacanya saja, ditambah pencatatan bahwa sebuah pengumuman sudah
/// ditutup. CRUD milik Admin hidup di [adminSettingsRepository], mengikuti
/// pemisahan yang sudah dipakai promo dan tutorial.
@Riverpod(keepAlive: true)
AnnouncementRepository announcementRepository(Ref ref) =>
    AnnouncementRepository(ref.watch(supabaseClientProvider));
