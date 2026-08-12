import 'package:camera/camera.dart';

import '../config/app_constants.dart';
import '../utils/app_failure.dart';
import '../utils/logger.dart';
import '../utils/result.dart';

/// Kontrol `CameraController` untuk sesi rekam.
///
/// Rincian pipeline perekaman ada di **Bab 8**. Yang sudah dikunci sejak
/// Bab 0–4 dan ditegakkan di sini:
///
/// - Resolusi 480p (Bab 1.3 poin 3) — biaya storage adalah model bisnisnya.
/// - Batas durasi ditegakkan timer **dan** constraint database (Bab 7.4);
///   kelas ini memegang sisi timer-nya.
class CameraService {
  CameraService();

  static const AppLogger _log = AppLogger('CameraService');

  CameraController? _controller;
  List<CameraDescription> _cameras = const [];

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isRecording => _controller?.value.isRecordingVideo ?? false;
  List<CameraDescription> get availableCameraList => _cameras;

  Future<Result<void>> init({CameraLensDirection? preferred}) async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        return Result.err(
          AppFailure.devicePermission('permissionCameraDenied'),
        );
      }

      final camera = _cameras.firstWhere(
        (c) => preferred == null || c.lensDirection == preferred,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        camera,
        // 480p — dikunci Bab 1.3 poin 3.
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await controller.initialize();
      _controller = controller;
      return okVoid;
    } on CameraException catch (e, s) {
      _log.e('Inisialisasi kamera gagal', e, s);
      return Result.err(_mapCameraException(e));
    } on Object catch (e, s) {
      return Result.err(AppFailure.unknown(e, s));
    }
  }

  Future<Result<void>> startRecording() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return Result.err(AppFailure.devicePermission('permissionCameraDenied'));
    }
    try {
      await c.startVideoRecording();
      return okVoid;
    } on CameraException catch (e) {
      return Result.err(_mapCameraException(e));
    }
  }

  Future<Result<String>> stopRecording() async {
    final c = _controller;
    if (c == null || !c.value.isRecordingVideo) {
      return Result.err(AppFailure.unknown('Tidak ada perekaman berjalan'));
    }
    try {
      final file = await c.stopVideoRecording();
      return Result.ok(file.path);
    } on CameraException catch (e) {
      return Result.err(_mapCameraException(e));
    }
  }

  /// Batas durasi efektif: yang lebih kecil antara batas tier dan jaring
  /// pengaman klien.
  Duration effectiveMaxDuration(Duration tierLimit) =>
      tierLimit < AppConstants.hardMaxRecordingDuration
          ? tierLimit
          : AppConstants.hardMaxRecordingDuration;

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }

  AppFailure _mapCameraException(CameraException e) => switch (e.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted' =>
          AppFailure.devicePermission('permissionCameraDenied'),
        'AudioAccessDenied' ||
        'AudioAccessDeniedWithoutPrompt' ||
        'AudioAccessRestricted' =>
          AppFailure.devicePermission('permissionMicrophoneDenied'),
        _ => AppFailure(
            kind: FailureKind.unknown,
            messageKey: 'errorUnknown',
            debugMessage: '${e.code}: ${e.description}',
            code: e.code,
          ),
      };
}
