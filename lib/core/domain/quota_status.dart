/// Aturan kuota token dan masa langganan (Bab 7).
///
/// Sengaja **murni Dart tanpa Flutter** agar seluruh ambang batas dapat diuji
/// tanpa perangkat maupun widget. Bab 7.3 dan 7.6 penuh dengan angka yang
/// mudah salah ketik; menaruhnya di widget berarti tidak akan pernah teruji.
///
/// ⚠️ Kelas ini **tidak menegakkan** apa pun. Penegakan sesungguhnya ada di
/// trigger `before_video_insert` (Bab 7.3 & 7.4). Yang ada di sini hanya
/// keputusan tampilan: kapan memberi warna, kapan memasang spanduk, kapan
/// mengabukan tombol.
library;

import '../config/app_constants.dart';
import '../models/enums.dart';

/// Tingkat kegentingan sisa kuota (Bab 7.3).
enum QuotaLevel {
  /// Sisa > 20% — indikator warna normal.
  normal,

  /// Sisa ≤ 20% — indikator kuning + spanduk di Beranda.
  warning,

  /// Sisa ≤ 5% — indikator merah + dialog peringatan saat membuka perekaman.
  critical,

  /// Sisa 0 — menu perekaman dinonaktifkan.
  exhausted;

  bool get needsHomeBanner => this == warning || this == critical;
  bool get needsRecordingDialog => this == critical;
  bool get blocksRecording => this == exhausted;
}

/// Keadaan dompet token pada satu titik waktu.
class QuotaStatus {
  const QuotaStatus({
    required this.balance,
    required this.quota,
    required this.isTrial,
  });

  /// Sisa token. Tidak pernah negatif — `greatest(balance - 1, 0)` di trigger
  /// menjaga itu (Bab 7.3).
  final int balance;

  /// Kuota penuh satu periode. Saat uji coba berisi 100 (Bab 7.5).
  final int quota;

  final bool isTrial;

  /// Sisa dibanding kuota, 0..1. Kuota 0 dianggap habis, bukan dibagi nol.
  double get ratio {
    if (quota <= 0) return 0;
    final r = balance / quota;
    return r < 0 ? 0 : (r > 1 ? 1 : r);
  }

  int get used => (quota - balance).clamp(0, quota);

  QuotaLevel get level {
    if (balance <= 0) return QuotaLevel.exhausted;
    if (ratio <= AppConstants.tokenCriticalRatio) return QuotaLevel.critical;
    if (ratio <= AppConstants.tokenWarningRatio) return QuotaLevel.warning;
    return QuotaLevel.normal;
  }

  bool get isExhausted => level == QuotaLevel.exhausted;

  /// Kunci l10n untuk spanduk Beranda, atau null bila belum perlu.
  ///
  /// Bab 7.5 membedakan pesannya: pengguna uji coba diajak berlangganan,
  /// pelanggan berbayar diajak menaikkan paket.
  String? get bannerKey => switch (level) {
        QuotaLevel.normal => null,
        QuotaLevel.exhausted =>
          isTrial ? 'trialExhaustedBanner' : 'quotaExhaustedBanner',
        _ => isTrial ? 'trialLowBanner' : 'quotaLowBanner',
      };

  @override
  String toString() =>
      'QuotaStatus($balance/$quota, ${level.name}${isTrial ? ', trial' : ''})';
}

/// Keadaan masa langganan (Bab 7.6).
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.tenantStatus,
    required this.periodEnd,
    required this.isTrial,
    DateTime? now,
  }) : _now = now;

  final TenantStatus tenantStatus;

  /// Akhir periode. **null saat uji coba** — Bab 7.5 menegaskan batas uji coba
  /// adalah jumlah video, bukan waktu.
  final DateTime? periodEnd;

  final bool isTrial;
  final DateTime? _now;

  DateTime get _clock => _now ?? DateTime.now();

  /// Sisa hari sampai langganan berakhir. null bila tidak berbatas waktu.
  ///
  /// Dihitung dari batas hari, bukan selisih jam: langganan yang berakhir
  /// 3 jam lagi tetap "hari ini", bukan "0,125 hari".
  int? get daysRemaining {
    final end = periodEnd;
    if (end == null || isTrial) return null;
    final today = DateTime(_clock.year, _clock.month, _clock.day);
    final last = DateTime(end.year, end.month, end.day);
    return last.difference(today).inDays;
  }

  bool get isExpired => tenantStatus == TenantStatus.expired;
  bool get isSuspended => tenantStatus == TenantStatus.suspended;
  bool get isActive => tenantStatus.canRecord;

  /// Bab 7.6 — peringatan wajib pada H-7, H-3, dan H-1.
  ///
  /// ⚠️ Dokumen menyebut tiga hari itu secara khusus, tetapi menampilkan
  /// peringatan HANYA pada tiga angka persis akan melewatkan pengguna yang
  /// tidak membuka aplikasi pada hari-hari tersebut. Karena itu peringatan
  /// muncul pada H-7 ke bawah; [warningDay] tetap melaporkan ambang terdekat
  /// agar kalimatnya sesuai.
  bool get shouldWarnExpiry {
    final d = daysRemaining;
    if (d == null || !isActive) return false;
    return d <= AppConstants.subscriptionWarningDays.first && d >= 0;
  }

  /// Ambang peringatan terketat yang sudah terlewati: 7, 3, atau 1.
  ///
  /// Contoh: sisa 6 hari → 7 (baru lewat H-7); sisa 3 hari → 3; sisa 0 hari → 1.
  /// Mengembalikan null bila masih lebih dari 7 hari.
  int? get warningDay {
    final d = daysRemaining;
    if (d == null || !isActive) return null;
    final crossed =
        AppConstants.subscriptionWarningDays.where((t) => d <= t).toList();
    if (crossed.isEmpty) return null;
    return crossed.reduce((a, b) => a < b ? a : b);
  }

  @override
  String toString() =>
      'SubscriptionStatus(${tenantStatus.name}, sisa=${daysRemaining ?? '-'} hari)';
}
