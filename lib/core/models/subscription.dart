import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'subscription.freezed.dart';
part 'subscription.g.dart';

/// Tabel `public.subscriptions` (Bab 5.2).
///
/// Fase 1 memakai alur pembayaran **semi-manual** (Bab 12): `payment_method`
/// bernilai `manual_transfer` dan Admin memverifikasi `proof_url`.
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

    /// `midtrans` | `manual_transfer`
    String? paymentMethod,
    String? midtransOrderId,
    String? midtransTxnId,

    /// Bukti transfer manual, diunggah pelanggan.
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

  num get netAmount => (amount - discountAmount).clamp(0, amount);

  bool get isPaid => status == SubStatus.paid;
  bool get isPending => status == SubStatus.pending;
  bool get isManualTransfer => paymentMethod == PaymentMethods.manualTransfer;
  bool get awaitingVerification => isPending && proofUrl != null;
}

class PaymentMethods {
  const PaymentMethods._();
  static const String midtrans = 'midtrans';
  static const String manualTransfer = 'manual_transfer';
}
