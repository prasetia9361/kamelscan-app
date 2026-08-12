import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/utils/app_failure.dart';
import '../../../core/utils/result.dart';

part 'verify_email_view_model.g.dart';

class VerifyEmailState {
  const VerifyEmailState({
    this.secondsLeft = 0,
    this.sending = false,
    this.justSent = false,
    this.failure,
  });

  /// Sisa hitungan mundur sebelum tombol "Kirim ulang" aktif lagi.
  ///
  /// Bab 6.4 mewajibkan penghitung 60 detik: Supabase Free membatasi ± 3–4
  /// email/jam, dan tanpa jeda pengguna akan menghabiskannya dalam sekejap
  /// lalu mengira aplikasinya rusak.
  final int secondsLeft;
  final bool sending;
  final bool justSent;
  final AppFailure? failure;

  bool get canResend => secondsLeft == 0 && !sending;

  VerifyEmailState copyWith({
    int? secondsLeft,
    bool? sending,
    bool? justSent,
    AppFailure? failure,
    bool clearFailure = false,
  }) =>
      VerifyEmailState(
        secondsLeft: secondsLeft ?? this.secondsLeft,
        sending: sending ?? this.sending,
        justSent: justSent ?? this.justSent,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

@riverpod
class VerifyEmailViewModel extends _$VerifyEmailViewModel {
  Timer? _timer;

  @override
  VerifyEmailState build(String email) {
    ref.onDispose(() => _timer?.cancel());
    // Hitungan mundur dimulai langsung: email pertama baru saja dikirim oleh
    // proses registrasi.
    _startCountdown();
    return const VerifyEmailState(secondsLeft: 60);
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = state.secondsLeft - 1;
      if (left <= 0) {
        t.cancel();
        state = state.copyWith(secondsLeft: 0);
      } else {
        state = state.copyWith(secondsLeft: left);
      }
    });
  }

  Future<void> resend() async {
    if (!state.canResend) return;
    state = state.copyWith(sending: true, justSent: false, clearFailure: true);

    final result =
        await ref.read(authRepositoryProvider).resendVerificationEmail(email);

    state = switch (result) {
      Err(:final failure) => state.copyWith(sending: false, failure: failure),
      Ok() => state.copyWith(sending: false, justSent: true, secondsLeft: 60),
    };
    if (result.isOk) _startCountdown();
  }

  /// Bab 6.4 — "Ganti email" berarti membatalkan pendaftaran ini dan kembali
  /// ke form. Sesi setengah jadi dibersihkan supaya tidak menggantung.
  Future<void> cancelAndSignOut() =>
      ref.read(authRepositoryProvider).signOut();
}
