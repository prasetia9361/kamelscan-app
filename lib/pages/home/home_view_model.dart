import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/models/home_stats.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/upload_queue_provider.dart';
import '../../core/utils/app_failure.dart';

part 'home_view_model.g.dart';

/// Isyarat "angka di Beranda mungkin berubah" dari Realtime (Bab 9.2).
///
/// Dipisah dari [HomeViewModel] agar umur langganannya jelas: ia hidup selama
/// ada yang mendengarkan dan ditutup begitu tidak ada — bukan menumpuk satu
/// langganan baru setiap kali statistiknya dimuat ulang.
@riverpod
Stream<void> homeStatsSignal(Ref ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return const Stream.empty();
  return ref.watch(homeRepositoryProvider).watchStatsChanges(session.tenantId);
}

/// Kartu monitoring Beranda (Bab 9.2).
@riverpod
class HomeViewModel extends _$HomeViewModel {
  Timer? _debounce;

  @override
  Future<HomeStats> build() async {
    // 🔴 Jejak pengukur — TIDAK mengubah perilaku apa pun.
    //
    // Beranda packer kadang kosong dan kadang tidak pada langkah yang sama
    // persis (M.17). Empat baris di berkas ini memisahkan empat sebab yang
    // gejalanya identik dari luar: sesinya belum siap, permintaannya tidak
    // pernah kembali, hasilnya tidak pernah menjadi keadaan layar, atau
    // ViewModel-nya dibuang di tengah jalan.
    final sesiSekarang = ref.watch(sessionProvider);
    final session = sesiSekarang.value;
    debugPrint('KAMELSCAN_HOME vm mulai · sesi=${sesiSekarang.runtimeType} '
        'role=${session?.role.wire}');
    if (session == null) throw AppFailure.sessionExpired;

    // Yang paling menentukan: apakah hasil kerja ViewModel ini pernah sampai
    // ke layar sama sekali.
    listenSelf((sebelum, sesudah) => debugPrint(
          'KAMELSCAN_HOME vm keadaan → ${sesudah.runtimeType} '
          'punyaNilai=${sesudah.hasValue} error=${sesudah.hasError}',
        ));

    ref.listen(homeStatsSignalProvider, (_, _) => _scheduleRefresh());

    // 🔴 Jaring pengaman yang TIDAK bergantung pada Realtime.
    //
    // Product Owner menguji di perangkat 18 Agustus 2026: video return terekam
    // dan angkanya benar, tetapi baru muncul setelah halaman dimuat ulang
    // dengan tangan. Realtime pada proyek ini belum pernah terbukti hidup, dan
    // menggantungkan satu-satunya jalur penyegaran padanya berarti keluhan itu
    // bertahan sampai penyebabnya ditemukan.
    //
    // Antrian lokal adalah sumber yang pasti ada — ia dibaca dari SQLite di
    // perangkat ini, tanpa jaringan sama sekali. Jumlahnya **berkurang** tepat
    // ketika sebuah video selesai terkirim, dan itulah saat angka di kartu
    // berubah di server. Kenaikan sengaja diabaikan: video yang baru direkam
    // belum menambah apa pun di sana (L.5 — barisnya baru dibuat saat
    // mengunggah).
    ref.listen(pendingUploadCountProvider, (previous, next) {
      final before = previous?.value;
      final after = next.value;
      if (before == null || after == null || after >= before) return;
      debugPrint('KAMELSCAN_HOME antrian $before → $after · menyegarkan');
      _scheduleRefresh();
    });

    ref.onDispose(() {
      _debounce?.cancel();
      debugPrint('KAMELSCAN_HOME vm dibuang');
    });

    debugPrint('KAMELSCAN_HOME vm minta statistik');
    final hasil = await ref.read(homeRepositoryProvider).fetchStats();
    debugPrint('KAMELSCAN_HOME vm statistik '
        '${hasil.isOk ? 'OK' : 'GAGAL · ${hasil.failureOrNull}'}');

    return hasil.unwrap();
  }

  /// Penyegaran yang diminta pengguna (tarik ke bawah). Berbeda dengan
  /// [_scheduleRefresh]: di sini kegagalan **memang** ditampilkan, karena
  /// pengguna sedang menunggu jawabannya.
  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () async => (await ref.read(homeRepositoryProvider).fetchStats()).unwrap(),
    );
  }

  /// Perekaman beruntun mengirim satu isyarat per video. Tanpa jeda ini,
  /// packer yang menyelesaikan 30 paket berturut-turut memicu 30 panggilan RPC
  /// beruntun — di jaringan gudang itu justru memperlambat hal lain yang
  /// sedang berjalan, dan angkanya toh sama saja pada panggilan terakhir.
  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _refreshQuietly);
  }

  /// 🔴 Jejak `KAMELSCAN_HOME` sengaja memakai `debugPrint`, bukan `AppLogger`
  /// — `AppLogger` memakai `dart:developer` dan tidak pernah sampai ke logcat
  /// (jebakan 11). Dan sesuai aturan yang lahir dari L.9: **jalur gagalnya ikut
  /// dicetak, bukan hanya jalur berhasil.**
  ///
  /// Ini bukan sisa lupa dibersihkan. Realtime pada proyek ini belum pernah
  /// terbukti hidup di perangkat (publikasinya baru didaftarkan 18 Agustus
  /// 2026, migrasi `21_realtime_publication.sql`), dan baris inilah yang akan
  /// membedakan "isyaratnya tidak pernah datang" dari "isyaratnya datang tetapi
  /// angkanya gagal diambil" — dua sebab yang sangat berbeda dan mustahil
  /// dibedakan dengan mata.
  Future<void> _refreshQuietly() async {
    final result = await ref.read(homeRepositoryProvider).fetchStats();
    result.fold(
      onOk: (stats) {
        debugPrint(
          'KAMELSCAN_HOME segar · packing=${stats.packingCount} '
          'retur=${stats.returnCount} token=${stats.tokenBalance}',
        );
        state = AsyncData(stats);
      },
      // Angka lama sengaja dibiarkan berdiri. Penyegaran latar yang gagal
      // bukan alasan mengosongkan layar yang sedang dipakai bekerja — yang
      // tertulis di sana masih benar sampai beberapa detik lalu.
      onErr: (failure) => debugPrint(
        'KAMELSCAN_HOME segar GAGAL · $failure · angka lama dipertahankan',
      ),
    );
  }
}
