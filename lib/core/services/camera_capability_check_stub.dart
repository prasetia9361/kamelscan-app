import 'camera_capability_check.dart';

/// Web tidak merekam video (Bab 10.1), jadi pemeriksaan ini tidak berlaku.
Future<CameraCheckReport> runPlatformCameraCapabilityCheck() async {
  return const CameraCheckReport([
    CameraCheckItem(
      name: 'Perekaman tidak tersedia di web',
      passed: true,
      detail: 'Bab 10.1 — jalur perekaman memang tidak dibangun untuk web',
    ),
  ]);
}
