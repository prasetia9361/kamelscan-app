import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/daily_stats.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/repositories/dashboard_repository.dart';
import '../../../core/utils/app_failure.dart';

part 'web_dashboard_view_model.g.dart';

/// Rentang yang sedang dipilih di dasbor: 7, 30, atau 90 hari (Bab 10.4).
///
/// Dipisah dari [WebDashboardViewModel] supaya penggantian rentang tidak
/// membuang ViewModel-nya. Kalau rentang disimpan di dalam ViewModel, setiap
/// klik tombol melahirkan ViewModel baru — dan grafiknya berkedip dari data
/// menjadi kerangka lalu kembali, walaupun jawabannya datang dalam sekejap.
@riverpod
class DashboardRange extends _$DashboardRange {
  /// 30 hari sebagai bawaan: cukup panjang untuk melihat pola mingguan,
  /// cukup pendek untuk tetap terbaca pada layar laptop.
  @override
  int build() => 30;

  void select(int days) {
    if (!DashboardRepository.allowedRanges.contains(days)) return;
    state = days;
  }
}

/// Grafik dan kartu ringkasan dasbor web (Bab 10.4).
@riverpod
class WebDashboardViewModel extends _$WebDashboardViewModel {
  @override
  Future<DailyStats> build() async {
    // 🔴 `watch`, bukan `read`. Inilah yang membuat grafik dimuat ulang saat
    // tombol 7/30/90 ditekan — tanpa satu baris pun kode penyegaran.
    final days = ref.watch(dashboardRangeProvider);

    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;

    debugPrint('KAMELSCAN_DASBOR minta statistik · $days hari');
    final hasil = await ref.read(dashboardRepositoryProvider).fetchDailyStats(days);

    // Jalur gagal ikut dicetak, bukan hanya jalur berhasil — aturan yang lahir
    // dari L.9. Tanpa ini, "server menolak" tidak dapat dibedakan dari
    // "permintaannya tidak pernah berangkat".
    debugPrint('KAMELSCAN_DASBOR statistik '
        '${hasil.isOk ? 'OK · ${hasil.valueOrNull?.totalVideos} video' : 'GAGAL · ${hasil.failureOrNull}'}');

    return hasil.unwrap();
  }

  /// Penyegaran yang diminta pengguna. Kegagalan di sini **memang**
  /// ditampilkan: ia sedang menunggu jawabannya.
  Future<void> refresh() async {
    final days = ref.read(dashboardRangeProvider);
    state = await AsyncValue.guard(
      () async =>
          (await ref.read(dashboardRepositoryProvider).fetchDailyStats(days))
              .unwrap(),
    );
  }
}
