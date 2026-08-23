import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/packer_summary.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/utils/app_failure.dart';

part 'packers_view_model.g.dart';

/// Hasil percobaan menghapus akun packer (Bab 9.6).
sealed class PackerDeleteOutcome {
  const PackerDeleteOutcome();
}

class PackerDeleted extends PackerDeleteOutcome {
  const PackerDeleted();
}

/// 🔴 Packer yang sudah pernah merekam **tidak boleh dihapus**.
///
/// `package_videos.user_id` memakai `on delete restrict` supaya tiap video
/// tetap menunjuk orang yang merekamnya. Menghapus perekamnya berarti memutus
/// rantai bukti tepat di titik yang paling dipertanyakan saat sengketa —
/// "siapa yang mengemas paket ini?".
///
/// Jalan keluarnya menonaktifkan akun: ia tidak dapat masuk lagi, tetapi
/// seluruh rekamannya tetap utuh dan tetap bernama.
class PackerHasVideos extends PackerDeleteOutcome {
  const PackerHasVideos(this.videoCount);
  final int videoCount;
}

class PackerDeleteFailed extends PackerDeleteOutcome {
  const PackerDeleteFailed(this.failure);
  final AppFailure failure;
}

/// Kelola Akun Packer (Bab 9.6 — Owner saja).
@riverpod
class PackersViewModel extends _$PackersViewModel {
  @override
  Future<List<PackerSummary>> build() async {
    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;

    return (await ref.read(userRepositoryProvider).fetchPackerSummaries())
        .unwrap();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () async =>
          (await ref.read(userRepositoryProvider).fetchPackerSummaries())
              .unwrap(),
    );
  }

  /// Buat akun packer baru.
  ///
  /// ⚠️ Batas jumlah packer ditegakkan **trigger `check_packer_limit`** di
  /// server, bukan di sini. Layar tetap menonaktifkan tombolnya saat kuota
  /// penuh agar Owner tahu lebih awal, tetapi yang menentukan tetap server —
  /// dua Owner yang menambah packer nyaris bersamaan tidak dapat dicegah dari
  /// aplikasi.
  Future<(NewPackerCredentials?, AppFailure?)> create({
    required String email,
    required String fullName,
    List<String> shopIds = const [],
  }) async {
    final result = await ref.read(userRepositoryProvider).createPacker(
          email: email.trim(),
          fullName: fullName.trim(),
          shopIds: shopIds,
        );

    return result.fold(
      onOk: (kredensial) async {
        await refresh();
        // Jumlah packer terpakai ikut berubah, dan kuotanya dibaca dari sesi.
        ref.invalidate(sessionProvider);
        return (kredensial, null);
      },
      onErr: (failure) {
        debugPrint('KAMELSCAN_PACKER buat GAGAL · $failure');
        return (null, failure);
      },
    );
  }

  Future<AppFailure?> setActive(String userId, {required bool active}) async {
    final result =
        await ref.read(userRepositoryProvider).setPackerActive(userId, active);

    final failure = result.failureOrNull;
    if (failure != null) {
      debugPrint('KAMELSCAN_PACKER ubah status GAGAL · $failure');
      return failure;
    }
    await refresh();
    return null;
  }

  /// Kirim tautan atur ulang password ke email packer.
  ///
  /// Dipilih daripada menerbitkan password sementara baru: tautan itu hanya
  /// dapat dipakai pemilik kotak masuknya, sedangkan password baru harus
  /// dibacakan Owner ke packer lewat jalur yang tidak terkendali — dan Bab 6.7
  /// memang menghendaki packer memiliki passwordnya sendiri.
  Future<AppFailure?> sendPasswordReset(String email) async {
    final result =
        await ref.read(authRepositoryProvider).sendPasswordReset(email);

    final failure = result.failureOrNull;
    if (failure != null) {
      debugPrint('KAMELSCAN_PACKER reset password GAGAL · $failure');
    }
    return failure;
  }

  Future<PackerDeleteOutcome> delete(PackerSummary item) async {
    if (!item.canDelete) return PackerHasVideos(item.videoCount);

    final result =
        await ref.read(userRepositoryProvider).deletePacker(item.user.id);

    final failure = result.failureOrNull;
    if (failure == null) {
      await refresh();
      ref.invalidate(sessionProvider);
      return const PackerDeleted();
    }

    debugPrint('KAMELSCAN_PACKER hapus GAGAL · $failure');

    // Server menolak karena ada video yang menunjuk akun ini. Terjadi bila
    // daftar di layar sudah usang — perlakukan sama dengan penolakan yang
    // sudah diketahui di muka, bukan sebagai error tak dikenal.
    //
    // Dibandingkan dengan [AppFailure.packerHasVideos], bukan dengan SQLSTATE
    // `23503` seperti sebelumnya: sejak 20 Agustus 2026 penghapusan berjalan
    // lewat Edge Function `delete-packer`, sehingga penolakannya datang
    // sebagai kode `PACKER_HAS_VIDEOS` dan tidak pernah lagi membawa nomor
    // SQLSTATE.
    if (failure.messageKey == AppFailure.packerHasVideos.messageKey) {
      await refresh();
      return PackerHasVideos(item.videoCount);
    }
    return PackerDeleteFailed(failure);
  }
}
