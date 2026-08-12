import 'notification_service.dart';

/// Implementasi Web: tanpa perekaman berarti tanpa antrian upload, sehingga
/// tidak ada yang perlu diberitahukan. Semua metode diam-diam tidak melakukan
/// apa pun — ini satu-satunya service yang no-op diam dapat dibenarkan.
class WebNotificationService implements NotificationService {
  const WebNotificationService();

  @override
  bool get isSupported => false;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> showUploadProgress({
    required int pending,
    required int total,
  }) async {}

  @override
  Future<void> showUploadComplete({required int uploaded}) async {}

  @override
  Future<void> showUploadFailed({required String resiCode}) async {}

  @override
  Future<void> cancelAll() async {}
}

NotificationService createPlatformNotificationService() =>
    const WebNotificationService();
