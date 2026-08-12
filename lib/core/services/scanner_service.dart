import 'dart:async';

import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/enums.dart';
import 'trigger_strategy.dart';

/// Hasil pemindaian yang sudah lolos debounce, normalisasi, dan (bila mode
/// barcode) konfirmasi pembacaan ganda.
class ScanResult {
  const ScanResult({required this.resiCode, required this.mode});

  final String resiCode;
  final TriggerMode mode;
}

/// Pembungkus `mobile_scanner` yang menegakkan aturan Bab 4.3 & Bab 8.3.
///
/// Aturan yang dijaga di sini, bukan di layar:
/// - Hanya format milik mode aktif yang diaktifkan.
/// - Kode yang sama tidak dibaca berulang (debounce + `lastScannedCode`).
/// - Mode barcode 1D menuntut dua pembacaan berturut-turut yang identik.
class ScannerService {
  ScannerService(this.strategy);

  final TriggerStrategy strategy;

  MobileScannerController? _controller;
  final StreamController<ScanResult> _results =
      StreamController<ScanResult>.broadcast();

  String? _lastAcceptedCode;
  DateTime? _lastAcceptedAt;
  String? _pendingConfirmation;

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
  void handleDetection(BarcodeCapture capture, {DateTime? now}) {
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;

    final code = strategy.accept(raw);
    if (code == null) return;

    final at = now ?? DateTime.now();

    // Kode yang sama diabaikan selama jendela debounce (Bab 8.3.2).
    if (_lastAcceptedCode == code &&
        _lastAcceptedAt != null &&
        at.difference(_lastAcceptedAt!) < strategy.debounce) {
      return;
    }

    // Bab 8.3.3 — terima hanya bila dua pembacaan berturut-turut identik.
    if (strategy.requiresDoubleRead && _pendingConfirmation != code) {
      _pendingConfirmation = code;
      return;
    }

    _pendingConfirmation = null;
    _lastAcceptedCode = code;
    _lastAcceptedAt = at;
    _results.add(ScanResult(resiCode: code, mode: strategy.mode));
  }

  /// Bersihkan memori pembacaan — dipanggil saat sesi rekam baru dimulai.
  void resetHistory() {
    _lastAcceptedCode = null;
    _lastAcceptedAt = null;
    _pendingConfirmation = null;
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    await _results.close();
  }
}
