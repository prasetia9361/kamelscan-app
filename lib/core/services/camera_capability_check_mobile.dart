import 'dart:async';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import 'camera_capability_check.dart';

/// Lama pengamatan. Cukup panjang untuk melewati beberapa frame, cukup pendek
/// agar pemeriksaan tidak terasa menggantung.
const Duration _observeFor = Duration(seconds: 6);

Future<CameraCheckReport> runPlatformCameraCapabilityCheck() async {
  final items = <CameraCheckItem>[];
  var frames = 0;
  CameraController? controller;
  BarcodeScanner? scanner;
  String? recordedPath;

  try {
    // ---- 1. Kamera tersedia? ----
    final cameras = await availableCameras();
    items.add(CameraCheckItem(
      name: 'Kamera terdeteksi',
      passed: cameras.isNotEmpty,
      detail: cameras.isEmpty ? 'availableCameras() kosong' : '${cameras.length} lensa',
    ));
    if (cameras.isEmpty) return CameraCheckReport(items);

    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    // ---- 2. Pratinjau menyala? ----
    controller = CameraController(
      back,
      // Bab 1.3 poin 3 — 480p. Resolusi rendah juga meringankan analisis frame.
      ResolutionPreset.low,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await controller.initialize();
    items.add(const CameraCheckItem(name: 'Pratinjau kamera menyala', passed: true));

    // ---- 3. Perekaman + aliran frame BERSAMAAN ----
    //
    // Inilah inti pemeriksaan. `startImageStream` terpisah akan melempar bila
    // perekaman sudah berjalan, jadi callback dipasang di startVideoRecording.
    scanner = BarcodeScanner(formats: [BarcodeFormat.qrCode, BarcodeFormat.code128]);
    var analyzed = 0;
    String? analyzeError;
    var busy = false;

    await controller.startVideoRecording(
      onAvailable: (image) {
        frames++;
        // Lewati frame selagi frame sebelumnya masih diproses. Tanpa ini,
        // antrean menumpuk lebih cepat daripada ML Kit menyelesaikannya dan
        // perangkat kehabisan memori.
        if (busy || analyzed >= 3) return;
        busy = true;
        unawaited(
          _analyze(scanner!, image, back.sensorOrientation).then((_) {
            analyzed++;
          }).catchError((Object e) {
            analyzeError ??= e.toString();
          }).whenComplete(() => busy = false),
        );
      },
    );

    await Future<void>.delayed(_observeFor);

    final file = await controller.stopVideoRecording();
    recordedPath = file.path;

    items.add(CameraCheckItem(
      name: 'Frame mengalir SELAGI merekam',
      passed: frames > 0,
      detail: frames > 0
          ? '$frames frame dalam ${_observeFor.inSeconds} detik'
          : 'tidak ada frame sama sekali — aturan pindai-untuk-berhenti '
              'tidak dapat berjalan di perangkat ini',
    ));

    items.add(CameraCheckItem(
      name: 'ML Kit memproses frame',
      passed: analyzed > 0 && analyzeError == null,
      detail: analyzeError ?? '$analyzed frame diproses',
    ));

    // ---- 4. Berkas rekaman benar-benar jadi ----
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

  return CameraCheckReport(items, framesReceived: frames);
}

Future<void> _analyze(
  BarcodeScanner scanner,
  CameraImage image,
  int sensorOrientation,
) async {
  final rotation =
      InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation0deg;
  final format =
      InputImageFormatValue.fromRawValue(image.format.raw as int) ??
          InputImageFormat.nv21;

  await scanner.processImage(
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
}
