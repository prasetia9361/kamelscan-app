import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/models/payment_history_entry.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/session_provider.dart';
import '../../core/utils/app_failure.dart';

part 'payment_history_view_model.g.dart';

/// Riwayat pembayaran (Bab 7.2) — diminta Product Owner 3 September 2026.
///
/// 🔴 Dua sumber, satu layar. `subscriptions` menjawab *kapan, apa, dan
/// bagaimana membayarnya*; `token_ledger` menjawab *berapa token yang
/// benar-benar masuk*. Keduanya sudah boleh dibaca aplikasi sejak migrasi 14,
/// jadi layar ini tidak menuntut satu migrasi pun.
///
/// ⚠️ Buku besarnya diambil dengan batas yang **lebih besar** daripada
/// langganannya, dan itu bukan angka asal: satu tenant menulis banyak baris
/// buku besar per hari (tiap video memotong token), sementara pembelian
/// terjadi paling banter beberapa kali sebulan. Batas yang sama besar akan
/// membuat pembelian lama tidak menemukan pasangannya — dan kolom tokennya
/// diam-diam berubah menjadi tanda hubung pada baris yang datanya sebenarnya
/// ada.
@riverpod
Future<List<PaymentHistoryEntry>> paymentHistory(Ref ref) async {
  final session = ref.watch(sessionProvider).value;
  if (session == null) throw AppFailure.sessionExpired;

  debugPrint('KAMELSCAN_PAYMENT minta riwayat pembayaran');

  final langganan =
      await ref.read(subscriptionRepositoryProvider).fetchHistory();
  if (langganan.isErr) {
    debugPrint(
      'KAMELSCAN_PAYMENT riwayat GAGAL · ${langganan.failureOrNull}',
    );
    throw langganan.failureOrNull!;
  }

  // 🔴 Kegagalan buku besar TIDAK menggagalkan layarnya. Tanpa buku besar
  // riwayatnya tetap menjawab empat dari lima pertanyaan; dengan melempar, ia
  // tidak menjawab satu pun. Kolom tokennya menjadi tanda hubung — yang memang
  // artinya "tidak diketahui".
  final ledger = await ref
      .read(tokenRepositoryProvider)
      .fetchLedger(session.tenant.id, limit: 500);

  if (ledger.isErr) {
    debugPrint(
      'KAMELSCAN_PAYMENT buku besar GAGAL · ${ledger.failureOrNull} '
      '- riwayat tetap ditampilkan tanpa jumlah token',
    );
  }

  final hasil = PaymentHistoryEntry.susun(
    subscriptions: langganan.unwrap(),
    ledger: ledger.valueOrNull ?? const [],
  );

  debugPrint('KAMELSCAN_PAYMENT riwayat OK · ${hasil.length} pembayaran');
  return hasil;
}
