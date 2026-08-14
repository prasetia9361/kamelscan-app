import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/admin_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/shop_repository.dart';
import '../repositories/token_repository.dart';
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
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(supabaseClientProvider));

@Riverpod(keepAlive: true)
AdminRepository adminRepository(Ref ref) =>
    AdminRepository(ref.watch(supabaseClientProvider));
