import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/providers/session_provider.dart';
import '../../core/repositories/account_deletion_repository.dart';
import '../../core/utils/app_failure.dart';
import '../../core/utils/result.dart';

part 'delete_account_view_model.g.dart';

sealed class DeleteAccountState {
  const DeleteAccountState();
}

class DeleteAccountIdle extends DeleteAccountState {
  const DeleteAccountIdle();
}

class DeleteAccountBusy extends DeleteAccountState {
  const DeleteAccountBusy();
}

class DeleteAccountFailed extends DeleteAccountState {
  const DeleteAccountFailed(this.failure);
  final AppFailure failure;
}

/// Akun trial yang sudah benar-benar hilang.
///
/// Dibedakan dari [DeleteAccountIdle] karena layarnya masih terpasang sesaat
/// sesudahnya dan perlu mengucapkan sesuatu sebelum pengguna dikeluarkan.
class DeleteAccountPurged extends DeleteAccountState {
  const DeleteAccountPurged();
}

/// Bab 9.6 — Owner menghapus akunnya sendiri, dan membatalkannya.
///
/// 🔴 **Layar tidak menavigasi sendiri.** Sesudah permintaannya diterima,
/// `sessionProvider` dimuat ulang, `tenant.isDeletionPending` menjadi `true`,
/// dan `RouteGuards` yang memindahkan pengguna ke layar kunci. Pembatalan
/// bekerja dengan cara yang sama, ke arah sebaliknya.
///
/// Alasannya sama persis dengan `LogoutViewModel`: begitu ada dua pihak yang
/// menentukan tujuan, keduanya akan berselisih pada keadaan yang tidak
/// terpikirkan — dan penjaga rute tetap harus benar sendirian, karena ia juga
/// yang menangkap deep link.
@riverpod
class DeleteAccountViewModel extends _$DeleteAccountViewModel {
  @override
  DeleteAccountState build() => const DeleteAccountIdle();

  /// [confirmation] adalah nama usaha yang diketik ulang Owner. Dikirim apa
  /// adanya — servernya yang mencocokkan (migrasi 37).
  Future<void> request(String confirmation) async {
    if (state is DeleteAccountBusy) return;
    state = const DeleteAccountBusy();

    final hasil = await ref
        .read(accountDeletionRepositoryProvider)
        .requestDeletion(confirmation);

    switch (hasil) {
      case Err(:final failure):
        if (ref.mounted) state = DeleteAccountFailed(failure);

      case Ok(value: DeletionOutcome.dihapusSekarang):
        // Akun trial. Barisnya sudah tidak ada, jadi memuat ulang sesi hanya
        // akan menemui profil yang hilang. Yang tersisa hanyalah menutup sesi
        // lokalnya; halaman yang memanggil yang mengeluarkan penggunanya.
        if (ref.mounted) state = const DeleteAccountPurged();

      case Ok():
        // Dijadwalkan, atau memang sudah pernah diminta sebelumnya. Keduanya
        // berakhir di tempat yang sama, dan keduanya benar.
        //
        // 🔴 `reload()` yang DITUNGGU, bukan `ref.invalidate` yang dilepas
        //    begitu saja. `invalidate` hanya menandai sesinya kotor dan
        //    membiarkan pemuatan ulangnya terjadi belakangan; selama jeda itu
        //    penjaga rute masih membaca tenant yang lama, memutuskan tidak ada
        //    yang perlu dipindahkan, dan layarnya diam.
        //
        //    Dilaporkan Product Owner 1 September 2026: *"saat klik hapus tidak
        //    ada respon, harus keluar dulu baru kalau masuk muncul halaman
        //    itu"* — dan ia menambahkan alasan kenapa itu mahal meski akunnya
        //    memang jadi terhapus: orang mengira aplikasinya rusak, lalu
        //    menekan tombolnya berulang-ulang.
        //
        // ⚠️ Menunggu di sini aman: `reload()` menyetel AsyncLoading lebih
        //    dulu, jadi layar mana pun yang sedang menyimak sesi menampilkan
        //    keadaan memuat, bukan data basi.
        await ref.read(sessionProvider.notifier).reload();
        if (ref.mounted) state = const DeleteAccountIdle();
    }
  }

  Future<void> cancel() async {
    if (state is DeleteAccountBusy) return;
    state = const DeleteAccountBusy();

    final hasil = await ref.read(accountDeletionRepositoryProvider).cancelDeletion();

    if (hasil case Err(:final failure)) {
      if (ref.mounted) state = DeleteAccountFailed(failure);
      return;
    }

    // Ditunggu, dengan alasan yang sama persis seperti di [request] — hanya
    // arahnya terbalik. Tanpa ini layar kunci tetap terpasang sesudah
    // pembatalan berhasil, dan Owner menekan "Batalkan penghapusan" lagi.
    await ref.read(sessionProvider.notifier).reload();
    if (ref.mounted) state = const DeleteAccountIdle();
  }

  void clearError() {
    if (state is DeleteAccountFailed) state = const DeleteAccountIdle();
  }
}
