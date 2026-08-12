import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/utils/app_failure.dart';
import '../../../core/utils/result.dart';

part 'change_password_view_model.g.dart';

class ChangePasswordState {
  const ChangePasswordState({
    this.busy = false,
    this.done = false,
    this.failure,
  });

  final bool busy;
  final bool done;
  final AppFailure? failure;
}

@riverpod
class ChangePasswordViewModel extends _$ChangePasswordViewModel {
  @override
  ChangePasswordState build() => const ChangePasswordState();

  /// Bab 6.7 — true bila pengguna adalah packer yang masih memakai password
  /// sementara. Dalam keadaan ini layar tidak boleh bisa ditinggalkan.
  bool get isForced => ref.read(authRepositoryProvider).mustChangePassword;

  /// Bab 6.8 — password lama diverifikasi ulang lebih dulu di dalam
  /// repository. Tanpa itu, siapa pun yang menemukan HP tidak terkunci bisa
  /// mengambil alih akun.
  Future<void> submit({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (state.busy) return;
    state = const ChangePasswordState(busy: true);

    final result = await ref.read(authRepositoryProvider).changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );

    state = switch (result) {
      Err(:final failure) => ChangePasswordState(failure: failure),
      Ok() => const ChangePasswordState(done: true),
    };

    // JWT membawa metadata lama sampai disegarkan (Bab 5.3), termasuk flag
    // must_change_password yang baru saja dihapus.
    if (result.isOk) {
      await ref.read(authRepositoryProvider).refreshSession();
    }
  }
}
