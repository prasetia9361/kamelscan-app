import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/utils/app_failure.dart';
import '../../../core/utils/result.dart';

part 'forgot_password_view_model.g.dart';

class ForgotPasswordState {
  const ForgotPasswordState({
    this.sending = false,
    this.sent = false,
    this.failure,
  });

  final bool sending;
  final bool sent;
  final AppFailure? failure;
}

@riverpod
class ForgotPasswordViewModel extends _$ForgotPasswordViewModel {
  @override
  ForgotPasswordState build() => const ForgotPasswordState();

  /// Bab 6.8 — **selalu** tampilkan pesan sukses, bahkan bila email tidak
  /// terdaftar. Membedakan keduanya mengubah layar ini menjadi alat untuk
  /// memeriksa email siapa saja yang menjadi pelanggan (*user enumeration*).
  Future<void> submit(String email) async {
    if (state.sending) return;
    state = const ForgotPasswordState(sending: true);

    final result =
        await ref.read(authRepositoryProvider).sendPasswordReset(email);

    state = switch (result) {
      // Hanya kegagalan jaringan yang ditampilkan; selebihnya tetap "terkirim".
      Err(:final failure) when failure.kind == FailureKind.network =>
        ForgotPasswordState(failure: failure),
      _ => const ForgotPasswordState(sent: true),
    };
  }
}
