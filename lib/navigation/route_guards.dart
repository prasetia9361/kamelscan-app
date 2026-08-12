import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/enums.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/session_provider.dart';
import 'route_names.dart';

/// Redirect berdasarkan sesi & role (Bab 3.2).
///
/// ⚠️ Bab 2.3 — ini **lapisan kenyamanan, bukan keamanan**. Penegakan
/// sesungguhnya ada di RLS Supabase. Setiap policy harus tetap aman dengan
/// asumsi penyerang memanggil API langsung tanpa lewat aplikasi.
class RouteGuards {
  const RouteGuards(this._ref);

  final Ref _ref;

  String? redirect(String location) {
    final signedIn = _ref.read(isSignedInProvider);

    // Splash memutuskan tujuannya sendiri setelah sesi selesai dipulihkan.
    if (location == Routes.splash) return null;

    if (!signedIn) {
      return Routes.isPublic(location) ? null : Routes.login;
    }

    // Sudah login tetapi membuka halaman auth — lempar ke beranda.
    if (Routes.isPublic(location) && location != Routes.splash) {
      return _homeFor(_ref.read(currentRoleProvider));
    }

    final role = _ref.read(currentRoleProvider);
    if (role == null) return null; // konteks sesi masih dimuat

    // Bab 10.1 — rute perekaman tidak boleh sekadar disembunyikan di web,
    // rutenya memang tidak terdaftar. Guard ini menangkap deep link manual.
    if (kIsWeb && _isRecordingRoute(location)) {
      return _homeFor(role);
    }

    // Bab 2.2 catatan 2 — Admin tidak punya toko, jalur rekam tidak dibuat.
    if (role == UserRole.admin && _isRecordingRoute(location)) {
      return Routes.adminDashboard;
    }

    // Packer tidak punya menu Toko, Pembayaran, maupun kelola packer.
    if (role == UserRole.packer && _isOwnerOnly(location)) {
      return Routes.home;
    }

    if (role != UserRole.admin && location.startsWith(Routes.adminDashboard)) {
      return _homeFor(role);
    }

    return null;
  }

  static String _homeFor(UserRole? role) => switch (role) {
        UserRole.admin => Routes.adminDashboard,
        _ => kIsWeb ? Routes.webDashboard : Routes.home,
      };

  static bool _isRecordingRoute(String location) =>
      location.startsWith(Routes.recordSetup);

  static bool _isOwnerOnly(String location) =>
      location.startsWith(Routes.shops) ||
      location.startsWith(Routes.payment) ||
      location.startsWith(Routes.packers) ||
      location.startsWith(Routes.watermark);
}

/// Jembatan agar GoRouter ikut menghitung ulang `redirect` saat status login
/// berubah. Tanpa ini, pengguna yang sesinya kedaluwarsa tetap melihat layar
/// terlindungi sampai ia menekan sesuatu.
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(this._ref) {
    _ref.listen(isSignedInProvider, (_, _) => notifyListeners());
    _ref.listen(currentRoleProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}
