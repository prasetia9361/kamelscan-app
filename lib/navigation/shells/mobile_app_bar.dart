import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/greeting.dart';
import '../../core/models/enums.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/upload_queue_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/failure_messages.dart';
import '../../core/widgets/profile_avatar.dart';

/// Bilah atas kerangka mobile (Bab 9.1) — tinggi 72 dp.
///
/// ```
/// ┌──────────────────────────────────────────────┐
/// │  ┌────┐  Selamat pagi,                       │
/// │  │foto│  Budi Santoso        [3 menunggu]    │
/// │  └────┘  ● Pemilik · Toko Maju Jaya          │
/// ```
///
/// Dipasang di kerangka, bukan di tiap halaman, supaya seluruh tab memakai
/// kepala yang sama persis — Bab 9.1 menyebutnya "kerangka tiga bagian".
class MobileTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const MobileTopBar({super.key, required this.onProfileTap});

  /// Foto profil dapat ditekan → menuju halaman Akun (Bab 9.1).
  final VoidCallback onProfileTap;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final theme = Theme.of(context);

    // Sesi belum pulih dari penyimpanan. Bilahnya tetap berdiri dengan tinggi
    // yang sama supaya isi halaman tidak melompat saat namanya muncul.
    if (session == null) {
      return AppBar(toolbarHeight: 72, title: const SizedBox.shrink());
    }

    final user = session.user;

    return AppBar(
      toolbarHeight: 72,
      leadingWidth: 68,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: ProfileAvatar(
            initials: user.initials,
            seed: user.id,
            avatarUrl: user.avatarUrl,
            onTap: onProfileTap,
          ),
        ),
      ),
      titleSpacing: 12,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _greetingText(context),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          Text(
            user.fullName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          _RoleLine(role: user.role, businessName: session.tenant.businessName),
        ],
      ),
      actions: const [
        // Bab 9.1 — lonceng notifikasi masih 🟡 TARGET dan belum punya isi,
        // jadi tempatnya diisi indikator antrian unggah seperti yang
        // diinstruksikan di sana. Lonceng kosong yang tidak pernah berbunyi
        // hanya melatih pengguna untuk mengabaikannya.
        _UploadIndicator(),
        SizedBox(width: 8),
      ],
    );
  }

  String _greetingText(BuildContext context) {
    final t = context.l10n;
    return switch (Greeting.now()) {
      Greeting.morning => t.homeGreetingMorning,
      Greeting.afternoon => t.homeGreetingAfternoon,
      Greeting.evening => t.homeGreetingEvening,
      Greeting.night => t.homeGreetingNight,
    };
  }
}

/// `● Pemilik · Toko Maju Jaya`
class _RoleLine extends StatelessWidget {
  const _RoleLine({required this.role, required this.businessName});

  final UserRole role;
  final String? businessName;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    // Bab 9.1 meminta Admin ungu, Owner biru, Packer hijau. Ketiganya diambil
    // dari warna semantik palet yang sudah ada — tidak ada `Color(0xFF…)` baru
    // yang ditulis di sini (§6 palet), dan mode gelapnya ikut benar dengan
    // sendirinya.
    final (color, label) = switch (role) {
      UserRole.admin => (colors.returnColor, t.roleAdmin),
      UserRole.owner => (colors.packing, t.roleOwner),
      UserRole.packer => (colors.success, t.rolePacker),
    };

    final shop = (businessName ?? '').trim();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // §0 palet — warna tidak pernah menjadi satu-satunya pembeda makna.
        // Titik berwarna ini selalu ditemani tulisan perannya.
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: color),
        ),
        if (shop.isNotEmpty) ...[
          Text(
            ' · ',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          Flexible(
            child: Text(
              shop,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ],
    );
  }
}

/// *"3 menunggu unggah"* — hanya muncul saat memang ada yang mengantre.
///
/// ⚠️ Angkanya dari antrian **lokal**, sama seperti spanduk di Beranda. Alasan
/// lengkapnya di `HomeStats.pendingUpload` dan `DEVIASI_LIBRARY.md` L.5.
class _UploadIndicator extends ConsumerWidget {
  const _UploadIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pendingUploadCountProvider).value ?? 0;
    if (count == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final color = theme.extension<AppColors>()!.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_upload_outlined, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            context.l10n.homeUploadPending(count),
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
