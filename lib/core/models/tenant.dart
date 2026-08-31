import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'tenant.freezed.dart';
part 'tenant.g.dart';

/// Satu baris = satu pelanggan (Owner). Cerminan tabel `public.tenants`.
///
/// `tenant_id` adalah sumbu isolasi data seluruh aplikasi (Bab 5.1 poin 1) —
/// bukan `shop_id`.
@freezed
abstract class Tenant with _$Tenant {
  const factory Tenant({
    required String id,
    required String ownerId,
    @Default(TierPlan.standar) TierPlan tierPlan,
    @Default(TenantStatus.trial) TenantStatus status,
    @Default(true) bool trialUsed,
    String? businessName,
    String? legalName,
    String? taxId,
    DateTime? periodStart,

    /// NULL selama masa uji coba — trial dibatasi jumlah video, bukan waktu
    /// (Bab 7.5).
    DateTime? periodEnd,
    /// Terisi begitu Owner meminta akunnya dihapus (Bab 9.6, migrasi 37).
    ///
    /// 🔴 Selama kolom ini terisi, akunnya **tidak boleh dipakai sama sekali**
    /// — bukan sekadar tidak boleh merekam. Itulah yang dijanjikan kalimat
    /// "akun langsung tidak dapat digunakan" pada layar konfirmasinya, dan
    /// janji itu yang dibaca pelanggan sebelum mengetikkan nama usahanya.
    DateTime? deletionRequestedAt,

    /// Kapan datanya benar-benar dimusnahkan. Sebelum tanggal ini Owner masih
    /// dapat membatalkan; sesudahnya tidak ada lagi yang dapat dikembalikan.
    DateTime? deletionPurgeAfter,

    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Tenant;

  const Tenant._();

  factory Tenant.fromJson(Map<String, dynamic> json) => _$TenantFromJson(json);

  /// Akun ini sedang menunggu dimusnahkan.
  ///
  /// Dipakai penjaga rute untuk mengunci seluruh aplikasi, jadi ia sengaja
  /// hanya menyimak [deletionRequestedAt] dan **tidak** membandingkan
  /// [deletionPurgeAfter] dengan waktu sekarang: tenant yang tenggangnya sudah
  /// lewat tetapi cron-nya belum berjalan justru yang paling tidak boleh
  /// dibiarkan masuk.
  bool get isDeletionPending => deletionRequestedAt != null;

  /// Sisa hari sebelum data dimusnahkan, dibulatkan ke atas.
  ///
  /// `inDays` memotong ke bawah, sehingga sisa 6 jam terbaca "0 hari" — angka
  /// yang membuat pelanggan menyangka kesempatannya sudah habis padahal masih
  /// ada. Untuk hitung mundur, membulatkan ke atas yang jujur.
  int? daysUntilPurge({DateTime? now}) {
    final akhir = deletionPurgeAfter;
    if (akhir == null) return null;
    final sisa = akhir.difference(now ?? DateTime.now());
    if (sisa.isNegative) return 0;
    return (sisa.inSeconds / Duration.secondsPerDay).ceil();
  }

  bool get isTrial => status == TenantStatus.trial;
  bool get isPro => tierPlan == TierPlan.pro;

  /// Bab 7.6 — `expired` dan `suspended` mengunci perekaman seketika.
  bool get canRecord => status.canRecord;

  /// Bab 7.6 — riwayat & pemutaran ikut terkunci saat langganan berakhir.
  bool get canPlayVideo => status.canRecord;

  /// Sisa hari langganan. `null` saat trial (tidak ada batas waktu).
  int? daysUntilExpiry({DateTime? now}) {
    final end = periodEnd;
    if (end == null) return null;
    return end.difference(now ?? DateTime.now()).inDays;
  }

  /// Bab 7.6 — banner peringatan muncul pada H-7, H-3, dan H-1.
  bool shouldWarnExpiry({DateTime? now, List<int> thresholds = const [7, 3, 1]}) {
    final days = daysUntilExpiry(now: now);
    if (days == null || days < 0) return false;
    return thresholds.contains(days);
  }
}
