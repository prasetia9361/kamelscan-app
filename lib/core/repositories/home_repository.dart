import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_constants.dart';
import '../models/home_stats.dart';
import '../services/supabase_service.dart';
import '../utils/result.dart';

/// Sumber data kartu monitoring Beranda (Bab 9.2).
///
/// Dipisahkan dari [VideoRepository] dan [TokenRepository] karena isinya
/// memang gabungan keduanya: satu panggilan yang menjawab "berapa video dan
/// berapa sisa token", bukan pertanyaan tentang salah satunya.
class HomeRepository {
  const HomeRepository(this._client);

  final SupabaseClient _client;

  /// RPC `get_home_stats()` — migrasi `20_home_stats.sql`.
  ///
  /// Cakupannya ditentukan RLS (`security invoker`), jadi tidak ada satu pun
  /// aturan peran yang perlu ditulis ulang di sini.
  Future<Result<HomeStats>> fetchStats() async {
    try {
      final json = await _client.rpc<Map<String, dynamic>>('get_home_stats');
      return Result.ok(HomeStats.fromJson(json));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Berdenting setiap kali angka di kartu berpotensi berubah (Bab 9.2 —
  /// *"data ini wajib dinamis dan real-time"*).
  ///
  /// Yang dikirim hanya **isyarat**, bukan datanya: penerimanya memanggil
  /// [fetchStats] lagi. Alasannya bukan kemalasan — muatan perubahan satu baris
  /// tidak dapat dipakai menghitung ulang agregat tanpa menyalin aturan periode
  /// dan aturan RLS ke sisi klien, dan salinan seperti itu akan menyimpang
  /// diam-diam begitu salah satunya berubah.
  ///
  /// Dua tabel didengarkan sekaligus:
  ///
  ///   - `token_wallets` — bergerak setiap kali sebuah video **berhasil**
  ///     diunggah, karena trigger `after_video_uploaded` memotong satu token
  ///     (Bab 7.2). Ini jalur yang paling sering dan paling andal.
  ///   - `package_videos` — untuk perubahan yang tidak menyentuh dompet:
  ///     unggahan yang gagal, dan video yang dihapus Owner.
  ///
  /// 🔴 Keduanya harus terdaftar di publikasi `supabase_realtime`, kalau tidak
  /// langganan ini **berhasil lalu diam selamanya tanpa error apa pun**.
  /// Pendaftarannya ada di migrasi `21_realtime_publication.sql`; lihat catatan
  /// di sana sebelum menduga masalahnya di kode Dart.
  Stream<void> watchStatsChanges(String tenantId) {
    final controller = StreamController<void>();
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'tenant_id',
      value: tenantId,
    );

    void ping(PostgresChangePayload payload) {
      debugPrint('KAMELSCAN_HOME isyarat · ${payload.table}/${payload.eventType.name}');
      if (!controller.isClosed) controller.add(null);
    }

    // ⚠️ Satu topik per tenant. Berlangganan topik yang sama dua kali dalam
    // satu aplikasi ditolak Realtime ("tried to subscribe multiple times"),
    // jadi hanya boleh ada satu pembaca — `homeViewModelProvider`.
    final channel = _client
        .channel('home-stats-$tenantId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: AppConstants.tblTokenWallets,
          filter: filter,
          callback: ping,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: AppConstants.tblPackageVideos,
          filter: filter,
          callback: ping,
        )
        // 🔴 Status langganan WAJIB dicetak, bukan diabaikan.
        //
        // Tanpa baris ini, langganan yang ditolak Realtime tampak persis sama
        // dengan langganan sehat yang kebetulan belum ada perubahannya: kedua-
        // duanya diam. Product Owner melaporkan 18 Agustus 2026 bahwa angka di
        // Beranda tidak berubah sendiri, dan tanpa status ini tidak ada cara
        // membedakan "channel gagal tersambung" dari "channel baik, isyaratnya
        // yang tidak dikirim server" — dua sebab yang perbaikannya berbeda
        // sama sekali.
        .subscribe((status, error) {
      debugPrint(
        'KAMELSCAN_HOME langganan status=${status.name}'
        '${error == null ? '' : ' · GAGAL: $error'}',
      );
    });

    controller.onCancel = () async {
      await _client.removeChannel(channel);
      await controller.close();
    };
    return controller.stream;
  }
}
