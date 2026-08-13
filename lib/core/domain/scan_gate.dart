/// Penyaring hasil pemindaian (Bab 8.3).
///
/// Memutuskan kapan sebuah pembacaan **diterima**, kapan diabaikan, dan kapan
/// pembacaan kedua berarti *berhenti merekam*.
///
/// Sengaja **murni Dart tanpa Flutter maupun mobile_scanner**, karena inilah
/// bagian Bab 8.3 yang paling rawan dan paling mahal bila salah:
///
/// > *"Nomor resi yang salah membuat video tidak dapat ditemukan saat
/// > dibutuhkan — dan video bukti yang tidak bisa ditemukan sama nilainya
/// > dengan tidak merekam sama sekali."*
///
/// Menaruh aturan ini di dalam widget kamera berarti hanya bisa diuji dengan
/// memegang label di depan HP, dan itu tidak akan pernah dilakukan berulang.
library;

import '../models/enums.dart';
import '../services/trigger_strategy.dart';

/// Keputusan atas satu pembacaan.
enum ScanDecision {
  /// Diabaikan: format salah, URL, atau bukan nomor resi.
  rejected,

  /// Pembacaan pertama pada mode barcode 1D — menunggu konfirmasi kedua.
  /// Belum boleh berbunyi bip (Bab 8.3.5).
  pendingConfirmation,

  /// Diterima. Perekaman boleh dimulai.
  accepted,

  /// Kode yang sama terbaca lagi selagi merekam — diabaikan (Bab 8.3.2).
  duplicateIgnored,

  /// Kode BERBEDA terbaca selagi merekam — sinyal untuk berhenti.
  stopRequested,
}

/// Hasil lengkap satu pembacaan.
class ScanResult {
  const ScanResult(this.decision, {this.resiCode});

  final ScanDecision decision;

  /// Nomor resi yang sudah dinormalkan; hanya terisi pada [ScanDecision.accepted].
  final String? resiCode;

  bool get shouldBeep => decision == ScanDecision.accepted;
  bool get shouldVibrate => decision == ScanDecision.accepted;

  @override
  String toString() => 'ScanResult(${decision.name}, $resiCode)';
}

/// Penjaga pemindaian untuk satu sesi perekaman.
///
/// Bukan widget dan tidak menyimpan apa pun ke disk — cukup dibuat ulang setiap
/// kali layar rekam dibuka.
class ScanGate {
  ScanGate({
    required this.strategy,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final TriggerStrategy strategy;
  final DateTime Function() _clock;

  /// Kode yang sedang menunggu konfirmasi kedua (mode barcode 1D).
  String? _pending;
  DateTime? _pendingAt;

  /// Kode yang sudah diterima dan sedang dipakai merekam.
  String? _active;

  /// Waktu penerimaan terakhir, untuk debounce.
  DateTime? _lastAcceptedAt;

  String? get activeResi => _active;
  String? get pendingResi => _pending;
  bool get isRecording => _active != null;

  /// Proses satu pembacaan mentah dari pemindai.
  ScanResult read(String rawValue) {
    final resi = strategy.accept(rawValue);
    if (resi == null) return const ScanResult(ScanDecision.rejected);

    final now = _clock();

    // ---------- Sedang merekam ----------
    if (_active != null) {
      if (resi == _active) {
        // Bab 8.3.2: kode yang sama terbaca ulang diabaikan. Tanpa ini,
        // kamera yang masih menghadap label akan langsung menghentikan
        // rekaman yang baru saja dimulai.
        return const ScanResult(ScanDecision.duplicateIgnored);
      }
      if (!strategy.canStopByScan) {
        return const ScanResult(ScanDecision.duplicateIgnored);
      }
      // Debounce tetap berlaku: label sebelah yang terbaca sekejap setelah
      // mulai bukan niat pengguna untuk berhenti.
      final since = _lastAcceptedAt;
      if (since != null && now.difference(since) < strategy.debounce) {
        return const ScanResult(ScanDecision.duplicateIgnored);
      }
      return ScanResult(ScanDecision.stopRequested, resiCode: resi);
    }

    // ---------- Belum merekam ----------
    if (strategy.requiresDoubleRead) {
      // Bab 8.3.3 — terima hanya bila DUA pembacaan berturut-turut identik.
      if (_pending != resi) {
        _pending = resi;
        _pendingAt = now;
        return const ScanResult(ScanDecision.pendingConfirmation);
      }
      // Konfirmasi yang datang terlalu lama setelah pembacaan pertama
      // diperlakukan sebagai pembacaan pertama yang baru — jeda panjang
      // berarti kamera sempat berpindah label.
      final first = _pendingAt;
      if (first != null && now.difference(first) > _confirmationWindow) {
        _pendingAt = now;
        return const ScanResult(ScanDecision.pendingConfirmation);
      }
    }

    _active = resi;
    _pending = null;
    _pendingAt = null;
    _lastAcceptedAt = now;
    return ScanResult(ScanDecision.accepted, resiCode: resi);
  }

  /// Batas waktu konfirmasi pembacaan kedua pada mode barcode 1D.
  ///
  /// Bab 8.3.3 memperkirakan konfirmasi menambah ± 300 ms. Jendela dibuat jauh
  /// lebih longgar agar pembacaan yang tersendat karena cahaya buruk tidak
  /// terus-menerus dianggap pembacaan pertama.
  static const Duration _confirmationWindow = Duration(seconds: 5);

  /// Mode Input Manual: resi diketik, bukan dipindai (Bab 8.3.4).
  ///
  /// Mengembalikan resi ternormalisasi bila sah.
  String? acceptManual(String typed) {
    if (strategy.mode != TriggerMode.manual) return null;
    final resi = strategy.accept(typed);
    if (resi == null) return null;
    _active = resi;
    _lastAcceptedAt = _clock();
    return resi;
  }

  /// Setelah perekaman selesai, siapkan untuk resi berikutnya.
  void reset() {
    _active = null;
    _pending = null;
    _pendingAt = null;
    _lastAcceptedAt = null;
  }
}
