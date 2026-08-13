import 'dart:async';

import 'package:mobile_scanner/mobile_scanner.dart';

import '../domain/scan_gate.dart';
import '../models/enums.dart';
import 'trigger_strategy.dart';

/// Pembungkus `mobile_scanner` (Bab 4.3 & Bab 8.3).
///
/// ⚠️ **Seluruh aturan keputusan ada di [ScanGate], bukan di sini.**
///
/// Berkas ini semula menyimpan salinan kedua dari aturan debounce, konfirmasi
/// pembacaan ganda, dan penghentian — versi yang tidak pernah diuji karena
/// mengimpor `mobile_scanner`. Setelah aturan berhenti diubah pada
/// 13 Agustus 2026, kedua salinan itu langsung menyimpang: yang teruji
/// memakai aturan baru, yang di sini masih memakai aturan lama.
///
/// Dua implementasi dari aturan yang sama adalah sumber bug yang pasti
/// terjadi, hanya soal waktu. Kini tinggal satu, dan yang teruji.
class ScannerService {
  ScannerService(this.strategy) : gate = ScanGate(strategy: strategy);

  final TriggerStrategy strategy;

  /// Penjaga keputusan. Terbuka agar layar dapat membaca
  /// [ScanGate.secondsUntilScanStop] untuk hitung mundur.
  final ScanGate gate;

  MobileScannerController? _controller;
  final StreamController<ScanResult> _results =
      StreamController<ScanResult>.broadcast();

  /// Setiap pembacaan diteruskan, **termasuk yang ditolak** — layar perlu tahu
  /// bedanya agar dapat menampilkan "Masih merekam X" atau "Tunggu 3 detik".
  /// Menyaringnya di sini membuat layar kehilangan alasan.
  Stream<ScanResult> get onScan => _results.stream;

  MobileScannerController get controller =>
      _controller ??= MobileScannerController(
        formats: strategy.formats,
        detectionSpeed: DetectionSpeed.normal,
        autoStart: false,
      );

  bool get isTorchAvailable => strategy.needsTorchButton;

  Future<void> start() async {
    if (strategy.mode == TriggerMode.manual) return;
    await controller.start();
  }

  Future<void> stop() async {
    if (_controller == null) return;
    await _controller!.stop();
  }

  Future<void> toggleTorch() => controller.toggleTorch();

  Future<void> switchCamera() => controller.switchCamera();

  /// Dipanggil dari `onDetect` milik `MobileScanner`.
  void handleDetection(BarcodeCapture capture) {
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;

    final result = gate.read(raw);
    // Pembacaan yang formatnya jelas bukan resi tidak perlu mengganggu layar.
    if (result.decision == ScanDecision.rejected) return;

    _results.add(result);
  }

  /// Resi diketik pada mode Input Manual (Bab 8.3.4).
  String? acceptManual(String typed) => gate.acceptManual(typed);

  /// Siapkan untuk resi berikutnya tanpa keluar dari layar.
  void resetHistory() => gate.reset();

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    await _results.close();
  }
}
