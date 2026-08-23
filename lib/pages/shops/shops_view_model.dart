import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/models/shop_summary.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/session_provider.dart';
import '../../core/utils/app_failure.dart';

part 'shops_view_model.g.dart';

/// Hasil percobaan menghapus toko (Bab 9.5).
///
/// Dibedakan bertingkat karena ketiganya menuntut kalimat yang berbeda di
/// layar: berhasil, ditolak server karena masih punya video, atau gagal karena
/// sebab lain.
sealed class ShopDeleteOutcome {
  const ShopDeleteOutcome();
}

class ShopDeleted extends ShopDeleteOutcome {
  const ShopDeleted();
}

/// 🔴 `package_videos.shop_id` memakai `on delete restrict` (Bab 5.2), dan itu
/// disengaja: video terikat pada toko tempat perekaman terjadi, jadi menghapus
/// tokonya akan memutus rantai bukti.
///
/// Yang benar bukan memaksa penghapusan, melainkan menawarkan **menonaktifkan**
/// toko — ia hilang dari pilihan perekaman tanpa menyentuh satu pun video lama.
class ShopHasVideos extends ShopDeleteOutcome {
  const ShopHasVideos(this.videoCount);
  final int videoCount;
}

class ShopDeleteFailed extends ShopDeleteOutcome {
  const ShopDeleteFailed(this.failure);
  final AppFailure failure;
}

/// Daftar toko (Bab 9.5 — Owner saja).
@riverpod
class ShopsViewModel extends _$ShopsViewModel {
  @override
  Future<List<ShopSummary>> build() async {
    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;

    return (await ref.read(shopRepositoryProvider).fetchShopSummaries())
        .unwrap();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () async =>
          (await ref.read(shopRepositoryProvider).fetchShopSummaries()).unwrap(),
    );
  }

  /// Nyalakan/matikan toko.
  ///
  /// Toko nonaktif tidak lagi muncul di layar setup perekaman, tetapi seluruh
  /// video lamanya tetap utuh dan tetap terbaca di Riwayat.
  Future<AppFailure?> setActive(String shopId, {required bool active}) async {
    final result = await ref
        .read(shopRepositoryProvider)
        .updateShop(shopId, isActive: active);

    return result.fold(
      onOk: (_) async {
        await refresh();
        return null;
      },
      onErr: (failure) {
        debugPrint('KAMELSCAN_TOKO ubah status GAGAL · $failure');
        return failure;
      },
    );
  }

  /// Hapus toko — hanya mungkin bila belum pernah dipakai merekam.
  ///
  /// Jumlah videonya sudah diketahui dari daftar, jadi penolakannya dapat
  /// dijelaskan **sebelum** server dihubungi. Tetapi hasil dari server tetap
  /// yang menentukan: daftar di layar bisa saja tertinggal beberapa detik dari
  /// keadaan sebenarnya bila packer lain baru saja merekam.
  Future<ShopDeleteOutcome> delete(ShopSummary item) async {
    if (!item.canDelete) return ShopHasVideos(item.videoCount);

    final result =
        await ref.read(shopRepositoryProvider).deleteShop(item.shop.id);

    final failure = result.failureOrNull;
    if (failure == null) {
      await refresh();
      return const ShopDeleted();
    }

    debugPrint('KAMELSCAN_TOKO hapus GAGAL · $failure');

    // `23503` = pelanggaran foreign key: sebuah video menunjuk toko ini.
    // Terjadi bila daftar di layar sudah usang — perlakukan sama dengan
    // penolakan yang sudah diketahui di muka, bukan sebagai error tak dikenal.
    if (failure.code == '23503') {
      await refresh();
      return ShopHasVideos(item.videoCount);
    }
    return ShopDeleteFailed(failure);
  }
}
