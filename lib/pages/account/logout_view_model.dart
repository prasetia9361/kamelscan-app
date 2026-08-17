import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_constants.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/utils/app_failure.dart';
import '../../core/utils/result.dart';

part 'logout_view_model.g.dart';

sealed class LogoutState {
  const LogoutState();
}

class LogoutIdle extends LogoutState {
  const LogoutIdle();
}

class LogoutBusy extends LogoutState {
  const LogoutBusy();
}

class LogoutFailed extends LogoutState {
  const LogoutFailed(this.failure);
  final AppFailure failure;
}

/// Bab 6.8 — keluar dari akun.
///
/// Layar tidak menavigasi sendiri. Begitu sesi hilang, `isSignedInProvider`
/// berubah, `GoRouterRefreshNotifier` menghitung ulang `redirect`, dan
/// `RouteGuards` yang memindahkan pengguna ke layar Masuk. Menavigasi manual di
/// sini berarti ada dua pihak yang mengatur tujuan.
@riverpod
class LogoutViewModel extends _$LogoutViewModel {
  @override
  LogoutState build() => const LogoutIdle();

  Future<void> signOut() async {
    if (state is LogoutBusy) return;
    state = const LogoutBusy();

    final result = await ref.read(authRepositoryProvider).signOut();

    if (result case Err(:final failure)) {
      // `ref.mounted` — sesi yang gagal ditutup membuat layar Akun tetap
      // terpasang, tetapi pemeriksaan ini tetap perlu bila pengguna sempat
      // berpindah tab sebelum jawabannya tiba.
      if (ref.mounted) state = LogoutFailed(failure);
      return;
    }

    await _clearUserScopedCache();

    if (ref.mounted) state = const LogoutIdle();
  }

  void clearError() {
    if (state is LogoutFailed) state = const LogoutIdle();
  }

  /// Bab 6.8 — *"Bersihkan cache lokal, tetapi jangan hapus antrian upload yang
  /// belum terkirim"*.
  ///
  /// 🔴 Antrian ada di SQLite (`upload_queue`), bukan di `SharedPreferences`,
  /// jadi ia tidak tersentuh di sini. Jangan sekali-kali mengganti ini dengan
  /// `prefs.clear()` — Bab 8.7: video yang belum terkirim adalah bukti
  /// pelanggan, dan menghapusnya berarti menghilangkannya permanen.
  ///
  /// Yang dihapus hanya jejak milik pengguna yang baru saja keluar:
  ///
  /// - `prefLastShopId` — toko milik tenant lama; bila pengguna berikutnya
  ///   berasal dari tenant lain, layar setup akan memilih toko yang tidak
  ///   dapat ia akses.
  /// - `prefRecentResi` — lima nomor resi terakhir. Ini data paket pelanggan
  ///   orang lain dan tidak boleh terbaca oleh packer berikutnya.
  ///
  /// Yang **sengaja dipertahankan** karena milik perangkat, bukan milik akun:
  /// tema, bahasa, mode pemicu, dan penanda onboarding sudah pernah dilihat.
  Future<void> _clearUserScopedCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefLastShopId);
    await prefs.remove(AppConstants.prefRecentResi);
  }
}
