import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/queue_summary.dart';
import 'repository_providers.dart';

part 'upload_queue_provider.g.dart';

/// Jumlah video yang masih menunggu giliran unggah (Bab 8.6).
///
/// Dipakai dua tempat: lencana antrian di Beranda, dan peringatan saat keluar
/// (Bab 8.7 — *"Ada 4 video belum terunggah. Tetap keluar?"*).
///
/// ⚠️ Hitungan ini mencakup **seluruh** baris antrian di perangkat, bukan hanya
/// milik pengguna yang sedang masuk. Antrian memang sengaja tidak dihapus saat
/// keluar (Bab 8.7), sehingga sisa milik pengguna sebelumnya ikut terhitung.
/// Untuk peringatan saat keluar sifat ini justru aman: lebih baik memperingati
/// terlalu sering daripada membiarkan bukti pelanggan hilang tanpa kabar.
///
/// Web tidak punya antrian lokal (Bab 4.3), jadi nilainya selalu 0 di sana.
@Riverpod(keepAlive: true)
Stream<int> pendingUploadCount(Ref ref) {
  final db = ref.watch(localDbServiceProvider);
  if (!db.isSupported) return Stream.value(0);
  return db.watchPendingCount();
}

/// Antrian dipecah menurut **apa yang menahannya** (Bab 8.7).
///
/// 🔴 Dipakai spanduk Beranda supaya kalimatnya menyebutkan sebab yang
/// sebenarnya. Sampai 3 September 2026 spanduk itu hanya tahu satu angka dan
/// kalimatnya ditulis mati *"menunggu Wi-Fi"* — diucapkan bahkan ketika yang
/// menahan adalah watermark yang gagal. Uraiannya di [QueueSummary].
@Riverpod(keepAlive: true)
Stream<QueueSummary> queueSummary(Ref ref) {
  final db = ref.watch(localDbServiceProvider);
  if (!db.isSupported) {
    return Stream<QueueSummary>.value(const QueueSummary());
  }
  return db.watchQueueSummary();
}
