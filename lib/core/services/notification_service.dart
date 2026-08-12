// ⚠️ Bab 4.3 — `flutter_local_notifications` tidak berjalan di Flutter Web.
import 'notification_stub.dart'
    if (dart.library.io) 'notification_mobile.dart';

/// Notifikasi lokal untuk progres antrian upload (Bab 3.2).
///
/// Push notification **tidak** termasuk MVP (Bab 0.2 — digeser ke Fase 2).
/// Yang ada di sini murni notifikasi lokal dari perangkat sendiri: memberi
/// tahu packer bahwa video sedang/selesai diunggah saat aplikasi di latar.
abstract interface class NotificationService {
  bool get isSupported;

  Future<void> init();

  /// Minta izin notifikasi (Android 13+ dan iOS).
  Future<bool> requestPermission();

  /// Notifikasi progres yang diperbarui di tempat, bukan menumpuk.
  Future<void> showUploadProgress({
    required int pending,
    required int total,
  });

  Future<void> showUploadComplete({required int uploaded});

  Future<void> showUploadFailed({required String resiCode});

  Future<void> cancelAll();
}

NotificationService createNotificationService() =>
    createPlatformNotificationService();
