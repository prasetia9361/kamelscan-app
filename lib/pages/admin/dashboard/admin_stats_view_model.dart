import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/platform_stats.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/utils/app_failure.dart';

part 'admin_stats_view_model.g.dart';

/// Angka ringkasan platform untuk dasbor Admin (Bab 11.1).
///
/// 🔴 Sengaja **tidak** dimuat oleh halaman menu Admin. Halaman itu dibuka
/// setiap kali admin masuk, sedangkan angka ini menghitung seluruh baris
/// `package_videos` di platform — pekerjaan yang tidak boleh dijalankan hanya
/// karena seseorang lewat. Ia dimuat saat halaman Dasbor Platform dibuka.
@riverpod
class AdminStatsViewModel extends _$AdminStatsViewModel {
  @override
  Future<PlatformStats> build() async {
    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;

    debugPrint('KAMELSCAN_ADMIN minta angka platform');
    final hasil = await ref.read(adminRepositoryProvider).fetchPlatformStats();

    // Jalur gagal ikut dicetak — aturan L.9. Yang bukan admin akan sampai di
    // sini dengan galat izin, dan itu perilaku yang benar: fungsi servernya
    // menolak, bukan mengembalikan nol.
    debugPrint('KAMELSCAN_ADMIN angka platform '
        '${hasil.isOk ? 'OK · ${hasil.valueOrNull?.totalTenants} tenant' : 'GAGAL · ${hasil.failureOrNull}'}');

    return hasil.unwrap();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () async =>
          (await ref.read(adminRepositoryProvider).fetchPlatformStats())
              .unwrap(),
    );
  }
}
