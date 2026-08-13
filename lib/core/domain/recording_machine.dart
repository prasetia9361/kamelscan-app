/// Mesin status perekaman (Bab 8.1).
///
/// ```
/// IDLE ─(setup lengkap)─► READY ─(resi diterima)─► RECORDING
///   RECORDING ─┬─(resi kedua)──────► STOPPING
///              ├─(batas durasi)────► STOPPING
///              └─(tombol Berhenti)─► STOPPING
///   STOPPING ─► PROCESSING (watermark) ─► QUEUED ─► selesai
/// ```
///
/// Murni Dart: tidak menyentuh kamera, FFmpeg, maupun widget. Alasannya sama
/// dengan [ScanGate] — transisi status adalah tempat bug paling mahal
/// bersembunyi (rekaman yang tidak pernah berhenti, atau berhenti dua kali
/// lalu menyimpan berkas rusak), dan itu tidak akan pernah teruji bila
/// tercampur dengan kode kamera.
library;

import '../config/app_constants.dart';
import '../models/enums.dart';

enum RecordingPhase {
  /// Setup belum lengkap.
  idle,

  /// Kamera, mode pemicu, dan toko sudah dipilih; menunggu resi.
  ready,

  /// Kamera sedang merekam.
  recording,

  /// Perintah berhenti sudah diterima, kamera sedang menutup berkas.
  stopping,

  /// FFmpeg sedang menempelkan watermark.
  processing,

  /// Tersimpan di antrian lokal, menunggu jaringan.
  queued,

  /// Gagal sebelum masuk antrian — berkasnya tidak dapat diselamatkan.
  failed;

  bool get isBusy =>
      this == RecordingPhase.recording ||
      this == RecordingPhase.stopping ||
      this == RecordingPhase.processing;

  /// Hanya pada fase ini tombol Berhenti berguna.
  bool get canStop => this == RecordingPhase.recording;
}

/// Alasan perekaman berhenti — menentukan pesan dan apakah hasilnya disimpan.
enum StopReason {
  /// Resi kedua yang berbeda terbaca (Bab 8.3.2).
  secondScan,

  /// Batas durasi tier tercapai (Bab 7.4).
  durationLimit,

  /// Tombol Berhenti ditekan — satu-satunya cara yang pasti berfungsi
  /// di semua mode (Bab 8.3.1).
  manual,

  /// Kesalahan kamera atau penyimpanan.
  error;

  /// Hanya kegagalan yang membuang hasil rekaman.
  bool get keepsRecording => this != StopReason.error;
}

class RecordingState {
  const RecordingState({
    this.phase = RecordingPhase.idle,
    this.resiCode,
    this.elapsed = Duration.zero,
    this.maxDuration = Duration.zero,
    this.stopReason,
    this.errorKey,
  });

  final RecordingPhase phase;
  final String? resiCode;
  final Duration elapsed;
  final Duration maxDuration;
  final StopReason? stopReason;
  final String? errorKey;

  Duration get remaining {
    final left = maxDuration - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Video sependek ini kemungkinan tidak berguna sebagai bukti.
  ///
  /// ⚠️ Ini **tidak** memblokir tombol Berhenti. Bab 8.3.1 menyebut tombol itu
  /// satu-satunya cara berhenti yang pasti berfungsi — mematikannya akan
  /// menjebak packer yang menyadari salah pindai atau kamera menghadap arah
  /// keliru. Yang dilakukan hanyalah meminta konfirmasi sekali.
  bool get needsShortVideoConfirm =>
      phase == RecordingPhase.recording &&
      elapsed < AppConstants.minRecordingBeforeScanStop;

  /// Bab 8.4 — voice-over mengucapkan "Lima detik lagi" tepat sekali.
  bool get isFinalCountdown =>
      phase == RecordingPhase.recording &&
      remaining.inSeconds <= 5 &&
      remaining > Duration.zero;

  /// Batas durasi tercapai; pemanggil harus memicu berhenti.
  bool get hasReachedLimit =>
      phase == RecordingPhase.recording &&
      maxDuration > Duration.zero &&
      elapsed >= maxDuration;

  RecordingState copyWith({
    RecordingPhase? phase,
    String? resiCode,
    Duration? elapsed,
    Duration? maxDuration,
    StopReason? stopReason,
    String? errorKey,
  }) =>
      RecordingState(
        phase: phase ?? this.phase,
        resiCode: resiCode ?? this.resiCode,
        elapsed: elapsed ?? this.elapsed,
        maxDuration: maxDuration ?? this.maxDuration,
        stopReason: stopReason ?? this.stopReason,
        errorKey: errorKey ?? this.errorKey,
      );

  @override
  String toString() =>
      'RecordingState(${phase.name}, $resiCode, ${elapsed.inSeconds}/'
      '${maxDuration.inSeconds}s)';
}

/// Transisi status. Setiap metode mengembalikan status baru dan **menolak**
/// transisi yang tidak sah alih-alih diam-diam menerimanya.
class RecordingMachine {
  const RecordingMachine._();

  /// Setup lengkap: kamera, mode pemicu, dan toko sudah dipilih (Bab 8.2).
  static RecordingState ready({required Duration maxDuration}) =>
      RecordingState(phase: RecordingPhase.ready, maxDuration: maxDuration);

  /// Resi diterima — kamera mulai merekam.
  ///
  /// Ditolak bila sedang sibuk. Tanpa penjagaan ini, pembacaan beruntun dapat
  /// memulai perekaman kedua di atas yang pertama dan berkasnya saling timpa.
  static RecordingState? start(RecordingState s, String resiCode) {
    if (s.phase != RecordingPhase.ready) return null;
    return s.copyWith(
      phase: RecordingPhase.recording,
      resiCode: resiCode,
      elapsed: Duration.zero,
    );
  }

  /// Perbarui penghitung durasi. Tidak mengubah fase.
  static RecordingState tick(RecordingState s, Duration elapsed) {
    if (s.phase != RecordingPhase.recording) return s;
    return s.copyWith(elapsed: elapsed);
  }

  /// Minta berhenti. Ditolak bila tidak sedang merekam — mencegah berhenti
  /// ganda yang menutup berkas dua kali.
  static RecordingState? stop(RecordingState s, StopReason reason) {
    if (s.phase != RecordingPhase.recording) return null;
    return s.copyWith(phase: RecordingPhase.stopping, stopReason: reason);
  }

  /// Kamera selesai menutup berkas; FFmpeg mulai bekerja.
  static RecordingState? toProcessing(RecordingState s) {
    if (s.phase != RecordingPhase.stopping) return null;
    return s.copyWith(phase: RecordingPhase.processing);
  }

  /// Watermark selesai, berkas masuk antrian lokal.
  static RecordingState? toQueued(RecordingState s) {
    if (s.phase != RecordingPhase.processing) return null;
    return s.copyWith(phase: RecordingPhase.queued);
  }

  /// Gagal di tahap mana pun.
  static RecordingState fail(RecordingState s, String errorKey) =>
      s.copyWith(
        phase: RecordingPhase.failed,
        stopReason: StopReason.error,
        errorKey: errorKey,
      );

  /// Siap untuk resi berikutnya tanpa keluar dari layar.
  static RecordingState next(RecordingState s) =>
      RecordingState(phase: RecordingPhase.ready, maxDuration: s.maxDuration);
}

/// Pilihan di layar setup (Bab 8.2).
///
/// Tombol Mulai aktif hanya bila **ketiganya terisi dan saldo token > 0**.
class RecordingSetup {
  const RecordingSetup({
    this.cameraId,
    this.triggerMode,
    this.shopId,
    this.hasTokens = false,
  });

  final String? cameraId;
  final TriggerMode? triggerMode;
  final String? shopId;
  final bool hasTokens;

  bool get isComplete =>
      cameraId != null && triggerMode != null && shopId != null;

  bool get canStart => isComplete && hasTokens;

  /// Alasan tombol Mulai masih mati, agar layar menjelaskan alih-alih
  /// menampilkan tombol abu-abu tanpa keterangan (Bab 9.10).
  String? get blockedReasonKey {
    if (!hasTokens) return 'errorTokenExhausted';
    if (cameraId == null) return 'setupPickCamera';
    if (triggerMode == null) return 'setupPickTrigger';
    if (shopId == null) return 'setupPickShop';
    return null;
  }

  RecordingSetup copyWith({
    String? cameraId,
    TriggerMode? triggerMode,
    String? shopId,
    bool? hasTokens,
  }) =>
      RecordingSetup(
        cameraId: cameraId ?? this.cameraId,
        triggerMode: triggerMode ?? this.triggerMode,
        shopId: shopId ?? this.shopId,
        hasTokens: hasTokens ?? this.hasTokens,
      );
}
