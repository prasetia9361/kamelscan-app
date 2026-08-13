import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/utils/app_failure.dart';
import '../../../core/utils/result.dart';

part 'register_view_model.g.dart';

sealed class RegisterState {
  const RegisterState();
}

class RegisterIdle extends RegisterState {
  const RegisterIdle();
}

class RegisterBusy extends RegisterState {
  const RegisterBusy();
}

class RegisterFailed extends RegisterState {
  const RegisterFailed(this.failure);
  final AppFailure failure;
}

/// Registrasi diterima server.
///
/// [needsEmailVerification] hampir selalu true: Supabase mengembalikan sesi
/// kosong selama "Confirm email" masih menyala (Bab 6.4).
class RegisterSucceeded extends RegisterState {
  const RegisterSucceeded({
    required this.email,
    required this.needsEmailVerification,
  });

  final String email;
  final bool needsEmailVerification;
}

@riverpod
class RegisterViewModel extends _$RegisterViewModel {
  @override
  RegisterState build() => const RegisterIdle();

  /// Bab 6.2 — seluruh pembentukan tenant, dompet uji coba, dan pengaturan
  /// dikerjakan trigger `handle_new_user` di server. Klien hanya mengirim
  /// metadata; ia tidak pernah menulis ke tabel aplikasi.
  Future<void> submit({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    String? username,
    String? businessName,
  }) async {
    if (state is RegisterBusy) return;
    state = const RegisterBusy();

    final repo = ref.read(authRepositoryProvider);

    // Bab 6.2 — username wajib unik. Diperiksa DI SINI, sebelum signUp.
    //
    // Bila dibiarkan sampai server, pelanggarannya terjadi di dalam trigger
    // `handle_new_user` dan GoTrue membungkusnya menjadi
    // "Database error saving new user" — pesan yang tidak menyebut username
    // sama sekali. Pengguna lalu menatap formulir tanpa tahu kolom mana yang
    // bermasalah. Terjadi sungguhan saat uji perangkat 13 Agustus 2026.
    final wanted = username?.trim() ?? '';
    if (wanted.isNotEmpty) {
      final check = await repo.isUsernameAvailable(wanted);
      switch (check) {
        case Err(:final failure):
          state = RegisterFailed(failure);
          return;
        case Ok(value: false):
          state = RegisterFailed(
            AppFailure.validation('validationUsernameTaken'),
          );
          return;
        case Ok():
          break;
      }
    }

    final result = await repo.signUp(
          email: email,
          password: password,
          fullName: fullName,
          phone: phone,
          username: username,
          businessName: businessName,
        );

    state = switch (result) {
      Err(:final failure) => RegisterFailed(failure),
      Ok(:final value) => RegisterSucceeded(
          email: value.email,
          needsEmailVerification: value.needsEmailVerification,
        ),
    };
  }

  void clearError() {
    if (state is RegisterFailed) state = const RegisterIdle();
  }
}
