import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../utils/app_failure.dart';
import 'repository_providers.dart';

part 'auth_provider.g.dart';

/// Sumber kebenaran status login (Bab 3.2).
///
/// GoRouter mendengarkan provider ini untuk `redirect` (lihat
/// `navigation/route_guards.dart`). Jangan membaca `Supabase.instance` langsung
/// di widget — nilainya tidak memicu rebuild.
@Riverpod(keepAlive: true)
Stream<AuthState> authStateChanges(Ref ref) =>
    ref.watch(authRepositoryProvider).onAuthStateChange;

/// `true` bila ada sesi aktif. Ikut berubah saat token kedaluwarsa atau
/// pengguna keluar dari perangkat lain.
@Riverpod(keepAlive: true)
bool isSignedIn(Ref ref) {
  final state = ref.watch(authStateChangesProvider);
  return state.maybeWhen(
    data: (value) => value.session != null,
    // Sebelum event pertama tiba, pakai sesi yang sudah dipulihkan dari
    // penyimpanan aman saat startup.
    orElse: () => ref.read(authRepositoryProvider).isSignedIn,
  );
}

/// Bab 6.7 — packer yang dibuatkan Owner memakai password sementara dan
/// **wajib** menggantinya sebelum boleh memakai aplikasi.
///
/// Nilainya berasal dari `user_metadata`, yang ikut berubah setelah
/// `refreshSession()` dipanggil pasca-penggantian.
@Riverpod(keepAlive: true)
bool mustChangePassword(Ref ref) {
  ref.watch(authStateChangesProvider);
  return ref.read(authRepositoryProvider).mustChangePassword;
}

/// Bab 6.8 — pengguna tiba lewat tautan *Lupa password* dan belum menyimpan
/// password barunya.
///
/// Sumbernya sebuah `ValueNotifier` di `SupabaseService`, bukan aliran
/// autentikasi, karena tautannya dapat tiba sebelum provider mana pun sempat
/// lahir. Alasan lengkapnya ada di sana.
///
/// ⚠️ Sengaja membaca `SupabaseService` **langsung**, tidak lewat Repository.
/// Ini penanda sepanjang umur proses milik batas SDK, bukan data sesi — dan
/// menariknya lewat `authRepositoryProvider` akan menyeret seluruh rantai
/// klien Supabase ikut hidup setiap kali route guard menghitung tujuan,
/// termasuk di dalam tes yang tidak pernah menginisialisasi Supabase.
@Riverpod(keepAlive: true)
class PasswordResetPending extends _$PasswordResetPending {
  @override
  bool build() {
    final source = SupabaseService.passwordResetPending;
    void sinkron() => state = source.value;
    source.addListener(sinkron);
    ref.onDispose(() => source.removeListener(sinkron));
    return source.value;
  }

  /// Dipanggil setelah password baru tersimpan atau pemulihan dibatalkan.
  void finish() => SupabaseService.passwordResetPending.value = false;
}

/// Kegagalan yang datang dari tautan email (kedaluwarsa, sudah terpakai,
/// dibuka di perangkat lain). Layar Masuk menampilkannya sekali lalu
/// membersihkannya.
@Riverpod(keepAlive: true)
class AuthLinkFailure extends _$AuthLinkFailure {
  @override
  AppFailure? build() {
    final source = SupabaseService.authLinkFailure;
    void sinkron() => state = source.value;
    source.addListener(sinkron);
    ref.onDispose(() => source.removeListener(sinkron));
    return source.value;
  }

  void clear() => SupabaseService.authLinkFailure.value = null;
}

@Riverpod(keepAlive: true)
String? currentUserId(Ref ref) {
  // Bergantung pada isSignedIn agar ikut diperbarui saat sesi berubah.
  ref.watch(isSignedInProvider);
  return ref.read(authRepositoryProvider).currentUserId;
}
