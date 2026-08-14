import 'package:camera/camera.dart';

import '../models/enums.dart';

// ⚠️ Bab 4.3 — `google_mlkit_barcode_scanning` menarik `dart:io` lewat
// `google_mlkit_commons`, sehingga `flutter build web` GAGAL bila paket ini
// diimpor tanpa penjaga. Layar rekam memang tidak ada di web, tetapi
// `app_router.dart` mengimpornya tanpa syarat, jadi kodenya tetap ikut
// dikompilasi. Pemisahan ini bukan kerapian, melainkan syarat build.
import 'barcode_frame_reader_stub.dart'
    if (dart.library.io) 'barcode_frame_reader_mobile.dart';

/// Membaca barcode/QR dari satu bingkai kamera (Bab 8.3).
///
/// 🔴 Kenapa bukan `mobile_scanner`: `mobile_scanner` memegang kameranya
/// sendiri dan tidak dapat berbagi dengan `camera`, sedangkan alur perekaman
/// wajib memindai **selagi** merekam. Keputusan Product Owner 14 Agustus 2026:
/// pada alur perekaman, `camera` + ML Kit adalah satu-satunya pemilik kamera.
/// `mobile_scanner` tetap dipakai di layar lain yang tidak merekam.
///
/// Terverifikasi di Redmi Note 9 (14 Agustus 2026), pada 480p:
///
/// ```
/// LULUS  Fase A · ML Kit MEMBACA isi kode — qrCode (setelah 72 frame)
/// LULUS  Perpindahan pindai → rekam diterima
/// LULUS  Fase B · ML Kit MEMBACA isi kode selagi merekam (setelah 4 frame)
/// ```
abstract interface class BarcodeFrameReader {
  /// `false` di web — layar rekam wajib memeriksanya sebelum memakai yang lain.
  bool get isSupported;

  /// Siapkan pemindai untuk satu mode pemicu. Mode manual tidak memindai
  /// apa pun, jadi pemanggilan untuknya tidak melakukan apa-apa.
  Future<void> start(TriggerMode mode);

  /// Isi kode mentah pertama yang terbaca dari [image], atau `null`.
  ///
  /// Isi dikembalikan **apa adanya**; penyaringan dan normalisasinya milik
  /// `TriggerStrategy.accept` dan `ScanGate`, bukan di sini.
  Future<String?> read(CameraImage image, int sensorOrientation);

  Future<void> close();
}

BarcodeFrameReader createBarcodeFrameReader() =>
    createPlatformBarcodeFrameReader();
