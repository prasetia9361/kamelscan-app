import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../models/enums.dart';
import '../utils/logger.dart';
import 'barcode_frame_reader.dart';

/// Implementasi Android/iOS di atas ML Kit.
class MlKitBarcodeFrameReader implements BarcodeFrameReader {
  MlKitBarcodeFrameReader();

  static const AppLogger _log = AppLogger('BarcodeFrameReader');

  BarcodeScanner? _scanner;

  @override
  bool get isSupported => true;

  @override
  Future<void> start(TriggerMode mode) async {
    await close();
    final formats = _formatsFor(mode);
    if (formats.isEmpty) return; // Mode manual — tidak ada yang dipindai.
    _scanner = BarcodeScanner(formats: formats);
  }

  @override
  Future<String?> read(CameraImage image, int sensorOrientation) async {
    final scanner = _scanner;
    if (scanner == null) return null;

    final input = _toInputImage(image, sensorOrientation);
    if (input == null) return null;

    try {
      final barcodes = await scanner.processImage(input);
      for (final b in barcodes) {
        final value = b.rawValue;
        if (value != null && value.isNotEmpty) return value;
      }
    } on Object catch (e) {
      // Satu frame gagal bukan alasan menghentikan perekaman; frame berikutnya
      // datang ± 55 ms lagi.
      _log.w('ML Kit gagal memproses frame', e);
    }
    return null;
  }

  @override
  Future<void> close() async {
    final scanner = _scanner;
    _scanner = null;
    if (scanner != null) {
      try {
        await scanner.close();
      } on Object catch (e) {
        _log.w('Menutup pemindai gagal', e);
      }
    }
  }

  /// Format ML Kit per mode pemicu.
  ///
  /// ⚠️ Sengaja **tidak** memakai `TriggerStrategy.formats`. Daftar itu
  /// bertipe `BarcodeFormat` milik `mobile_scanner` — nama enumnya mirip tetapi
  /// tipenya berbeda dan nilai mentahnya tidak sama, sehingga tidak dapat
  /// dioper langsung ke ML Kit.
  ///
  /// Isinya tetap mengikuti Bab 8.3.3 persis, tidak lebih: setiap format
  /// tambahan memperlambat pemindaian dan menaikkan peluang salah baca.
  static List<BarcodeFormat> _formatsFor(TriggerMode mode) => switch (mode) {
        TriggerMode.qrCode => const [BarcodeFormat.qrCode],
        TriggerMode.barcode1d => const [
            BarcodeFormat.code128,
            BarcodeFormat.code39,
            BarcodeFormat.itf,
            BarcodeFormat.ean13,
            BarcodeFormat.ean8,
            BarcodeFormat.upca,
          ],
        TriggerMode.manual => const [],
      };

  /// Bungkus satu bingkai kamera menjadi masukan ML Kit.
  ///
  /// Bentuk ini yang terbukti bekerja di perangkat: `nv21` satu bidang, ukuran
  /// dan `bytesPerRow` diambil dari bingkainya sendiri, rotasi dari
  /// `sensorOrientation`. Menebak salah satunya menghasilkan pemindaian yang
  /// tidak pernah membaca apa pun **tanpa melempar error** — kegagalan paling
  /// mahal karena terlihat seperti label yang sulit dibaca.
  static InputImage? _toInputImage(CameraImage image, int sensorOrientation) {
    if (image.planes.isEmpty) return null;

    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw as int) ??
        InputImageFormat.nv21;

    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }
}

BarcodeFrameReader createPlatformBarcodeFrameReader() =>
    MlKitBarcodeFrameReader();
