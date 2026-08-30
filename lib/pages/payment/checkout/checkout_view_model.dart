import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/payment_methods.dart';
import '../../../core/models/subscription.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/utils/app_failure.dart';

part 'checkout_view_model.g.dart';

/// Isi halaman instruksi transfer (Bab 12.2 langkah 3–5).
class CheckoutData {
  const CheckoutData({required this.accounts, this.bill, this.whatsapp});

  /// Tagihan yang sedang berjalan. Null bila tidak ada satu pun yang menunggu
  /// diselesaikan — misalnya Owner membuka tautan ini langsung, atau tagihannya
  /// baru saja diverifikasi Admin.
  final Subscription? bill;

  final List<BankAccount> accounts;
  final String? whatsapp;
}

/// Halaman Selesaikan Pembayaran (Bab 9.8 / 12.2).
@riverpod
class CheckoutViewModel extends _$CheckoutViewModel {
  @override
  Future<CheckoutData> build() async {
    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;

    final repo = ref.read(subscriptionRepositoryProvider);

    final tagihan = (await repo.fetchLatest()).unwrap();
    final metode = (await repo.fetchPaymentMethods()).getOrElse(
      (_) => PaymentMethods.fallback,
    );
    final wa = (await repo.fetchSupportWhatsapp()).valueOrNull;

    return CheckoutData(
      // Tagihan yang sudah lunas bukan urusan halaman ini lagi.
      bill: tagihan != null && tagihan.isPending ? tagihan : null,
      accounts: metode.bankAccounts,
      whatsapp: wa,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Mengunggah bukti transfer (langkah 4).
  ///
  /// Mengembalikan kegagalan, atau null bila berhasil.
  Future<AppFailure?> uploadProof(Uint8List bytes) async {
    final data = state.value;
    final tagihan = data?.bill;
    if (tagihan == null) return AppFailure.notFound;

    final hasil = await ref
        .read(subscriptionRepositoryProvider)
        .uploadProof(
          tenantId: tagihan.tenantId,
          subscriptionId: tagihan.id,
          bytes: bytes,
        );

    return hasil.fold(
      onOk: (path) async {
        debugPrint('KAMELSCAN_BAYAR bukti terkirim · $path');
        await refresh();
        return null;
      },
      onErr: (failure) {
        debugPrint('KAMELSCAN_BAYAR bukti GAGAL · $failure');
        return failure;
      },
    );
  }

  /// URL bertanda tangan untuk menengok bukti yang sudah diunggah.
  Future<String?> proofUrl() async {
    final path = state.value?.bill?.proofUrl;
    if (path == null || path.isEmpty) return null;

    final hasil = await ref
        .read(subscriptionRepositoryProvider)
        .signedProofUrl(path);
    return hasil.valueOrNull;
  }
}
