import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/utils/app_failure.dart';
import '../../../core/utils/result.dart';

part 'complete_profile_view_model.g.dart';

sealed class CompleteProfileState {
  const CompleteProfileState();
}

class CompleteProfileIdle extends CompleteProfileState {
  const CompleteProfileIdle();
}

class CompleteProfileBusy extends CompleteProfileState {
  const CompleteProfileBusy();
}

class CompleteProfileFailed extends CompleteProfileState {
  const CompleteProfileFailed(this.failure);
  final AppFailure failure;
}

class CompleteProfileDone extends CompleteProfileState {
  const CompleteProfileDone();
}

/// Bab 6.2 — melengkapi nomor HP dan persetujuan S&K yang tidak pernah
/// ditanyakan saat masuk lewat Google.
@riverpod
class CompleteProfileViewModel extends _$CompleteProfileViewModel {
  @override
  CompleteProfileState build() => const CompleteProfileIdle();

  Future<void> submit({String? phone}) async {
    if (state is CompleteProfileBusy) return;
    state = const CompleteProfileBusy();

    final result =
        await ref.read(authRepositoryProvider).completeProfile(phone: phone);

    switch (result) {
      case Err(:final failure):
        state = CompleteProfileFailed(failure);
      case Ok():
        // Muat ulang sesi lebih dulu. Tanpa ini `needsProfileCompletion` masih
        // bernilai lama dan route guard langsung melempar pengguna kembali ke
        // layar yang baru saja ia selesaikan.
        await ref.read(sessionProvider.notifier).reload();
        state = const CompleteProfileDone();
    }
  }

  void clearError() {
    if (state is CompleteProfileFailed) state = const CompleteProfileIdle();
  }
}
