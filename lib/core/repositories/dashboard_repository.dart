import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/daily_stats.dart';
import '../services/supabase_service.dart';
import '../utils/result.dart';

/// Sumber data dasbor web (Bab 10.4).
///
/// Dipisahkan dari [HomeRepository] karena keduanya menjawab pertanyaan yang
/// berbeda dan memakai periode yang berbeda — lihat catatan panjang di
/// [DailyStats]. Menggabungkannya ke satu repositori akan mengundang orang
/// berikutnya "menyeragamkan" periodenya, dan itu justru cacatnya.
class DashboardRepository {
  const DashboardRepository(this._client);

  final SupabaseClient _client;

  /// Rentang yang boleh diminta — pemilih Bab 10.4.
  ///
  /// Server menjepit nilai di luar 7..90, jadi daftar ini bukan penjagaan
  /// keamanan melainkan sumber tunggal bagi tombol pemilih dan tesnya.
  static const List<int> allowedRanges = [7, 30, 90];

  /// RPC `get_daily_stats(p_days)` — migrasi `27_daily_stats.sql`.
  ///
  /// Hari dikelompokkan menurut waktu Asia/Jakarta di **server**, bukan di
  /// sini. Menghitungnya di peramban akan mengikuti zona waktu laptop yang
  /// membukanya, dan dua orang yang menelepon satu sama lain akan melihat
  /// grafik yang berbeda.
  Future<Result<DailyStats>> fetchDailyStats(int days) async {
    try {
      final json = await _client.rpc<Map<String, dynamic>>(
        'get_daily_stats',
        params: {'p_days': days},
      );
      return Result.ok(DailyStats.fromJson(json));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }
}
