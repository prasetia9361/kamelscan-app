import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/utils/app_failure.dart';
import '../../../core/utils/result.dart';

part 'reset_password_view_model.g.dart';

class ResetPasswordState {
  const ResetPasswordState({
    this.busy = false,
    this.done = false,
    this.failure,
  });

  final bool busy;
  final bool done;
  final AppFailure? failure;
}

/// Bab 6.8 — layar terakhir alur *Lupa password*.
///
/// Berbeda dari layar Ganti Password, di sini password lama **tidak**
/// ditanyakan: pengguna sampai ke layar ini justru karena tidak mengingatnya.
/// Yang menggantikan verifikasi itu adalah tautan sekali pakai dari emailnya
/// sendiri, yang sudah ditukar menjadi sesi sebelum layar ini terbuka.
@riverpod
class ResetPasswordViewModel extends _$ResetPasswordViewModel {
  @override
  ResetPasswordState build() => const ResetPasswordState();

  Future<void> submit(String newPassword) async {
    if (state.busy) return;
    state = const ResetPasswordState(busy: true);

    final result =
        await ref.read(authRepositoryProvider).updatePassword(newPassword);

    switch (result) {
      case Err(:final failure):
        state = ResetPasswordState(failure: failure);
      case Ok():
        // Penandanya dipadamkan lebih dulu, baru layarnya menyatakan selesai.
        // Bila urutannya terbalik, route guard masih melihat pemulihan yang
        // "belum selesai" dan mengembalikan pengguna ke layar yang baru saja
        // ia tuntaskan — persis jebakan yang sudah pernah terjadi di layar
        // Lengkapi Profil.
        ref.read(passwordResetPendingProvider.notifier).finish();
        state = const ResetPasswordState(done: true);
    }
  }

  /// Membatalkan pemulihan: sesi dari tautan dibuang dan pengguna kembali ke
  /// layar Masuk.
  ///
  /// 🔴 Layar ini wajib punya jalan keluar. Layar paksa tanpa jalan keluar
  /// sudah pernah membuat aplikasi harus ditutup paksa (Lengkapi Profil,
  /// 24 Agustus 2026) — jangan diulang.
  Future<void> cancel() async {
    ref.read(passwordResetPendingProvider.notifier).finish();
    await ref.read(authRepositoryProvider).signOut();
  }
}
