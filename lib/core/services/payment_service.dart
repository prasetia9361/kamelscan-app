import '../models/enums.dart';
import '../utils/result.dart';

/// Integrasi pembayaran.
///
/// 🔵 Bab 0.2 — **integrasi penuh Midtrans (auto-recurring) digeser ke Fase 2**
/// karena verifikasi merchant memakan 5–14 hari kerja di luar kendali tim.
/// Fase 1 memakai alur **semi-manual** (Bab 12): pelanggan transfer, mengunggah
/// bukti, lalu Admin memverifikasi dan menaikkan tier.
///
/// 🔴 `MIDTRANS_SERVER_KEY` **tidak boleh** ada di aplikasi Flutter dalam bentuk
/// apa pun (Bab 4.4). Snap token selalu diterbitkan Edge Function.
abstract interface class PaymentService {
  /// Jalur semi-manual Fase 1: buat tagihan `pending` yang menunggu bukti
  /// transfer.
  Future<Result<String>> createManualOrder({
    required TierPlan plan,
    String? promoCode,
  });

  /// Unggah bukti transfer untuk diverifikasi Admin.
  Future<Result<void>> submitTransferProof({
    required String subscriptionId,
    required String localFilePath,
  });

  /// Jalur Midtrans Snap. Token diterbitkan Edge Function `midtrans-charge`,
  /// bukan dihitung di klien.
  Future<Result<SnapCheckout>> createSnapTransaction({
    required TierPlan plan,
    String? promoCode,
  });
}

class SnapCheckout {
  const SnapCheckout({
    required this.orderId,
    required this.snapToken,
    required this.redirectUrl,
  });

  final String orderId;
  final String snapToken;
  final String redirectUrl;
}
