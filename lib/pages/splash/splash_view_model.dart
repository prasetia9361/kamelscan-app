import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/models/enums.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../navigation/route_names.dart';

part 'splash_view_model.g.dart';

/// Menentukan tujuan pertama aplikasi setelah sesi & preferensi selesai
/// dipulihkan.
///
/// ViewModel tidak mengimpor `material.dart` (Bab 3.1 poin 2) — ia hanya
/// menghitung path tujuan; navigasinya dikerjakan View lewat GoRouter.
@riverpod
class SplashViewModel extends _$SplashViewModel {
  @override
  Future<String> build() async {
    // Preferensi dimuat lebih dulu agar tema tidak berkedip saat layar
    // pertama tampil.
    await ref.read(appPreferencesProvider.future);

    if (!ref.read(isSignedInProvider)) return Routes.login;

    final session = await ref.read(sessionProvider.future);
    if (session == null) return Routes.login;

    // Antrian upload diproses begitu aplikasi dibuka. Di iOS ini adalah jalur
    // utamanya, karena BGTaskScheduler tidak menjamin eksekusi (Bab 4.3).
    if (!kIsWeb) {
      await ref.read(uploadWorkerProvider).requestImmediateRun();
    }

    return switch (session.role) {
      UserRole.admin => Routes.adminDashboard,
      _ => kIsWeb ? Routes.webDashboard : Routes.home,
    };
  }
}
