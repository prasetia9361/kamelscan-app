import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
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

    return Scaffold(
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
              subtitle: t.adminNotYetBuilt,
              enabled: false,
              onTap: null,
            ),

            const SizedBox(height: 28),
            // Bab 9.6 butir 6 — Keluar berwarna merah dan selalu meminta
            // konfirmasi. Dipakai ulang apa adanya dari halaman Akun supaya
            // peringatan antrean unggah (Bab 8.7) tidak perlu ditulis dua kali.
            const LogoutButton(),
          ],
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
    this.enabled = true,
    this.badge = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  /// Jumlah yang menunggu. 0 berarti tidak ada lencana.
  final int badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: enabled ? onTap : null,
          leading: Icon(icon, color: enabled ? scheme.primary : scheme.outline),
          title: Text(title, style: theme.textTheme.titleMedium),
          subtitle: Text(subtitle),
          trailing: badge > 0
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.warning,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    Formatters.number(badge),
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.onPrimary),
                  ),
                )
              : (enabled ? const Icon(Icons.chevron_right) : null),
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        ),
      ),
    );
  }
}
