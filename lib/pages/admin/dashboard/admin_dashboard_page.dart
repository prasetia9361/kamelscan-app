import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/double_back_exit.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../navigation/route_names.dart';
import '../../account/widgets/logout_button.dart';
import '../payments/admin_payments_view_model.dart';

/// Halaman pembuka panel Admin (Bab 11).
///
/// 🔴 Isinya sengaja **menu**, bukan ringkasan angka. Alasannya bukan
/// kesederhanaan: sampai 28 Agustus 2026 halaman ini hanya placeholder, dan
/// akibatnya seluruh panel admin **tidak dapat dicapai sama sekali**. Halaman
/// Verifikasi Pembayaran sudah selesai dibangun tetapi tidak ada satu pun
/// tautan menuju ke sana — hanya dapat dibuka dengan mengetik alamatnya.
///
/// 🔴 Tombol **Keluar** wajib ada di sini, dan itu temuan yang lebih penting
/// daripada menunya. Rute admin berdiri di luar rangka aplikasi, jadi tidak
/// ada menu bawah maupun sidebar; sementara `RouteGuards` melempar siapa pun
/// yang sudah masuk kembali ke beranda perannya. Tanpa tombol ini, seseorang
/// yang masuk sebagai admin **terkurung** — tidak dapat keluar, dan tidak
/// dapat kembali ke akunnya sendiri tanpa membersihkan simpanan peramban.
/// Terjadi sungguhan pada Product Owner, 28 Agustus 2026.
///
/// Ringkasan angka platform (Bab 11.1) berdiri sebagai halaman tersendiri,
/// bukan di sini. Alasannya bukan tata letak: halaman ini dibuka setiap kali
/// admin masuk, sedangkan angka itu menghitung seluruh baris `package_videos`
/// di platform — pekerjaan yang tidak boleh dijalankan hanya karena seseorang
/// lewat.
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final menunggu = ref.watch(adminPaymentsViewModelProvider);

    // Tombol Kembali perangkat: keluar aplikasi butuh dua ketukan
    // (keluhan Product Owner 5 September 2026).
    //
    // 🔴 Dipasang di sini juga, bukan hanya di rangka mobile. Rute admin
    // berdiri DI LUAR rangka — alasan yang sama yang dulu membuat tombol
    // Keluar wajib ada di halaman ini — sehingga halaman ini adalah rute
    // paling bawah bagi seorang admin, dan satu ketukan Kembali di sini
    // menutup aplikasi persis seperti di Beranda.
    //
    // ⚠️ Sub-halaman admin dibuka dengan `context.go`, yang tetap menyusun
    // /admin di bawahnya. Jadi Kembali dari Kelola Pengguna memulangkan ke
    // halaman ini lebih dulu, bukan langsung menutup aplikasi.
    return DoubleBackToExit(
      child: Scaffold(
        appBar: AppBar(title: Text(t.navAdmin)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _MenuAdmin(
                icon: Icons.fact_check_outlined,
                title: t.adminPaymentsTitle,
                // Jumlahnya ditulis di menunya, bukan hanya di dalam halaman.
                // Inilah satu-satunya pekerjaan admin yang punya tenggat: uang
                // sudah masuk ke rekening dan pelanggannya sedang menunggu.
                subtitle: menunggu.when(
                  loading: () => t.commonLoading,
                  error: (_, _) => t.errorUnknown,
                  data: (d) => d.isEmpty
                      ? t.dashboardPendingNone
                      : t.adminPendingCount(Formatters.number(d.length)),
                ),
                badge: menunggu.value?.length ?? 0,
                onTap: () => context.go(Routes.adminPayments),
              ),
              const SizedBox(height: 12),

              _MenuAdmin(
                icon: Icons.query_stats_outlined,
                title: t.adminStatsTitle,
                subtitle: t.adminStatsMenuSubtitle,
                onTap: () => context.go(Routes.adminStats),
              ),
              const SizedBox(height: 12),

              // 🔴 SATU menu, bukan dua. Sampai 29 Agustus 2026 di sini berdiri
              // "Kelola Pengguna" dan "Daftar Pelanggan" — keduanya karangan
              // saya, bukan dari dokumen. Bab 11.2 hanya menyebut satu halaman:
              // tabel seluruh pelanggan beserta tombol aksinya.
              //
              // Menu yang tidak ada di spesifikasi membuat orang berikutnya
              // membangun dua halaman untuk pekerjaan yang satu.
              _MenuAdmin(
                icon: Icons.group_outlined,
                title: t.adminMenuUsers,
                subtitle: t.adminUsersMenuSubtitle,
                onTap: () => context.go(Routes.adminUsers),
              ),
              const SizedBox(height: 12),

              // Berdiri di kelompok atas bersama menu yang menyentuh orang,
              // bukan di Pengaturan Platform — yang diurus di sini akun
              // seseorang, bukan aturan yang berlaku bagi semua.
              _MenuAdmin(
                icon: Icons.admin_panel_settings_outlined,
                title: t.adminNewAdminTitle,
                subtitle: t.adminNewAdminMenuSubtitle,
                onTap: () => context.go(Routes.adminNewAdmin),
              ),

              // 🔴 Batas antara dua jenis pekerjaan yang berbeda, dan bukan
              // hiasan. Menu di ATAS mengubah SATU pelanggan; menu di BAWAH
              // mengubah aturan yang berlaku bagi SELURUH pelanggan sekaligus.
              //
              // Keempatnya sengaja ditunda ke Fase 2 saat MVP disusun (Bab 11,
              // "Keputusan lingkup MVP") dan dikerjakan lewat Supabase Dashboard
              // — antarmuka teknis berbahasa Inggris berupa tabel database.
              // Selesai 29 Agustus 2026, sehari sebelum integrasi Midtrans.
              const SizedBox(height: 24),
              _JudulKelompok(t.adminGroupPlatform),
              const SizedBox(height: 8),

              _MenuAdmin(
                icon: Icons.sell_outlined,
                title: t.adminPricingTitle,
                subtitle: t.adminPricingMenuSubtitle,
                onTap: () => context.go(Routes.adminPricing),
              ),
              const SizedBox(height: 12),

              // Ditaruh sebelum Promo dengan sengaja: inilah satu-satunya menu
              // yang dapat menghentikan seluruh pendapatan bila salah disetel,
              // dan yang paling sering dibuka menjelang Midtrans dinyalakan.
              _MenuAdmin(
                icon: Icons.account_balance_wallet_outlined,
                title: t.adminMethodsTitle,
                subtitle: t.adminMethodsMenuSubtitle,
                onTap: () => context.go(Routes.adminPaymentMethods),
              ),
              const SizedBox(height: 12),

              _MenuAdmin(
                icon: Icons.local_offer_outlined,
                title: t.adminPromosTitle,
                subtitle: t.adminPromosMenuSubtitle,
                onTap: () => context.go(Routes.adminPromos),
              ),
              const SizedBox(height: 12),

              _MenuAdmin(
                icon: Icons.support_agent_outlined,
                title: t.adminContactTitle,
                subtitle: t.adminContactMenuSubtitle,
                onTap: () => context.go(Routes.adminContact),
              ),
              const SizedBox(height: 12),

              // Bab 9.9 — utang paling lama di proyek ini, dijadwalkan Product
              // Owner 3 September 2026. Tabelnya ada sejak migrasi 10; yang
              // selama ini kurang hanyalah layarnya.
              _MenuAdmin(
                icon: Icons.ondemand_video_outlined,
                title: t.adminTutorialsTitle,
                subtitle: t.adminTutorialsMenuSubtitle,
                onTap: () => context.go(Routes.adminTutorials),
              ),
              const SizedBox(height: 12),

              // Bab 11.5 — utang nomor 3 daftar kesiapan produksi. Bucket-nya
              // baru lahir di migrasi 46; sampai itu gambar iklan hanya dapat
              // diganti lewat Supabase Dashboard.
              _MenuAdmin(
                icon: Icons.image_outlined,
                title: t.adminBannersTitle,
                subtitle: t.adminBannersMenuSubtitle,
                onTap: () => context.go(Routes.adminBanners),
              ),
              const SizedBox(height: 12),

              // Migrasi 50 — diminta Product Owner 5 September 2026.
              //
              // 🔴 Satu-satunya menu di halaman ini yang dapat MENGUNCI
              // seluruh pengguna sekaligus: pengumuman berjenis penting
              // menahan aplikasi sampai mereka memperbaruinya. Itu memang
              // gunanya, dan itu pula alasan tombol nonaktifnya ada di
              // tiap baris daftar.
              _MenuAdmin(
                icon: Icons.campaign_outlined,
                title: t.adminAnnouncementsTitle,
                subtitle: t.adminAnnouncementsMenuSubtitle,
                onTap: () => context.go(Routes.adminAnnouncements),
              ),

              const SizedBox(height: 28),
              // Bab 9.6 butir 6 — Keluar berwarna merah dan selalu meminta
              // konfirmasi. Dipakai ulang apa adanya dari halaman Akun supaya
              // peringatan antrean unggah (Bab 8.7) tidak perlu ditulis dua kali.
              const LogoutButton(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Judul pemisah antar kelompok menu.
class _JudulKelompok extends StatelessWidget {
  const _JudulKelompok(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        teks,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _MenuAdmin extends StatelessWidget {
  const _MenuAdmin({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// Jumlah yang menunggu. 0 berarti tidak ada lencana.
  final int badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;

    // Sampai 29 Agustus 2026 widget ini punya keadaan `enabled: false` yang
    // meredupkan menu "Belum dikerjakan". Sejak Kelola Pengguna selesai, tidak
    // ada lagi menu yang belum jadi — dan keadaan yang tidak dipakai siapa pun
    // adalah jalur yang tidak pernah dilihat mata, jadi ia dibuang.
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: scheme.primary),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: badge > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.warning,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  Formatters.number(badge),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimary,
                  ),
                ),
              )
            : const Icon(Icons.chevron_right),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      ),
    );
  }
}
