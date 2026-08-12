import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/config/env.dart';
import '../pages/account/account_page.dart';
import '../pages/account/packers/packers_page.dart';
import '../pages/admin/dashboard/admin_dashboard_page.dart';
import '../pages/admin/payments/admin_payments_page.dart';
import '../pages/admin/users/admin_users_page.dart';
import '../pages/auth/change_password/change_password_page.dart';
import '../pages/auth/forgot_password/forgot_password_page.dart';
import '../pages/auth/login/login_page.dart';
import '../pages/auth/register/register_page.dart';
import '../pages/auth/verify_email/verify_email_page.dart';
import '../pages/history/detail/video_detail_page.dart';
import '../pages/history/history_page.dart';
import '../pages/home/home_page.dart';
import '../pages/not_found_page.dart';
import '../pages/payment/checkout/checkout_page.dart';
import '../pages/payment/plan_page.dart';
import '../pages/recording/camera/recording_camera_page.dart';
import '../pages/recording/result/recording_result_page.dart';
import '../pages/recording/setup/recording_setup_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/settings/watermark/watermark_page.dart';
import '../pages/shops/form/shop_form_page.dart';
import '../pages/shops/shops_page.dart';
import '../pages/splash/splash_page.dart';
import '../pages/tutorial/tutorial_page.dart';
import '../pages/web/dashboard/web_dashboard_page.dart';
import 'route_guards.dart';
import 'route_names.dart';
import 'shells/mobile_shell.dart';
import 'shells/web_shell.dart';

part 'app_router.g.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Konfigurasi GoRouter (Bab 3.2).
///
/// 🔴 Bab 3.1 poin 5 — navigasi **hanya** lewat GoRouter. Tidak ada
/// `Navigator.push` langsung di dalam widget bisnis.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final guards = RouteGuards(ref);
  final refresh = GoRouterRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.splash,
    debugLogDiagnostics: Env.isDev,
    refreshListenable: refresh,
    // GoRouter 17: lokasi dibaca dari `state.uri`, bukan `state.location`.
    redirect: (context, state) => guards.redirect(state.uri.path),
    errorBuilder: (context, state) => const NotFoundPage(),
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, _) => const SplashPage(),
      ),

      // ---------- Autentikasi ----------
      GoRoute(path: Routes.login, builder: (_, _) => const LoginPage()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterPage()),
      GoRoute(
        path: Routes.verifyEmail,
        // Email dibawa lewat query agar layar ini tetap bisa dibuka kembali
        // dari deep link atau setelah aplikasi di-restart.
        builder: (_, state) => VerifyEmailPage(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: Routes.changePassword,
        builder: (_, _) => const ChangePasswordPage(),
      ),

      // ---------- Perekaman — mobile saja ----------
      //
      // Bab 10.1: menu perekaman tidak boleh sekadar disembunyikan lewat CSS;
      // rutenya memang tidak terdaftar untuk target web.
      if (!kIsWeb) ...[
        GoRoute(
          path: Routes.recordSetup,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, _) => const RecordingSetupPage(),
          routes: [
            GoRoute(
              path: 'camera',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (_, _) => const RecordingCameraPage(),
            ),
            GoRoute(
              path: 'result',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (_, _) => const RecordingResultPage(),
            ),
          ],
        ),
      ],

      // ---------- Admin ----------
      GoRoute(
        path: Routes.adminDashboard,
        builder: (_, _) => const AdminDashboardPage(),
        routes: [
          GoRoute(path: 'users', builder: (_, _) => const AdminUsersPage()),
          GoRoute(
            path: 'payments',
            builder: (_, _) => const AdminPaymentsPage(),
          ),
        ],
      ),

      // ---------- Rangka utama ----------
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => kIsWeb
            ? WebShell(navigationShell: shell)
            : MobileShell(navigationShell: shell),
        branches: [
          // Branch 0 — Beranda (mobile) / Dasbor (web)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: kIsWeb ? Routes.webDashboard : Routes.home,
                builder: (_, _) =>
                    kIsWeb ? const WebDashboardPage() : const HomePage(),
                routes: [
                  GoRoute(
                    path: 'tutorial',
                    builder: (_, _) => const TutorialPage(),
                  ),
                ],
              ),
            ],
          ),

          // Branch 1 — Riwayat
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.history,
                builder: (_, _) => const HistoryPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const VideoDetailPage(),
                  ),
                ],
              ),
            ],
          ),

          // Branch 2 — Toko (Owner)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.shops,
                builder: (_, _) => const ShopsPage(),
                routes: [
                  GoRoute(
                    path: 'form',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const ShopFormPage(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (_, _) => const ShopFormPage(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Branch 3 — Akun, Pengaturan, Pembayaran
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.account,
                builder: (_, _) => const AccountPage(),
                routes: [
                  GoRoute(
                    path: 'packers',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const PackersPage(),
                  ),
                ],
              ),
              GoRoute(
                path: Routes.settings,
                builder: (_, _) => const SettingsPage(),
                routes: [
                  GoRoute(
                    path: 'watermark',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const WatermarkPage(),
                  ),
                ],
              ),
              GoRoute(
                path: Routes.payment,
                builder: (_, _) => const PlanPage(),
                routes: [
                  GoRoute(
                    path: 'checkout',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const CheckoutPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
