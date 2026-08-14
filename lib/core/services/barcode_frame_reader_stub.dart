import 'package:camera/camera.dart';

import '../models/enums.dart';
import 'barcode_frame_reader.dart';

/// Implementasi web: jujur menolak, tidak berpura-pura bekerja.
///
/// Bab 10.1 — perekaman memang tidak ada di web, dan menyembunyikan
/// ketidakmampuan ini di balik `null` yang diam akan membuat layar menunggu
/// resi selamanya tanpa satu pun keterangan.
class UnsupportedBarcodeFrameReader implements BarcodeFrameReader {
  const UnsupportedBarcodeFrameReader();

  @override
  bool get isSupported => false;

  @override
  Future<void> start(TriggerMode mode) async {}

  @override
  Future<String?> read(CameraImage image, int sensorOrientation) async => null;

  @override
  Future<void> close() async {}
}

BarcodeFrameReader createPlatformBarcodeFrameReader() =>
    const UnsupportedBarcodeFrameReader();
