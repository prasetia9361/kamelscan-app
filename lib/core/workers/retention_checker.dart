import '../models/enums.dart';
import '../models/package_video.dart';

/// Penanda video kedaluwarsa di **sisi klien** (Bab 3.2).
///
/// 🔴 Penghapusan sesungguhnya dilakukan cron di server (Bab 5 & Bab 7).
/// Kelas ini tidak menghapus apa pun — ia hanya membantu UI menampilkan status
/// yang jujur di antara dua kali sinkronisasi, sehingga pengguna tidak menekan
/// "Tonton" pada video yang sebenarnya sudah lewat masa retensi.
///
/// Bab 1.3 poin 4: video terhapus otomatis setelah retensi habis. **Ini bukan
/// bug, ini model bisnis** — dan harus tampil jelas di UI.
class RetentionChecker {
  const RetentionChecker();

  /// Ambang peringatan yang ditampilkan di daftar riwayat.
  static const int warnWithinDays = 3;

  bool isExpired(PackageVideo video, {DateTime? now}) =>
      video.isExpired(now: now);

  bool isExpiringSoon(PackageVideo video, {DateTime? now}) {
    if (isExpired(video, now: now)) return false;
    return video.daysUntilExpiry(now: now) <= warnWithinDays;
  }

  /// Video terlama yang masih hidup — dipakai layar penguncian langganan untuk
  /// kalimat "Video Anda akan mulai terhapus dalam N hari" (Bab 7.6).
  int? daysUntilFirstDeletion(
    List<PackageVideo> videos, {
    DateTime? now,
  }) {
    final alive = videos.where((v) => !isExpired(v, now: now));
    if (alive.isEmpty) return null;
    return alive
        .map((v) => v.daysUntilExpiry(now: now))
        .reduce((a, b) => a < b ? a : b);
  }

  /// Tandai ulang status video yang sudah melewati `expires_at` agar UI tidak
  /// menawarkan aksi yang pasti gagal.
  List<PackageVideo> markExpired(List<PackageVideo> videos, {DateTime? now}) =>
      videos
          .map(
            (v) => isExpired(v, now: now) && v.isUploaded
                ? v.copyWith(status: VideoStatus.expired)
                : v,
          )
          .toList();
}
