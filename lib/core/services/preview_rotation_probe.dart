import 'dart:ui' show Size;

// ⚠️ Bab 4.3 — `camera_android_camerax` menarik `dart:io` lewat
// `camerax_library.g.dart`, sehingga `flutter build web` GAGAL bila paket ini
// diimpor tanpa penjaga. Pemisahan ini bukan kerapian, melainkan syarat build.
// Pola yang sama dipakai `barcode_frame_reader.dart`.
import 'preview_rotation_probe_stub.dart'
    if (dart.library.io) 'preview_rotation_probe_mobile.dart';

/// Ukuran bingkai pratinjau yang **sedang** dikirim kamera saat ini, atau
/// `null` bila tidak dapat dibaca (bukan Android, kamera belum siap).
///
/// 🔴 Kenapa ini perlu dibaca ulang, bukan diambil dari
/// `CameraController.value.previewSize`: nilai di `previewSize` hanya diisi
/// **sekali** waktu kamera dibuka dan tidak pernah diperbarui, padahal CameraX
/// dapat mengganti bingkai pratinjaunya di tengah sesi.
///
/// Terbukti di Redmi Note 9 (14 Agustus 2026) — lihat
/// `CameraService.readPreviewRotationCorrection`.
Future<Size?> readLivePreviewResolution() => readPlatformLivePreviewResolution();
