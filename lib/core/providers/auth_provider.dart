import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

@Riverpod(keepAlive: true)
String? currentUserId(Ref ref) {
  // Bergantung pada isSignedIn agar ikut diperbarui saat sesi berubah.
  ref.watch(isSignedInProvider);
  return ref.read(authRepositoryProvider).currentUserId;
}
