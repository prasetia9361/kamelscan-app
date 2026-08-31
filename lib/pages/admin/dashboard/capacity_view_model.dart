import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/domain/capacity_status.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/utils/result.dart';

part 'capacity_view_model.g.dart';

/// Kapasitas platform untuk kartu di Statistik Platform (Bab 11.1).
///
/// 🔴 Provider tersendiri, bukan ditempelkan ke `AdminStatsViewModel`.
/// `pg_database_size()` memindai seluruh direktori database; menyatukannya
/// berarti setiap pembukaan halaman statistik membayar pemindaian itu untuk
/// angka yang hanya berubah beberapa kilobyte per jam.
///
/// ⚠️ Kegagalannya juga tidak boleh menular. Angka pendapatan dan jumlah
/// pelanggan adalah alasan halaman ini dibuka; kartu kapasitas yang gagal
/// dimuat tidak boleh menyeret keduanya ikut hilang.
@riverpod
class CapacityViewModel extends _$CapacityViewModel {
  @override
  Future<CapacityStats> build() async {
    final hasil = await ref.read(adminRepositoryProvider).fetchCapacityStats();

    if (hasil case Err(:final failure)) {
      throw failure;
    }
    return hasil.unwrap();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    ref.invalidateSelf();
    await future;
  }
}
