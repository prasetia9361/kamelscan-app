import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/utils/app_failure.dart';
import '../../../core/utils/result.dart';

part 'login_view_model.g.dart';

/// Hasil satu percobaan masuk.
///
/// Sengaja bukan `AsyncValue<void>`: layar perlu membedakan "belum mencoba"
/// dari "berhasil", dan `AsyncData(null)` tidak bisa membedakan keduanya.
sealed class LoginState {
  const LoginState();
}

class LoginIdle extends LoginState {
  const LoginIdle();
}

class LoginBusy extends LoginState {
  const LoginBusy();
}

class LoginFailed extends LoginState {
  const LoginFailed(this.failure);
  final AppFailure failure;
}

/// Berhasil masuk. [mustChangePassword] menandai packer yang masih memakai
/// password sementara (Bab 6.7).
class LoginSucceeded extends LoginState {
  const LoginSucceeded({required this.mustChangePassword});
  final bool mustChangePassword;
}

@riverpod
class LoginViewModel extends _$LoginViewModel {
  @override
  LoginState build() => const LoginIdle();

  /// Menerima email **atau** username pada satu kolom (Bab 6.1 & 6.6).
  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    if (state is LoginBusy) return; // cegah tekan ganda
    state = const LoginBusy();

    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signInWithIdentifier(
      identifier: identifier,
      password: password,
    );

    state = switch (result) {
      Err(:final failure) => LoginFailed(failure),
      Ok() => LoginSucceeded(mustChangePassword: repo.mustChangePassword),
    };
  }

  Future<void> signInWithGoogle() async {
    if (state is LoginBusy) return;
    state = const LoginBusy();

    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signInWithGoogle();

    state = switch (result) {
      Err(:final failure) => LoginFailed(failure),
      // Di web, `signInWithOAuth` mengalihkan halaman; kode setelahnya tidak
      // pernah berjalan. Di mobile, sesi sudah terbentuk saat sampai sini.
      Ok() => LoginSucceeded(mustChangePassword: repo.mustChangePassword),
    };
  }

  /// Dipanggil saat pengguna mulai mengetik lagi, agar kotak error hilang
  /// tanpa perlu menekan apa pun.
  void clearError() {
    if (state is LoginFailed) state = const LoginIdle();
  }
}
