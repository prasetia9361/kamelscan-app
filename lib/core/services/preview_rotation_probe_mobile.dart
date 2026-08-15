import 'dart:io' show Platform;
import 'dart:ui' show Size;

import 'package:camera_android_camerax/camera_android_camerax.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Menanyakan langsung ke CameraX: sebesar apa bingkai pratinjau sekarang?
///
/// Hanya berlaku di Android. iOS memakai `camera_avfoundation`, yang tidak
/// pernah menyalakan StreamSharing sehingga tidak punya masalah yang sama.
///
/// 🔴 **Jejak `KAMELSCAN_ROTASI` di bawah sengaja memakai `debugPrint`, bukan
/// `AppLogger`.** `AppLogger` memakai `dart:developer` yang **tidak pernah
/// sampai ke logcat** — hanya ke terminal `flutter run`. Begitu terminal itu
/// ditutup, kegagalan penyelidik ini tidak dapat didiagnosis dari perangkat
/// sama sekali; buta itu sempat membuang satu putaran build penuh pada
/// 15 Agustus 2026. Jejaknya akan dibutuhkan lagi saat menguji di perangkat
/// dengan tingkat kamera berbeda. Lihat bagian J di `DEVIASI_LIBRARY.md`.
Future<Size?> readPlatformLivePreviewResolution() async {
  if (!Platform.isAndroid) {
    debugPrint('KAMELSCAN_ROTASI: bukan Android — dilewati');
    return null;
  }

  final platform = CameraPlatform.instance;
  if (platform is! AndroidCameraCameraX) {
    debugPrint('KAMELSCAN_ROTASI: GAGAL — CameraPlatform.instance bertipe '
        '${platform.runtimeType}, bukan AndroidCameraCameraX');
    return null;
  }

  // `preview` ditandai @visibleForTesting oleh paketnya, tetapi tidak ada jalan
  // lain: paket itu sendiri tidak menyediakan cara menanyakan ukuran pratinjau
  // yang sedang berjalan, dan justru di situlah letak cacatnya.
  // ignore: invalid_use_of_visible_for_testing_member
  final preview = platform.preview;
  if (preview == null) {
    debugPrint('KAMELSCAN_ROTASI: GAGAL — platform.preview masih null');
    return null;
  }

  try {
    final info = await preview.getResolutionInfo();
    if (info == null) {
      debugPrint('KAMELSCAN_ROTASI: GAGAL — getResolutionInfo() '
          'mengembalikan null');
      return null;
    }
    final size = Size(
      info.resolution.width.toDouble(),
      info.resolution.height.toDouble(),
    );
    debugPrint('KAMELSCAN_ROTASI: terbaca ${size.width.toInt()}'
        'x${size.height.toInt()}');
    return size;
  } on Object catch (e) {
    // Pratinjau yang belum terpasang ke kamera melempar. Itu bukan kegagalan
    // perekaman — layar cukup memakai perilaku bawaannya.
    debugPrint('KAMELSCAN_ROTASI: GAGAL — getResolutionInfo() melempar: $e');
    return null;
  }
}
