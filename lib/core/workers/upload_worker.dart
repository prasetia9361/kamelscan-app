// ⚠️ Bab 4.3 — `workmanager` tidak berjalan di Flutter Web, dan hanya Android
// yang menjamin eksekusi terjadwal. iOS memakai `BGTaskScheduler` yang **tidak
// menjamin** kapan tugas dijalankan; strateginya adalah memproses antrian saat
// aplikasi dibuka + `beginBackgroundTask` maksimal 30 detik saat ditutup.
// Keterbatasan ini harus disampaikan ke klien sejak awal.
import 'upload_worker_stub.dart'
    if (dart.library.io) 'upload_worker_mobile.dart';

/// Pemroses antrian upload di latar belakang (Bab 3.2 / Bab 8).
abstract interface class UploadWorker {
  bool get isSupported;

  /// Daftarkan tugas periodik. Aman dipanggil berkali-kali.
  Future<void> register();

  /// Minta pemrosesan antrian sekarang juga — dipakai saat koneksi kembali
  /// atau saat aplikasi dibuka.
  Future<void> requestImmediateRun();

  Future<void> cancelAll();
}

UploadWorker createUploadWorker() => createPlatformUploadWorker();
