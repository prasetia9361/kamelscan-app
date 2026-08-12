import 'package:mobile_scanner/mobile_scanner.dart';

import '../config/app_constants.dart';
import '../models/enums.dart';
import '../utils/validators.dart';

/// Abstraksi tiga mode pemicu perekaman (Bab 0.3 / Bab 8.3).
///
/// Layar rekam berbicara ke antarmuka ini, bukan ke `mobile_scanner` langsung.
/// Dengan begitu menambah mode keempat kelak (mis. scanner Bluetooth di Fase 2)
/// tidak menyentuh kode kamera.
sealed class TriggerStrategy {
  const TriggerStrategy();

  TriggerMode get mode;

  /// Format barcode yang diaktifkan.
  ///
  /// ⚠️ Bab 4.3 — **jangan mengaktifkan semua format sekaligus.** Setiap format
  /// tambahan memperlambat pemindaian dan menaikkan peluang salah baca.
  List<BarcodeFormat> get formats;

  /// Bab 8.3.3 — barcode 1D wajib dibaca dua kali dengan hasil identik sebelum
  /// diterima. Nomor resi yang salah membuat video tidak dapat ditemukan saat
  /// dibutuhkan, dan bukti yang tidak bisa ditemukan sama nilainya dengan tidak
  /// merekam sama sekali.
  bool get requiresDoubleRead;

  /// Bingkai bantu mendatar untuk barcode 1D, kotak untuk QR.
  bool get usesWideFrame;

  /// Mode barcode dipakai di gudang remang — senter wajib tersedia.
  bool get needsTorchButton;

  /// Apakah pemindaian kedua dapat menghentikan perekaman. Mode manual tidak
  /// memindai apa pun, sehingga hanya tombol Berhenti dan batas durasi yang
  /// berlaku (Bab 8.3.4).
  bool get canStopByScan;

  /// Jeda sebelum kode yang sama boleh diterima lagi.
  Duration get debounce => AppConstants.scanDebounce;

  /// Terima isi kode mentah, kembalikan nomor resi yang sudah dinormalkan,
  /// atau `null` bila isinya bukan nomor resi yang sah (Bab 8.3.1).
  String? accept(String rawValue) {
    if (Validators.isLikelyUrl(rawValue)) return null;
    final normalized = Validators.normalizeResi(rawValue);
    return Validators.resiCode(normalized) == null ? normalized : null;
  }

  static TriggerStrategy of(TriggerMode mode) => switch (mode) {
        TriggerMode.qrCode => const QrTriggerStrategy(),
        TriggerMode.barcode1d => const Barcode1dTriggerStrategy(),
        TriggerMode.manual => const ManualTriggerStrategy(),
      };
}

/// Mode QR — paling andal, dipakai Shopee, TikTok Shop, dan label modern.
class QrTriggerStrategy extends TriggerStrategy {
  const QrTriggerStrategy();

  @override
  TriggerMode get mode => TriggerMode.qrCode;

  @override
  List<BarcodeFormat> get formats => const [BarcodeFormat.qrCode];

  @override
  bool get requiresDoubleRead => false;

  @override
  bool get usesWideFrame => false;

  @override
  bool get needsTorchButton => false;

  @override
  bool get canStopByScan => true;
}

/// Mode Barcode 1D — keandalan menengah, bergantung kualitas cetak & cahaya.
class Barcode1dTriggerStrategy extends TriggerStrategy {
  const Barcode1dTriggerStrategy();

  @override
  TriggerMode get mode => TriggerMode.barcode1d;

  /// Daftar persis dari Bab 8.3.3 — tidak lebih.
  @override
  List<BarcodeFormat> get formats => const [
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        // Bab 8.3.3 menulis `itf`; nama itu sudah deprecated di
        // mobile_scanner 7 dan digantikan `itf14` dengan nilai yang sama.
        BarcodeFormat.itf14,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
      ];

  @override
  bool get requiresDoubleRead => true;

  @override
  bool get usesWideFrame => true;

  @override
  bool get needsTorchButton => true;

  @override
  bool get canStopByScan => true;
}

/// Mode Input Manual — selalu berhasil, paling lambat, paling rawan salah ketik.
class ManualTriggerStrategy extends TriggerStrategy {
  const ManualTriggerStrategy();

  @override
  TriggerMode get mode => TriggerMode.manual;

  @override
  List<BarcodeFormat> get formats => const [];

  @override
  bool get requiresDoubleRead => false;

  @override
  bool get usesWideFrame => false;

  @override
  bool get needsTorchButton => false;

  @override
  bool get canStopByScan => false;

  /// Pengecekan resi ganda berjalan saat pengguna berhenti mengetik (Bab 7.7).
  Duration get typingDebounce => AppConstants.manualResiCheckDebounce;
}
