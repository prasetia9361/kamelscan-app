import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/config/env.dart';
import '../core/models/enums.dart';
import '../pages/account/account_page.dart';
import '../pages/account/delete_account_page.dart';
import '../pages/account/deletion_pending_page.dart';
import '../pages/account/edit_profile/edit_profile_page.dart';
import '../pages/account/packers/packers_page.dart';
import '../pages/admin/dashboard/admin_dashboard_page.dart';
import '../pages/admin/dashboard/admin_stats_page.dart';
import '../pages/admin/payments/admin_payments_page.dart';
import '../pages/admin/settings/admin_contact_page.dart';
import '../pages/admin/settings/admin_new_admin_page.dart';
import '../pages/admin/settings/admin_payment_methods_page.dart';
import '../pages/admin/settings/admin_pricing_page.dart';
import '../pages/admin/settings/admin_promos_page.dart';
import '../pages/admin/users/admin_users_page.dart';
import '../pages/auth/callback/auth_callback_page.dart';
import '../pages/auth/change_password/change_password_page.dart';
import '../pages/auth/complete_profile/complete_profile_page.dart';
import '../pages/auth/forgot_password/forgot_password_page.dart';
import '../pages/auth/login/login_page.dart';
import '../pages/auth/register/register_page.dart';
import '../pages/auth/reset_password/reset_password_page.dart';
import '../pages/auth/verify_email/verify_email_page.dart';
import '../pages/history/detail/video_detail_page.dart';
import '../pages/history/history_page.dart';
import '../pages/home/home_page.dart';
import '../pages/not_found_page.dart';
import '../pages/payment/checkout/checkout_page.dart';
import '../pages/payment/payment_access.dart';
import '../pages/payment/plan_page.dart';
import '../pages/public/public_video_page.dart';
import '../pages/recording/camera/recording_camera_page.dart';
import '../pages/recording/setup/recording_setup_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/shops/form/shop_form_page.dart';
import '../pages/shops/shops_page.dart';
import '../pages/splash/splash_page.dart';
import '../pages/tutorial/tutorial_page.dart';
import '../pages/web/dashboard/web_dashboard_page.dart';
import '../pages/web/history/web_history_page.dart';
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
      GoRoute(
        path: Routes.completeProfile,
        builder: (_, _) => const CompleteProfilePage(),
      ),

      // Bab 9.6 — layar kunci akun yang menunggu dimusnahkan.
      //
      // Di luar `StatefulShellRoute` dengan sengaja: bilah tab di bawah
      // menuju layar-layar yang justru sedang dikunci penjaga rute.
      GoRoute(
        path: Routes.deletionPending,
        builder: (_, _) => const DeletionPendingPage(),
      ),
      GoRoute(
        path: Routes.resetPassword,
        builder: (_, _) => const ResetPasswordPage(),
      ),

      // 🔴 Tempat peramban mendarat sesudah tautan email ditekan di web
      // (Bab 10). Tanpa rute ini alamatnya jatuh ke `errorBuilder`, dan
      // pengguna tersangkut di layar "halaman tidak ditemukan" tanpa jalan
      // keluar — uraiannya di `Routes.authCallback`.
      GoRoute(
        path: Routes.authCallback,
        builder: (_, _) => const AuthCallbackPage(),
      ),

      // Halaman bukti publik — dibuka tanpa login oleh pusat resolusi
      // marketplace (Bab 10.6). `RouteGuards.isPublic` sudah mengizinkan
      // seluruh alamat berawalan `/v/`, jadi ia tidak pernah dialihkan ke
      // layar masuk.
      GoRoute(
        path: Routes.publicVideo,
        builder: (_, state) => PublicVideoPage(
          token: state.pathParameters['token'] ?? '',
        ),
      ),

      // ---------- Perekaman — mobile saja ----------
      //
      // Bab 10.1: menu perekaman tidak boleh sekadar disembunyikan lewat CSS;
      // rutenya memang tidak terdaftar untuk target web.
      if (!kIsWeb) ...[
        GoRoute(
          path: Routes.recordSetup,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, state) => RecordingSetupPage(
            typeWire:
                state.uri.queryParameters['type'] ?? VideoType.packing.wire,
          ),
          routes: [
            GoRoute(
              path: 'camera',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (_, state) {
                final q = state.uri.queryParameters;
                return RecordingCameraPage(
                  cameraName: q['camera'] ?? '',
                  triggerWire: q['mode'] ?? TriggerMode.qrCode.wire,
                  shopId: q['shop'] ?? '',
                  // Tanpa tipe, `fromWire` jatuh ke `packing` — bawaan yang
                  // sama dengan layar setup, sehingga rute lama tanpa parameter
                  // ini tetap berperilaku seperti sebelumnya.
                  typeWire: q['type'] ?? VideoType.packing.wire,
                  shopName: q['shop_name'] ?? '',
                );
              },
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
          GoRoute(
            path: 'stats',
            builder: (_, _) => const AdminStatsPage(),
          ),
          GoRoute(
            path: 'pricing',
            builder: (_, _) => const AdminPricingPage(),
          ),
          GoRoute(path: 'promos', builder: (_, _) => const AdminPromosPage()),
          GoRoute(
            path: 'payment-methods',
            builder: (_, _) => const AdminPaymentMethodsPage(),
          ),
          GoRoute(
            path: 'contact',
            builder: (_, _) => const AdminContactPage(),
          ),
          GoRoute(
            path: 'new-admin',
            builder: (_, _) => const AdminNewAdminPage(),
          ),
        ],
      ),

      // ---------- Rangka utama ----------
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => kIsWeb
            ? WebShell(navigationShell: shell, location: state.uri.path)
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
                  // Tutorial di HP hidup di bawah Beranda: dibuka dari sana,
                  // punya tombol kembali, dan menu bawah tetap menyala di
                  // Beranda. Di web ia menjadi cabang tersendiri — lihat
                  // cabang 5 di bawah dan `Routes.homeTutorial`.
                  if (!kIsWeb)
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
                // Filter jenis dibawa di query oleh kartu Beranda yang
                // ditekan (Bab 9.2). Kosong berarti tanpa penyaringan.
                // 🔴 Dua halaman untuk satu alamat, dan itu disengaja
                // (Bab 10.5). Keduanya membaca tabel dan filter yang sama,
                // tetapi bentuknya berbeda secara mendasar: HP memakai gulir
                // tak berujung, web memakai tabel berhalaman bernomor yang
                // wajib tahu jumlah total barisnya. Memaksa satu halaman
                // melayani keduanya berarti HP ikut menanggung perhitungan
                // `count` pada tiap gulir, di jaringan gudang, untuk angka
                // yang tidak pernah ditampilkan di sana.
                builder: (_, state) => kIsWeb
                    ? WebHistoryPage(
                        typeWire: state.uri.queryParameters['type'] ?? '',
                        initialQuery: state.uri.queryParameters['q'],
                      )
                    : HistoryPage(
                        typeWire: state.uri.queryParameters['type'] ?? '',
                        // Bab 10.3 — kolom *Cari resi* di bilah atas web
                        // mendarat di sini. Kosong berarti dibuka lewat menu
                        // biasa.
                        initialQuery: state.uri.queryParameters['q'] ?? '',
                      ),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, state) => VideoDetailPage(
                      videoId: state.pathParameters['id'] ?? '',
                    ),
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
                    // Tanpa `:id` berarti menambah toko baru.
                    builder: (_, _) => const ShopFormPage(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (_, state) => ShopFormPage(
                          shopId: state.pathParameters['id'] ?? '',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Branch 3 — Akun & Pembayaran
          //
          // Pembayaran sengaja menumpang di sini, bukan menjadi tab sendiri:
          // ia dicapai dari kartu token di Beranda dan dari baris Pro di
          // Pengaturan, bukan sebagai tempat yang dikunjungi rutin.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.account,
                builder: (_, _) => const AccountPage(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const EditProfilePage(),
                  ),
                  GoRoute(
                    path: 'packers',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const PackersPage(),
                  ),
                  GoRoute(
                    path: 'delete',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const DeleteAccountPage(),
                  ),
                ],
              ),
              GoRoute(
                path: Routes.payment,
                builder: (_, _) => const PlanPage(),
                routes: [
                  // 🔴 Bab 12.5 — halaman Checkout TIDAK didaftarkan di HP.
                  //
                  // Google Play dan Apple App Store mewajibkan pembelian dalam
                  // aplikasi untuk konten digital; melewatkannya berisiko
                  // aplikasi ditolak saat review, tepat di akhir proyek.
                  // Keputusan Product Owner 30 Agustus 2026: di HP paketnya
                  // tetap terlihat, pembayarannya diselesaikan di dasbor web.
                  //
                  // Rutenya dibuang, bukan sekadar tombolnya disembunyikan —
                  // alamat yang masih hidup dapat dicapai dengan mengetiknya,
                  // dan itu persis yang diperiksa saat review.
                  if (PaymentAccess.canPayHere)
                    GoRoute(
                      path: 'checkout',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (_, _) => const CheckoutPage(),
                    ),
                ],
              ),
            ],
          ),

          // Branch 4 — Pengaturan
          //
          // 🔴 Harus berdiri sebagai cabang **sendiri**, bukan menumpang di
          // cabang Akun seperti sebelumnya. Dua tab yang berbagi satu cabang
          // saling menimpa: menekan Pengaturan lalu Akun akan menampilkan
          // halaman yang sama, dan riwayat navigasi keduanya bercampur.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (_, _) => const SettingsPage(),
              ),
            ],
          ),

          // Branch 5 — Tutorial, **web saja** (Bab 10.3).
          //
          // 🔴 Sengaja cabang terakhir. `MobileShell.branchesFor` memetakan
          // tombol menu bawah ke nomor cabang 0–4 secara tetap; menyisipkan
          // cabang baru di tengah akan menggeser seluruh peta itu, dan
          // gejalanya packer yang menekan Riwayat mendarat di halaman lain —
          // kesalahan yang tidak menimbulkan error apa pun.
          //
          // Di HP cabang ini tidak ada sama sekali, jadi peta itu tetap utuh.
          if (kIsWeb)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: Routes.tutorial,
                  builder: (_, _) => const TutorialPage(),
                ),
              ],
            ),
        ],
      ),
    ],
  );
}
