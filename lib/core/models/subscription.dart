import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'subscription.freezed.dart';
part 'subscription.g.dart';

/// Satu upaya pembayaran langganan (Bab 12.2). Cerminan tabel
/// `public.subscriptions`.
///
/// Barisnya dibuat **sebelum** uangnya berpindah, berstatus `pending`, dan
/// baru menjadi `paid` setelah Admin memverifikasi buktinya. Karena itu
/// keberadaan baris di sini tidak pernah berarti pelanggan sudah membayar.
@freezed
abstract class Subscription with _$Subscription {
  const factory Subscription({
    required String id,
    required String tenantId,
    required TierPlan plan,
    required num amount,
    @Default(SubStatus.pending) SubStatus status,
    @Default(0) num discountAmount,
    String? promoCode,
    String? paymentMethod,
    String? proofUrl,
    String? verifiedBy,
    DateTime? periodStart,
    DateTime? periodEnd,
    DateTime? paidAt,
    DateTime? createdAt,
  }) = _Subscription;

  const Subscription._();

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);

  bool get isPending => status == SubStatus.pending;
  bool get isPaid => status == SubStatus.paid;

  /// Bukti sudah diunggah, tinggal menunggu Admin.
  ///
  /// Dibedakan dari [isPending] karena dua keadaan ini terasa sangat berbeda
  /// bagi Owner: yang satu "giliran saya", yang lain "giliran mereka". Layar
  /// yang menyamakan keduanya akan menyuruh orang mentransfer ulang uang yang
  /// sudah ia kirim.
  bool get isWaitingVerification => isPending && (proofUrl?.isNotEmpty ?? false);

  /// Batas waktu transfer — 24 jam sejak barisnya dibuat (Bab 12.2 langkah 3).
  ///
  /// Tidak ada kolomnya di database; batas itu memang turunan dari
  /// `created_at`. Menyimpannya sebagai kolom tersendiri hanya menciptakan
  /// kesempatan bagi keduanya untuk berbeda.
  DateTime? get transferDeadline => createdAt?.add(const Duration(hours: 24));

  /// Sisa waktu transfer terhadap [now]; `Duration.zero` bila sudah lewat.
  ///
  /// [now] diminta sebagai parameter, bukan dibaca dari `DateTime.now()` di
  /// dalam, supaya hitungannya dapat diuji tanpa perangkat.
  Duration remainingToTransfer(DateTime now) {
    final batas = transferDeadline;
    if (batas == null) return Duration.zero;
    final sisa = batas.difference(now);
    return sisa.isNegative ? Duration.zero : sisa;
  }

  /// Tagihan ini sudah kedaluwarsa dan tidak layak ditampilkan sebagai
  /// "menunggu pembayaran" lagi.
  bool isStale(DateTime now) =>
      isPending &&
      !isWaitingVerification &&
      remainingToTransfer(now) == Duration.zero;
}
