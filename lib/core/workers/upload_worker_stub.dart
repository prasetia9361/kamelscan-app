import 'upload_worker.dart';

/// Implementasi Web: tidak ada perekaman, jadi tidak ada antrian yang perlu
/// diproses di latar (Bab 1.3 poin 5).
class WebUploadWorker implements UploadWorker {
  const WebUploadWorker();

  @override
  bool get isSupported => false;

  @override
  Future<void> register() async {}

  @override
  Future<void> requestImmediateRun() async {}

  @override
  Future<void> cancelAll() async {}
}

UploadWorker createPlatformUploadWorker() => const WebUploadWorker();
