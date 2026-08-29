import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/pending_payment.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/utils/app_failure.dart';

part 'admin_payments_view_model.g.dart';

/// Daftar pembayaran manual yang menunggu verifikasi Admin (Bab 12.2).
///
/// 🔴 Layar ini menyentuh **uang sungguhan**. Menyetujui satu baris di sini
/// menaikkan tier tenant, mengisi ulang dompet tokennya, dan memulai periode
/// langganan 30 hari — seluruhnya lewat trigger `activate_subscription()`
/// (migrasi 28). Tidak ada tombol pembatalan.
///
/// Karena itu ViewModel ini **tidak pernah** menyetujui atas inisiatifnya
/// sendiri: tidak ada percobaan ulang otomatis, tidak ada penyegaran yang
/// diam-diam memanggil ulang. Setiap persetujuan datang dari satu ketukan
/// manusia yang sudah melihat bukti transfernya.
@riverpod
class AdminPaymentsViewModel extends _$AdminPaymentsViewModel {
  @override
  Future<List<PendingPayment>> build() async {
    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;

    debugPrint('KAMELSCAN_ADMIN minta daftar pembayaran');
    final hasil = await ref.read(adminRepositoryProvider).fetchPendingPayments();

    debugPrint('KAMELSCAN_ADMIN '
        '${hasil.isOk ? 'OK · ${hasil.valueOrNull?.length} menunggu' : 'GAGAL · ${hasil.failureOrNull}'}');

    return hasil.unwrap();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () async =>
          (await ref.read(adminRepositoryProvider).fetchPendingPayments())
              .unwrap(),
    );
  }

  /// Setujui satu pembayaran. Mengembalikan kegagalan, atau null bila berhasil.
  ///
  /// 🔴 `verifiedBy` diambil dari sesi yang sedang berjalan, bukan dikirim
  /// pemanggil. Kolom itu satu-satunya jejak siapa yang menyetujui uang masuk;
  /// membiarkan layar menentukan isinya berarti jejak itu dapat dikarang.
  Future<AppFailure?> approve(String subscriptionId) async {
    final adminId = ref.read(sessionProvider).value?.user.id;
    if (adminId == null) return AppFailure.sessionExpired;

    debugPrint('KAMELSCAN_ADMIN setujui $subscriptionId');
    final hasil = await ref.read(adminRepositoryProvider).approvePayment(
          subscriptionId: subscriptionId,
          verifiedBy: adminId,
        );

    // 🔴 Daftar disegarkan HANYA setelah berhasil. Membuangnya lebih dulu
    // membuat baris hilang dari layar walaupun servernya menolak — dan yang
    // melihatnya akan mengira pekerjaannya sudah selesai.
    if (hasil.isOk) await refresh();

    debugPrint('KAMELSCAN_ADMIN setujui '
        '${hasil.isOk ? 'BERHASIL' : 'GAGAL · ${hasil.failureOrNull}'}');
    return hasil.failureOrNull;
  }

  /// Tolak satu pembayaran, dengan alasan yang **dibaca pelanggan**.
  ///
  /// ⚠️ Tidak ada trigger apa pun yang bereaksi terhadap status `failed`.
  /// Menolak hanya menutup baris itu; uang yang terlanjur masuk **tidak**
  /// dikembalikan aplikasi, dan tidak ada pemberitahuan yang dikirim ke mana
  /// pun. Keduanya urusan manusia, dan layar ini mengatakannya apa adanya.
  ///
  /// 🔴 Yang berubah sejak 29 Agustus 2026 hanyalah bahwa penolakannya kini
  /// **terlihat**: alasannya tersimpan di `subscriptions.rejection_reason` dan
  /// muncul sebagai spanduk di halaman Pembayaran pelanggan. Sebelumnya
  /// spanduk "menunggu verifikasi" lenyap begitu saja dan tagihannya seolah
  /// menguap — ditemukan Product Owner saat menguji tombol ini pada baris
  /// sungguhan.
  Future<AppFailure?> reject(String subscriptionId, String reason) async {
    debugPrint('KAMELSCAN_ADMIN tolak $subscriptionId');
    final hasil = await ref.read(adminRepositoryProvider).rejectPayment(
          subscriptionId: subscriptionId,
          reason: reason,
        );
    if (hasil.isOk) await refresh();

    debugPrint('KAMELSCAN_ADMIN tolak '
        '${hasil.isOk ? 'BERHASIL' : 'GAGAL · ${hasil.failureOrNull}'}');
    return hasil.failureOrNull;
  }

  /// URL bertanda tangan untuk menengok bukti transfer.
  ///
  /// Berumur 5 menit dengan sengaja (`signedProofUrl`): bukti transfer memuat
  /// mutasi rekening, dan tautan yang hidup lama bertahan di riwayat peramban
  /// serta log server.
  Future<String?> proofUrl(String path) async {
    final hasil =
        await ref.read(subscriptionRepositoryProvider).signedProofUrl(path);
    return hasil.valueOrNull;
  }
}
