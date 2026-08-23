import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'promo.freezed.dart';
part 'promo.g.dart';

/// Kode promo (Bab 9.8). Cerminan tabel `public.promos`.
///
/// ⚠️ Perhitungan di sini **bukan** penentu akhir. Nilai yang benar-benar
/// ditagihkan ditetapkan saat Admin memverifikasi pembayaran; yang di sini
/// hanya agar Owner melihat angkanya sebelum menekan Bayar. Dua tempat
/// menghitung hal yang sama memang berisiko berbeda — karena itu aturannya
/// ditulis sekali di sini dan diuji tanpa perangkat, bukan disebar ke widget.
@freezed
abstract class Promo with _$Promo {
  const factory Promo({
    required String code,
    required String discountType,
    required num discountValue,
    required DateTime validUntil,
    String? description,

    /// null = berlaku untuk semua paket.
    TierPlan? appliesTo,
    DateTime? validFrom,
    int? maxUses,
    @Default(0) int usedCount,
    @Default(true) bool isActive,
  }) = _Promo;

  const Promo._();

  factory Promo.fromJson(Map<String, dynamic> json) => _$PromoFromJson(json);

  bool get isPercent => discountType == 'percent';

  /// Kuota pemakaian sudah habis. `maxUses` null berarti tanpa batas.
  bool get isUsedUp => maxUses != null && usedCount >= maxUses!;

  /// Alasan kode ini tidak dapat dipakai, atau null bila sah.
  ///
  /// Mengembalikan **kunci l10n**, bukan kalimat — mengikuti aturan Bab 9.11
  /// poin 5. Dipisah dari [discountFor] supaya layar dapat menjelaskan
  /// *mengapa* sebuah kode ditolak; "kode tidak berlaku" tanpa alasan membuat
  /// Owner mencoba kode yang sama berulang kali.
  String? rejectionKey(TierPlan plan, DateTime now) {
    if (!isActive) return 'promoInactive';
    if (validFrom != null && now.isBefore(validFrom!)) return 'promoNotStarted';
    if (now.isAfter(validUntil)) return 'promoExpired';
    if (isUsedUp) return 'promoUsedUp';
    if (appliesTo != null && appliesTo != plan) return 'promoWrongPlan';
    return null;
  }

  /// Potongan dalam rupiah untuk [price].
  ///
  /// Selalu dibulatkan ke bawah dan tidak pernah melebihi harganya sendiri —
  /// promo `fixed` yang nilainya lebih besar daripada harga paket akan
  /// menghasilkan tagihan negatif bila tidak dijepit di sini.
  num discountFor(num price) {
    final mentah = isPercent ? price * discountValue / 100 : discountValue;
    return mentah.clamp(0, price).floor();
  }
}
