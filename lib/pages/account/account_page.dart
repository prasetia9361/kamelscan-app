import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/enums.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/failure_messages.dart';
import '../../core/widgets/profile_avatar.dart';
import '../../navigation/route_names.dart';
import 'account_view_model.dart';
import 'widgets/logout_button.dart';

/// Halaman Akun (Bab 9.6).
///
/// Bagian atas: foto profil, nama, email, peran, tanggal bergabung. Di bawahnya
/// daftar menu, lalu tombol Keluar menempel di dasar layar.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;

    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final t = context.l10n;
    final isOwner = session.isOwner;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              children: [
                _ProfileHeader(),

                const SizedBox(height: 20),

                _MenuTile(
                  icon: Icons.person_outline_rounded,
                  title: t.accountEditProfile,
                  onTap: () => context.push(Routes.editProfile),
                ),
                _MenuTile(
                  icon: Icons.key_outlined,
                  title: t.accountChangePassword,
                  onTap: () => context.push(Routes.changePassword),
                ),

                // Bab 9.6 butir 3 — hanya Owner. Packer tidak mengelola siapa
                // pun, dan menyembunyikannya lebih jujur daripada menampilkan
                // menu yang akan ditolak saat ditekan.
                if (isOwner)
                  _MenuTile(
                    icon: Icons.groups_outlined,
                    title: t.accountManagePackers,
                    onTap: () => context.push(Routes.packers),
                  ),

                const SizedBox(height: 8),
                _SubscriptionCard(),
                const SizedBox(height: 8),

                _SupportTile(),

                // Bab 9.6 — Hapus Akun.
                //
                // 🔴 WAJIB ADA DAN WAJIB DAPAT DITEMUKAN. App Store Review
                // Guideline 5.1.1(v) menuntut penghapusan akun dari dalam
                // aplikasi; menyembunyikannya di balik menu bertingkat adalah
                // alasan penolakan tersendiri, bukan hanya ketiadaannya.
                //
                // Hanya Owner: packer tidak memiliki tenant, dan yang akan
                // dihapus adalah seluruh usaha milik orang lain.
                if (isOwner) ...[
                  const SizedBox(height: 8),
                  _MenuTile(
                    icon: Icons.delete_forever_outlined,
                    title: t.accountDelete,
                    color: Theme.of(context).extension<AppColors>()!.danger,
                    onTap: () => context.push(Routes.deleteAccount),
                  ),
                ],
              ],
            ),
          ),

          // Bab 9.6 butir 6 — tombol Keluar di paling bawah.
          //
          // Jarak bawah 88 dp, bukan 24 dp: tombol Rekam yang mengambang di
          // sudut kanan bawah kerangka mobile menumpang di atas isi halaman,
          // dan pada jarak 24 dp ia menutupi ujung kanan tombol Keluar.
          // Terlihat di Redmi Note 9, 17 Agustus 2026.
          //
          // Sejak sakelar Bab 9.7 ada, jarak itu kembali ke 24 dp saat
          // tombolnya memang disembunyikan — cacat di atas tidak mungkin
          // terjadi kalau tombolnya tidak digambar sama sekali.
          Padding(
            padding: EdgeInsets.fromLTRB(
                24, 8, 24, ref.watch(showRecordFabProvider) ? 88 : 24),
            child: const LogoutButton(),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final session = ref.watch(sessionProvider).value;
    if (session == null) return const SizedBox.shrink();

    final user = session.user;

    final (peranWarna, peranLabel) = switch (user.role) {
      UserRole.admin => (colors.returnColor, t.roleAdmin),
      UserRole.owner => (colors.packing, t.roleOwner),
      UserRole.packer => (colors.success, t.rolePacker),
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ProfileAvatar(
              initials: user.initials,
              seed: user.id,
              avatarUrl: user.avatarUrl,
              size: 64,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: peranWarna.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          peranLabel,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: peranWarna),
                        ),
                      ),
                      if (user.createdAt != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            t.accountJoinedAt(Formatters.date(user.createdAt!)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bab 9.6 butir 4 — tier aktif, tanggal berakhir, tombol *Upgrade*.
class _SubscriptionCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final session = ref.watch(sessionProvider).value;
    if (session == null) return const SizedBox.shrink();

    final langganan = session.subscription;
    final sisaHari = langganan.daysRemaining;

    final labelTier = session.isTrial
        ? t.tierTrial
        : (session.plan.name == 'pro' ? t.tierPro : t.tierStandar);

    // Masa uji coba dibatasi **jumlah video**, bukan waktu (Bab 7.5) — jadi
    // yang ditampilkan sisa tokennya, bukan tanggal berakhir yang memang
    // tidak ada.
    final keterangan = session.isTrial
        ? t.accountTrialRemaining(session.quota.balance)
        : (langganan.periodEnd == null
            ? t.accountNoEndDate
            : t.accountValidUntil(Formatters.date(langganan.periodEnd!)));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium_outlined,
                    size: 20, color: colors.warning),
                const SizedBox(width: 12),
                Text(t.accountSubscription,
                    style: theme.textTheme.titleMedium),
                const Spacer(),
                Text(labelTier, style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              keterangan,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),

            // Bab 7.6 — peringatan sebelum langganan berakhir wajib ada;
            // mengunci pelanggan tanpa peringatan adalah cara tercepat
            // kehilangan mereka.
            if (langganan.shouldWarnExpiry && sisaHari != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 16,
                      color: sisaHari <= 1 ? colors.danger : colors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sisaHari <= 0
                          ? t.subscriptionExpiryToday
                          : t.subscriptionExpiryWarning(sisaHari),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],

            // Hanya Owner yang boleh membeli (Bab 2.2). Bagi packer tombolnya
            // tidak ada sama sekali — bukan abu-abu, karena tidak ada yang
            // dapat ia lakukan untuk mengubahnya.
            if (session.isOwner) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => context.push(Routes.payment),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                  label: Text(t.commonUpgrade),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bab 9.6 butir 5 — Bantuan & Kontak.
class _SupportTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final kontak = ref.watch(supportContactProvider);

    return _MenuTile(
      icon: Icons.support_agent_rounded,
      title: t.accountSupport,
      subtitle: t.accountSupportBody,
      // Selagi kontaknya dibaca dari server, barisnya tetap dapat ditekan —
      // nilai cadangan sudah tersedia, jadi tidak ada alasan menahannya.
      onTap: () async {
        final c = kontak.value ?? SupportContact.fallback;
        final uri = c.waLink(t.accountSupportMessage);
        final messenger = ScaffoldMessenger.of(context);

        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          messenger.showSnackBar(
            SnackBar(content: Text(t.accountSupportFailed(c.whatsapp))),
          );
        }
      },
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.color,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  /// Warna ikon dan judul. Dipakai satu-satunya menu yang merusak sesuatu.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
        // Bab 9.10 — sasaran sentuh besar; gudang, sarung tangan.
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      ),
    );
  }
}
