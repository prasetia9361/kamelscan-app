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

import '../config/app_constants.dart';
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

  /// Resi yang sama dipindai lagi setelah 5 detik — sinyal untuk berhenti.
  stopRequested,

  /// Resi yang sama dipindai, tetapi perekaman belum mencapai 5 detik.
  /// Layar menampilkan sisa detiknya, bukan diam saja.
  stopTooEarly,

  /// Resi **berbeda** dipindai selagi merekam.
  ///
  /// ⚠️ Wajib ditampilkan ke layar. Bila diabaikan diam-diam, packer mengira
  /// ia sedang merekam paket yang baru dipindai, padahal masih merekam paket
  /// sebelumnya — dan videonya akan ber-watermark resi yang salah.
  otherResiIgnored,
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

  /// Sisa detik sebelum pemindaian boleh menghentikan perekaman.
  ///
  /// Dipakai layar untuk menampilkan *"Tunggu 3 detik lagi"* alih-alih diam
  /// saat packer memindai terlalu cepat.
  int get secondsUntilScanStop {
    final since = _lastAcceptedAt;
    if (since == null || _active == null) return 0;
    final left = AppConstants.minRecordingBeforeScanStop -
        _clock().difference(since);
    if (left <= Duration.zero) return 0;
    // Dibulatkan ke ATAS: sisa 4,2 detik ditampilkan "5", bukan "4" — angka
    // yang menghitung mundur ke nol lebih dulu daripada tombolnya aktif akan
    // terlihat seperti aplikasi macet.
    return (left.inMilliseconds / 1000).ceil();
  }

  /// Apakah pemindaian sudah boleh menghentikan perekaman.
  bool get canStopByScan =>
      _active != null && strategy.canStopByScan && secondsUntilScanStop == 0;

  /// Proses satu pembacaan mentah dari pemindai.
  ScanResult read(String rawValue) {
    final resi = strategy.accept(rawValue);
    if (resi == null) return const ScanResult(ScanDecision.rejected);

    final now = _clock();

    // ---------- Sedang merekam ----------
    //
    // Aturan yang berlaku (penyimpangan dari Bab 8.3.2, disetujui Product
    // Owner 13 Agustus 2026 — lihat AppConstants.minRecordingBeforeScanStop):
    // resi yang SAMA menghentikan, resi BERBEDA tidak.
    if (_active != null) {
      if (resi != _active) {
        // Bukan sekadar diabaikan: pemanggil WAJIB menampilkan pesan, agar
        // packer tahu ia masih merekam paket sebelumnya.
        return ScanResult(ScanDecision.otherResiIgnored, resiCode: _active);
      }

      if (!strategy.canStopByScan) {
        // Mode manual: pemindaian tidak pernah menghentikan (Bab 8.3.4).
        return ScanResult(ScanDecision.otherResiIgnored, resiCode: _active);
      }

      final since = _lastAcceptedAt;
      if (since != null &&
          now.difference(since) < AppConstants.minRecordingBeforeScanStop) {
        return ScanResult(ScanDecision.stopTooEarly, resiCode: _active);
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
