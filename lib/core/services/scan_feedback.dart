import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// Umpan balik saat resi diterima (Bab 8.3.5).
///
/// Bab 8.3.5 menetapkan tiga hal sekaligus: **getaran, bunyi, dan nomor resi
/// tampil besar**. Yang ketiga milik layar; dua yang pertama ada di sini.
///
/// Dipisahkan menjadi service agar ViewModel tidak menyentuh
/// `package:flutter/services.dart` langsung dan tetap dapat diuji dengan
/// pengganti palsu.
///
/// ⚠️ **Aturan waktunya lebih penting daripada bunyinya.** Bab 8.3.5:
/// pada mode barcode, bunyi hanya dibunyikan **setelah konfirmasi pembacaan
/// kedua** — bukan pada pembacaan pertama. Aturan itu ditegakkan [ScanGate],
/// yang baru mengembalikan `accepted` setelah dua pembacaan identik; kelas ini
/// cukup dipanggil pada `accepted` saja.
class ScanFeedback {
  const ScanFeedback();

  static const AppLogger _log = AppLogger('ScanFeedback');

  /// Resi diterima — perekaman akan dimulai.
  ///
  /// 📌 **Belum bunyi bip sungguhan.** Proyek ini belum memuat paket pemutar
  /// suara, dan `SystemSound` bawaan Flutter hanya mendukung bunyi *klik* di
  /// Android — `SystemSoundType.alert` diabaikan di seluruh platform mobile.
  /// Bip sesuai Bab 8.3.5 memerlukan satu paket pemutar audio beserta berkas
  /// WAV-nya; penambahan itu menunggu keputusan Product Owner karena penyangga
  /// jadwal Bab 0.2 sudah minus.
  Future<void> accepted() async {
    try {
      await HapticFeedback.mediumImpact();
      await SystemSound.play(SystemSoundType.click);
    } on Object catch (e) {
      // Umpan balik adalah kenyamanan, bukan syarat. Perangkat yang bisu atau
      // tanpa motor getar tidak boleh menghentikan perekaman.
      _log.w('Umpan balik gagal', e);
    }
  }

  /// Perekaman berhenti.
  Future<void> stopped() async {
    try {
      await HapticFeedback.heavyImpact();
    } on Object catch (e) {
      _log.w('Umpan balik gagal', e);
    }
  }

  /// Pembacaan ditolak atau diabaikan — getaran ringan saja, tanpa bunyi,
  /// agar tidak tertukar dengan penerimaan resi.
  Future<void> rejected() async {
    try {
      await HapticFeedback.selectionClick();
    } on Object catch (e) {
      _log.w('Umpan balik gagal', e);
    }
  }
}
