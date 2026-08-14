import 'dart:async';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import 'camera_capability_check.dart';

/// Lama tiap fase pengamatan.
///
/// Cukup panjang bagi penguji untuk mengarahkan kamera ke label, cukup pendek
/// agar seluruh pemeriksaan tidak melebihi setengah menit.
const Duration _phaseTimeout = Duration(seconds: 12);

/// Format yang dicoba dibaca. Sengaja mencakup QR **dan** satu 1D sekaligus,
/// karena kedua mode dipakai produk dan keduanya perlu dibuktikan.
const List<BarcodeFormat> _formats = [
  BarcodeFormat.qrCode,
  BarcodeFormat.code128,
  BarcodeFormat.ean13,
];

/// Pemeriksaan kemampuan kamera — urutannya **persis** seperti layar rekam.
///
/// Fase A meniru keadaan sebelum resi pertama terbaca, fase B meniru keadaan
/// selagi merekam. Yang diuji bukan sekadar "frame mengalir", melainkan
/// perpindahan di antara keduanya dan apakah ML Kit benar-benar **membaca isi**
/// kode, bukan hanya menerima frame tanpa melempar error.
Future<CameraCheckReport> runPlatformCameraCapabilityCheck() async {
  final items = <CameraCheckItem>[];
  var framesWhileRecording = 0;
  CameraController? controller;
  BarcodeScanner? scanner;
  String? recordedPath;

  try {
    // ---- 1. Kamera tersedia? ----
    final cameras = await availableCameras();
    items.add(CameraCheckItem(
      name: 'Kamera terdeteksi',
      passed: cameras.isNotEmpty,
      detail:
          cameras.isEmpty ? 'availableCameras() kosong' : '${cameras.length} lensa',
    ));
    if (cameras.isEmpty) return CameraCheckReport(items);

    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    // ---- 2. Pratinjau menyala pada resolusi yang sesungguhnya dipakai ----
    //
    // ⚠️ `medium` = 480p, dikunci Bab 1.3 poin 3. Pemeriksaan 14 Agustus
    // memakai `low` (240p) yang lebih ringan; merekam pada 240p lalu
    // menskalakannya ke 480p oleh FFmpeg justru memperbesar berkas tanpa
    // menambah kejelasan. Karena itu resolusi yang diuji di sini harus sama
    // dengan yang dipakai produk.
    controller = CameraController(
      back,
      ResolutionPreset.medium,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await controller.initialize();

    final preview = controller.value.previewSize;
    items.add(CameraCheckItem(
      name: 'Pratinjau 480p menyala',
      passed: true,
      detail: preview == null
          ? null
          : '${preview.width.toInt()}x${preview.height.toInt()}',
    ));

    scanner = BarcodeScanner(formats: _formats);

    // ---- 3. FASE A — memindai SEBELUM merekam ----
    //
    // Inilah keadaan layar rekam saat menunggu resi pertama. Perekaman belum
    // berjalan, jadi jalurnya `startImageStream`.
    final phaseA = _ScanPhase(scanner, back.sensorOrientation);

    await controller.startImageStream(phaseA.onFrame);
    await phaseA.waitUntilDecodedOr(_phaseTimeout);
    await controller.stopImageStream();

    items.add(CameraCheckItem(
      name: 'Fase A · frame mengalir sebelum merekam',
      passed: phaseA.frames > 0,
      detail: '${phaseA.frames} frame',
    ));
    items.add(CameraCheckItem(
      name: 'Fase A · ML Kit MEMBACA isi kode',
      passed: phaseA.decoded != null,
      detail: phaseA.describe(),
    ));

    // ---- 4. FASE B — perpindahan ke perekaman ----
    //
    // 🔴 Butir paling rawan. CameraX mengikat ulang use case-nya di sini;
    // bila penolakan terjadi, seluruh rancangan layar rekam harus berubah.
    final phaseB = _ScanPhase(scanner, back.sensorOrientation);

    try {
      await controller.startVideoRecording(onAvailable: phaseB.onFrame);
      items.add(const CameraCheckItem(
        name: 'Perpindahan pindai → rekam diterima',
        passed: true,
        detail: 'stopImageStream lalu startVideoRecording(onAvailable:)',
      ));
    } on CameraException catch (e) {
      items.add(CameraCheckItem(
        name: 'Perpindahan pindai → rekam diterima',
        passed: false,
        detail: '${e.code}: ${e.description}',
      ));
      return CameraCheckReport(items);
    }

    // ---- 5. Senter selagi merekam ----
    //
    // Bab 8.3.3 mewajibkan tombol senter pada mode barcode. Gudang remang, dan
    // barcode 1D jauh lebih sensitif terhadap cahaya dibanding QR.
    String? torchError;
    try {
      await controller.setFlashMode(FlashMode.torch);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await controller.setFlashMode(FlashMode.off);
    } on CameraException catch (e) {
      torchError = '${e.code}: ${e.description}';
    }
    items.add(CameraCheckItem(
      name: 'Senter menyala selagi merekam',
      passed: torchError == null,
      detail: torchError ?? 'torch on → off',
    ));

    await phaseB.waitUntilDecodedOr(_phaseTimeout);
    framesWhileRecording = phaseB.frames;

    items.add(CameraCheckItem(
      name: 'Fase B · frame mengalir SELAGI merekam',
      passed: phaseB.frames > 0,
      detail: '${phaseB.frames} frame',
    ));
    items.add(CameraCheckItem(
      name: 'Fase B · ML Kit MEMBACA isi kode selagi merekam',
      passed: phaseB.decoded != null,
      detail: phaseB.describe(),
    ));

    // ---- 6. Berkas rekaman benar-benar jadi ----
    final file = await controller.stopVideoRecording();
    recordedPath = file.path;
    final size = await File(recordedPath).length();
    items.add(CameraCheckItem(
      name: 'Berkas video tersimpan',
      passed: size > 0,
      detail: '$size byte',
    ));
  } on CameraException catch (e) {
    items.add(CameraCheckItem(
      name: 'Kamera menolak konfigurasi',
      passed: false,
      detail: '${e.code}: ${e.description}',
    ));
  } on Object catch (e) {
    items.add(CameraCheckItem(
      name: 'Pemeriksaan gagal dijalankan',
      passed: false,
      detail: e.toString(),
    ));
  } finally {
    try {
      await scanner?.close();
      await controller?.dispose();
      if (recordedPath != null) {
        final f = File(recordedPath);
        if (f.existsSync()) await f.delete();
      }
    } on Object {
      // Kegagalan membersihkan tidak boleh menutupi hasil pemeriksaan.
    }
  }

  return CameraCheckReport(items, framesReceived: framesWhileRecording);
}

/// Satu fase pengamatan: menghitung frame dan mencoba membaca isi kode.
class _ScanPhase {
  _ScanPhase(this._scanner, this._sensorOrientation);

  final BarcodeScanner _scanner;
  final int _sensorOrientation;
  final Completer<void> _done = Completer<void>();

  int frames = 0;
  int analyzed = 0;
  String? decoded;
  String? decodedFormat;
  String? error;

  bool _busy = false;

  void onFrame(CameraImage image) {
    frames++;
    // Lewati frame selagi frame sebelumnya masih diproses. Tanpa ini, antrean
    // menumpuk lebih cepat daripada ML Kit menyelesaikannya dan perangkat
    // kehabisan memori.
    if (_busy || decoded != null) return;
    _busy = true;
    unawaited(
      _analyze(image).whenComplete(() => _busy = false),
    );
  }

  Future<void> _analyze(CameraImage image) async {
    try {
      final rotation =
          InputImageRotationValue.fromRawValue(_sensorOrientation) ??
              InputImageRotation.rotation0deg;
      final format = InputImageFormatValue.fromRawValue(image.format.raw as int) ??
          InputImageFormat.nv21;

      final barcodes = await _scanner.processImage(
        InputImage.fromBytes(
          bytes: image.planes.first.bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: format,
            bytesPerRow: image.planes.first.bytesPerRow,
          ),
        ),
      );
      analyzed++;

      for (final b in barcodes) {
        final value = b.rawValue;
        if (value == null || value.isEmpty) continue;
        decoded = value;
        decodedFormat = b.format.name;
        if (!_done.isCompleted) _done.complete();
        return;
      }
    } on Object catch (e) {
      error ??= e.toString();
    }
  }

  /// Berhenti begitu satu kode terbaca, atau setelah [limit] habis.
  Future<void> waitUntilDecodedOr(Duration limit) =>
      _done.future.timeout(limit, onTimeout: () {});

  String describe() {
    if (error != null) return 'ERROR: $error';
    if (decoded == null) {
      return 'tidak ada kode terbaca dari $analyzed frame yang dianalisis '
          '(pastikan kamera diarahkan ke QR/barcode)';
    }
    final shown = decoded!.length > 40 ? '${decoded!.substring(0, 40)}…' : decoded;
    return '$decodedFormat = "$shown" (setelah $analyzed frame)';
  }
}
