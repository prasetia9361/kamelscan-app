import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../config/app_constants.dart';
import '../utils/app_failure.dart';
import '../utils/logger.dart';
import '../utils/result.dart';
import 'preview_rotation_probe.dart';

/// Kontrol `CameraController` untuk sesi rekam.
///
/// Rincian pipeline perekaman ada di **Bab 8**. Yang sudah dikunci sejak
/// Bab 0–4 dan ditegakkan di sini:
///
/// - Resolusi 480p (Bab 1.3 poin 3) — biaya storage adalah model bisnisnya.
/// - Batas durasi ditegakkan timer **dan** constraint database (Bab 7.4);
///   kelas ini memegang sisi timer-nya.
///
/// 🔴 **Dua jalur frame, bukan satu.** Layar rekam harus memindai sebelum
/// perekaman dimulai (untuk menangkap resi pertama) dan selama perekaman
/// berjalan (agar resi yang sama dapat menghentikannya). `startImageStream`
/// **melempar** bila perekaman sudah berjalan, jadi selama merekam frame hanya
/// bisa diambil lewat `startVideoRecording(onAvailable:)`.
///
/// Perpindahan antara kedua jalur itu terverifikasi di Redmi Note 9
/// (14 Agustus 2026) pada 480p — CameraX menerimanya, dan ML Kit tetap
/// membaca isi kode di kedua jalur.
/// Bentuk pratinjau yang **sedang** berjalan, beserta koreksi yang harus
/// diterapkan layar.
///
/// Keduanya harus dibawa bersama: koreksi memperbaiki **putaran**, [liveSize]
/// memperbaiki **bentuk kotaknya**. Dulu hanya koreksi yang dikembalikan, dan
/// akibatnya pratinjau tegak tetapi melar 2,25 kali selama merekam.
class PreviewGeometry {
  const PreviewGeometry({this.quarterTurnCorrection = 0, this.liveSize});

  /// `0` atau `-1` — seperempat putaran yang harus dibatalkan layar.
  final int quarterTurnCorrection;

  /// Ukuran bingkai yang sedang dikirim kamera; `null` bila tidak terbaca.
  final Size? liveSize;

  static const PreviewGeometry unknown = PreviewGeometry();
}

class CameraService {
  CameraService();

  static const AppLogger _log = AppLogger('CameraService');

  CameraController? _controller;
  List<CameraDescription> _cameras = const [];

  CameraController? get controller => _controller;
  CameraDescription? get description => _controller?.description;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isRecording => _controller?.value.isRecordingVideo ?? false;
  bool get isStreamingImages => _controller?.value.isStreamingImages ?? false;
  List<CameraDescription> get availableCameraList => _cameras;

  /// Orientasi sensor lensa aktif — dibutuhkan ML Kit untuk memutar bingkai.
  int get sensorOrientation => _controller?.description.sensorOrientation ?? 0;

  /// [cameraName] adalah `CameraDescription.name` yang dipilih di layar setup
  /// (Bab 8.2). Bila tidak ditemukan, jatuh ke [preferred], lalu ke lensa
  /// pertama — pilihan tersimpan yang tidak ada lagi tidak boleh membuat
  /// perekaman gagal total.
  ///
  /// [enableAudio] `false` bila izin mikrofon ditolak. Bab 8.9: video bisu jauh
  /// lebih baik daripada tidak ada bukti sama sekali.
  Future<Result<void>> init({
    String? cameraName,
    CameraLensDirection? preferred,
    bool enableAudio = true,
  }) async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        return Result.err(
          AppFailure.devicePermission('permissionCameraDenied'),
        );
      }

      final camera = _pick(cameraName, preferred);

      final controller = CameraController(
        camera,
        // 480p — dikunci Bab 1.3 poin 3.
        ResolutionPreset.medium,
        enableAudio: enableAudio,
        // 🔴 Wajib nv21: bentuk inilah yang dibungkus `InputImage.fromBytes`
        // sebagai satu bidang. Tanpa penyetelan ini Android memberi
        // `yuv420_888` tiga bidang, dan ML Kit membaca bidang pertamanya saja —
        // hasilnya pemindaian yang tidak pernah menemukan apa pun tanpa satu
        // pun pesan error.
        imageFormatGroup: ImageFormatGroup.nv21,
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

  CameraDescription _pick(String? name, CameraLensDirection? preferred) {
    if (name != null) {
      for (final c in _cameras) {
        if (c.name == name) return c;
      }
      _log.w('Kamera "$name" tidak ada lagi — memakai lensa lain');
    }
    return _cameras.firstWhere(
      (c) => preferred == null || c.lensDirection == preferred,
      orElse: () => _cameras.first,
    );
  }

  /// Aliran frame **sebelum** perekaman dimulai.
  Future<Result<void>> startImageStream(
    void Function(CameraImage image) onFrame,
  ) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return Result.err(AppFailure.devicePermission('permissionCameraDenied'));
    }
    if (c.value.isStreamingImages) return okVoid;
    try {
      await c.startImageStream(onFrame);
      return okVoid;
    } on CameraException catch (e) {
      return Result.err(_mapCameraException(e));
    }
  }

  Future<void> stopImageStream() async {
    final c = _controller;
    if (c == null || !c.value.isStreamingImages || c.value.isRecordingVideo) {
      return;
    }
    try {
      await c.stopImageStream();
    } on CameraException catch (e) {
      _log.w('stopImageStream gagal', e);
    }
  }

  /// Mulai merekam. [onFrame] tetap menerima bingkai **selama** perekaman —
  /// syarat mutlak aturan berhenti Product Owner.
  ///
  /// Aliran pra-rekam dihentikan lebih dulu di sini, karena
  /// `startVideoRecording` akan menolak bila `startImageStream` masih aktif.
  Future<Result<void>> startRecording({
    void Function(CameraImage image)? onFrame,
  }) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return Result.err(AppFailure.devicePermission('permissionCameraDenied'));
    }
    if (c.value.isRecordingVideo) {
      return Result.err(AppFailure.unknown('Perekaman sudah berjalan'));
    }
    try {
      await stopImageStream();
      await c.startVideoRecording(onAvailable: onFrame);
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

  /// Berapa seperempat putaran yang harus **dibatalkan** layar dari pratinjau.
  /// `0` berarti tidak ada yang perlu dikoreksi, `-1` berarti gambarnya harus
  /// diputar balik seperempat putaran berlawanan arah jarum jam.
  ///
  /// 🔴 **Kenapa ini ada.** Selama merekam, kamera dipakai tiga hal sekaligus:
  /// pratinjau, pemindai frame, dan perekam video. Tiga aliran gambar terpisah
  /// hanya dijamin pada perangkat tingkat `LEVEL_3`. Redmi Note 9 hanya `FULL`,
  /// jadi CameraX menyalakan **StreamSharing**: pratinjau dan perekam digabung
  /// jadi satu aliran lalu dipisah lagi lewat pemroses OpenGL.
  ///
  /// Pemroses itu **memutar sendiri gambarnya 90° ke dalam piksel**, lalu
  /// melapor `rotationDegrees=0` — "sudah beres". Sialnya `camera_android_camerax`
  /// menetapkan sekali di awal siapa yang bertugas memutar dan tidak pernah
  /// menengok lagi, sehingga Flutter tetap memutar 90° seperti semula. Dua
  /// putaran menumpuk dan pratinjau miring seperempat putaran selama merekam.
  ///
  /// **Terbukti di Redmi Note 9 (14 Agustus 2026)** lewat logcat:
  ///
  /// ```
  /// sebelum : Preview resolution=720x480
  /// merekam : SurfaceProcessorNode [StreamSharing]
  ///           outputEdge rotationDegrees=0, rotationInTransform=90
  ///           Preview resolution=480x720 (originalConfigured=720x480)
  /// berhenti: Preview resolution=720x480
  /// ```
  ///
  /// ⚠️ **Jangan menggantinya dengan "kalau sedang merekam, putar balik".**
  /// StreamSharing tidak selalu menyala — perangkat `LEVEL_3` sanggup tiga
  /// aliran sekaligus dan tidak memutar apa pun. Koreksi buta akan membuat
  /// pratinjau di perangkat itu justru miring. Karena itu yang diperiksa adalah
  /// **bentuk bingkainya**: bila berubah dari mendatar jadi tegak (atau
  /// sebaliknya) dibanding saat kamera dibuka, berarti CameraX sudah memutar
  /// sendiri.
  Future<PreviewGeometry> readPreviewGeometry() async {
    final baseline = _controller?.value.previewSize;
    if (baseline == null) return PreviewGeometry.unknown;

    final live = await readLivePreviewResolution();
    if (live == null) return PreviewGeometry.unknown;

    final flipped = _isWide(baseline) != _isWide(live);
    final correction = flipped ? -1 : 0;
    // Sengaja `debugPrint`, bukan hanya `AppLogger` — lihat catatan di
    // `preview_rotation_probe_mobile.dart`.
    debugPrint('KAMELSCAN_ROTASI: awal=${_fmt(baseline)} '
        'sekarang=${_fmt(live)} koreksi=$correction merekam=$isRecording');
    return PreviewGeometry(
      quarterTurnCorrection: correction,
      liveSize: live,
    );
  }

  static bool _isWide(Size size) => size.width >= size.height;

  static String _fmt(Size size) =>
      '${size.width.toInt()}x${size.height.toInt()}';

  /// Senter (Bab 8.3.3 — wajib pada mode barcode; gudang sering remang).
  ///
  /// Terverifikasi menyala **selagi merekam** di Redmi Note 9.
  Future<Result<void>> setTorch(bool on) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return Result.err(AppFailure.devicePermission('permissionCameraDenied'));
    }
    try {
      await c.setFlashMode(on ? FlashMode.torch : FlashMode.off);
      return okVoid;
    } on CameraException catch (e) {
      // Sebagian lensa depan tidak punya senter. Itu bukan kegagalan
      // perekaman — tombolnya saja yang tidak berguna.
      _log.w('Senter tidak dapat diubah', e);
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
    final c = _controller;
    _controller = null;
    if (c == null) return;
    try {
      // Membuang controller selagi merekam meninggalkan berkas yang tidak
      // pernah ditutup dengan benar.
      if (c.value.isRecordingVideo) await c.stopVideoRecording();
    } on Object catch (e) {
      _log.w('Menutup rekaman saat dispose gagal', e);
    }
    await c.dispose();
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
