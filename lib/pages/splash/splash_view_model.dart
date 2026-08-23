import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/models/enums.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/utils/app_failure.dart';
import '../../navigation/route_names.dart';

part 'splash_view_model.g.dart';

/// Menentukan tujuan pertama aplikasi setelah sesi & preferensi selesai
/// dipulihkan.
///
/// ViewModel tidak mengimpor `material.dart` (Bab 3.1 poin 2) — ia hanya
/// menghitung path tujuan; navigasinya dikerjakan View lewat GoRouter.
/// Batas waktu memulihkan sesi saat aplikasi dibuka.
///
/// 🔴 Ditambahkan 19 Agustus 2026 setelah aplikasi **menggantung selamanya di
/// layar splash** pada perangkat Product Owner ketika jaringannya terputus.
/// Logonya berputar tanpa pesan apa pun dan tanpa jalan keluar; satu-satunya
/// cara keluar adalah menutup paksa aplikasi.
///
/// Sebabnya: pemulihan sesi menembak empat permintaan berturut-turut ke
/// Supabase (profil, tenant, katalog tier, dompet) dan klien HTTP-nya tidak
/// punya batas waktu bawaan. Pada jaringan yang mati di tengah — bukan
/// tertolak, melainkan diam — permintaan itu tidak pernah kembali.
///
/// 20 detik: cukup longgar untuk jaringan gudang yang lambat, cukup pendek
/// untuk tidak terasa seperti aplikasi yang rusak.
const Duration _batasPemulihanSesi = Duration(seconds: 20);

/// 🔴 Mematikan coba-lagi otomatis Riverpod **khusus layar ini**.
///
/// Riverpod 3 mengulang provider yang gagal sampai 10 kali dengan jeda
/// berlipat: 200 ms, 400, 800, … sampai 6,4 detik. Di layar mana pun itu
/// berguna, tetapi di layar pembuka akibatnya buruk: pengguna menatap logo
/// berputar **± 2,5 menit** sebelum akhirnya diberi tahu bahwa jaringannya
/// mati. Terbukti di Redmi Note 9, 19 Agustus 2026 — tercatat 11 percobaan
/// berturut-turut di logcat.
///
/// Layar pembuka harus cepat berterus terang. Sekali gagal, tampilkan
/// pesannya beserta tombol *Coba lagi*, lalu diam.
///
/// ⚠️ Hanya berlaku di sini. Layar lain (Beranda, Riwayat, Toko) tetap
/// memakai coba-lagi otomatis, karena di sana ia berjalan di latar tanpa
/// menghalangi apa pun.
Duration? _tanpaCobaLagiOtomatis(int retryCount, Object error) => null;

@Riverpod(retry: _tanpaCobaLagiOtomatis)
class SplashViewModel extends _$SplashViewModel {
  /// Dipanggil tombol *Coba lagi*.
  ///
  /// 🔴 `sessionProvider` WAJIB ikut dibuang. Ia `keepAlive`, jadi sekali
  /// gagal ia menyimpan kegagalan itu selamanya — menyegarkan layar ini saja
  /// akan membaca kegagalan yang sama dan langsung menyerah lagi tanpa
  /// menyentuh jaringan.
  ///
  /// Itulah sebabnya tombol *Coba lagi* tidak melakukan apa-apa saat diuji
  /// 19 Agustus 2026: internetnya sudah kembali, tetapi yang dibaca tetap
  /// kegagalan lama.
  void retry() {
    ref.invalidate(sessionProvider);
    ref.invalidateSelf();
  }
  @override
  Future<String> build() async {
    // Preferensi dimuat lebih dulu agar tema tidak berkedip saat layar
    // pertama tampil.
    await ref.read(appPreferencesProvider.future);

    final signedIn = ref.read(isSignedInProvider);

    // 🔴 Jejak diagnosis — jangan dihapus tanpa penggantinya.
    //
    // 19 Agustus 2026 aplikasi dalam mode pesawat langsung membuka halaman
    // login, padahal sesinya masih tersimpan. Membaca kode `gotrue` dan
    // `supabase_flutter` tidak menjelaskannya: kegagalan penyegaran token
    // karena jaringan **tidak** menghapus sesi di sana. Baris ini yang akan
    // membedakan "sesinya memang hilang" dari "sesinya ada tetapi ada yang
    // lain mengalihkan" — dua sebab yang perbaikannya berbeda sama sekali.
    debugPrint('KAMELSCAN_SPLASH mulai · isSignedIn=$signedIn');

    if (!signedIn) {
      debugPrint('KAMELSCAN_SPLASH → login (tidak ada sesi tersimpan)');
      return Routes.login;
    }

    final SessionContext? session;
    try {
      session = await ref
          .read(sessionProvider.future)
          .timeout(_batasPemulihanSesi, onTimeout: () {
      // Dilempar, bukan dibiarkan diam. `SplashPage` sudah menangani keadaan
      // error dengan `AppErrorView` beserta tombol *Coba lagi*; yang selama ini
      // kurang hanyalah sesuatu yang mengakhiri penantiannya.
      //
      // 🔴 Sengaja TIDAK jatuh ke halaman login. Sesinya kemungkinan besar
      // masih sah — yang gagal jaringannya. Melempar pengguna ke layar masuk
      // akan menyuruhnya mengetik ulang kata sandi untuk masalah yang bukan
      // salahnya, dan di gudang tanpa sinyal ia justru tidak akan bisa masuk
      // kembali.
        debugPrint('KAMELSCAN_SPLASH sesi TIMEOUT setelah '
            '${_batasPemulihanSesi.inSeconds} dtk');
        throw AppFailure.network;
      });
    } on Object catch (error) {
      // Sesuai aturan L.9: jalur gagalnya ikut dicetak, bukan hanya yang
      // berhasil. Tanpa ini, kegagalan cepat — misalnya tidak ada jaringan
      // sama sekali — tidak meninggalkan jejak apa pun, dan dari layar tampak
      // sama saja dengan aplikasi yang diam begitu saja.
      debugPrint('KAMELSCAN_SPLASH pulihkan sesi GAGAL · $error');
      rethrow;
    }

    if (session == null) {
      debugPrint('KAMELSCAN_SPLASH → login (sesi pulih tetapi kosong)');
      return Routes.login;
    }
    debugPrint('KAMELSCAN_SPLASH sesi siap · role=${session.role.wire}');

    // Antrian unggah dibangunkan begitu aplikasi dibuka. Di iOS ini jalur
    // utamanya, karena BGTaskScheduler tidak menjamin eksekusi (Bab 4.3).
    //
    // ⚠️ Sengaja **tidak ditunggu**. Membangunkan antrian bukan syarat untuk
    // memakai aplikasi; menunggunya berarti satu lagi tempat yang dapat
    // menggantungkan layar splash tanpa alasan yang dapat dijelaskan kepada
    // pengguna.
    if (!kIsWeb) {
      unawaited(ref.read(uploadWorkerProvider).requestImmediateRun());
    }

    return switch (session.role) {
      UserRole.admin => Routes.adminDashboard,
      _ => kIsWeb ? Routes.webDashboard : Routes.home,
    };
  }
}
