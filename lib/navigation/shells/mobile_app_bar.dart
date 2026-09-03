import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/greeting.dart';
import '../../core/models/enums.dart';
import '../../core/providers/pipeline_providers.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/upload_queue_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_text_styles_display.dart';
import '../../core/widgets/failure_messages.dart';
import '../../core/widgets/profile_avatar.dart';

/// Bilah atas kerangka mobile (Bab 9.1) — tinggi 56 dp.
///
/// ```
/// ┌──────────────────────────────────────────────┐
/// │  [K] KAMELSCAN          [3 menunggu]  (RS)●  │
/// └──────────────────────────────────────────────┘
/// ```
///
/// 🔴 **Sapaan pindah ke badan Beranda** (revisi tampilan, 1 September 2026).
///
/// Sebelumnya bilah ini memuat sapaan, nama, peran, dan nama usaha setinggi
/// 72 dp — dan mengulanginya di **setiap** tab. Di halaman Toko atau Riwayat,
/// tiga baris tentang siapa yang sedang login mendorong isi yang sebenarnya
/// dicari turun hampir seperlima layar, tiap kali.
///
/// Sekarang bilah ini hanya menyatakan aplikasi apa ini dan siapa yang login;
/// sapaannya hidup di `HomePage`, tempat ia memang berarti sesuatu.
///
/// Dipasang di kerangka, bukan di tiap halaman, supaya seluruh tab memakai
/// kepala yang sama persis — Bab 9.1 menyebutnya "kerangka tiga bagian".
class MobileTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const MobileTopBar({super.key, required this.onProfileTap});

  /// Foto profil dapat ditekan → menuju halaman Akun (Bab 9.1).
  final VoidCallback onProfileTap;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final theme = Theme.of(context);

    return AppBar(
      toolbarHeight: 56,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // `logo-app.png` — 873×626, versi **mark saja**: huruf K, barcode,
          // centang, kardus.
          //
          // ⚠️ Catatan desainer menyebut berkas ini lockup penuh 1254×1254
          // beserta wordmark dan tagline, dan menyuruh memakai berkas mark
          // terpisah. Itu sudah tidak berlaku: berkas di repo ini sudah versi
          // mark, dimensinya sama persis dengan yang dipakai prototipe.
          //
          // Berkasnya berlatar putih solid, bukan transparan — karena itu ia
          // dipasang di atas bidang putih ber-radius 9 dp, yang di mode terang
          // nyaris tak terlihat dan di mode gelap justru menjadi bagian
          // bentuknya. Begitu ada versi berlatar transparan, bidang putih ini
          // bisa dihapus tanpa mengubah tata letak.
          Container(
            width: 28,
            height: 28,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Image.asset(
              'assets/images/logo-app.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'KAMELSCAN',
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.2,
            ),
          ),
        ],
      ),
      actions: [
        // Bab 9.1 — lonceng notifikasi masih 🟡 TARGET dan belum punya isi,
        // jadi tempatnya diisi indikator antrian unggah seperti yang
        // diinstruksikan di sana. Lonceng kosong yang tidak pernah berbunyi
        // hanya melatih pengguna untuk mengabaikannya.
        const _UploadIndicator(),
        const SizedBox(width: 10),
        // Sesi belum pulih dari penyimpanan: ruangnya tetap disisakan supaya
        // bilahnya tidak berubah lebar saat avatarnya muncul.
        if (session == null)
          const SizedBox(width: 36)
        else
          ProfileAvatar(
            initials: session.user.initials,
            seed: session.user.id,
            avatarUrl: session.user.avatarUrl,
            size: 36,
            online: ref.watch(networkOnlineProvider).value,
            onTap: onProfileTap,
          ),
        const SizedBox(width: 16),
      ],
    );
  }
}

/// `[PEMILIK] Toko Maju Jaya` — lencana peran di badan Beranda.
///
/// Dipindahkan ke sini dari bilah atas bersama sapaannya. Bentuknya berubah
/// dari titik + teks menjadi lencana berisi penuh: pada badan halaman ia
/// berdiri sendiri tanpa foto di sebelahnya, jadi ia perlu bentuknya sendiri
/// untuk terbaca sebagai satu hal.
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role, required this.businessName});

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
    final (color, background, label) = switch (role) {
      UserRole.admin => (
          colors.onReturnContainer,
          colors.returnContainer,
          t.roleAdmin
        ),
      UserRole.owner => (
          colors.onPackingContainer,
          colors.packingContainer,
          t.roleOwner
        ),
      UserRole.packer => (colors.success, colors.successContainer, t.rolePacker),
    };

    final shop = (businessName ?? '').trim();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // §0 palet — warna tidak pernah menjadi satu-satunya pembeda makna.
        // Lencana berwarna ini selalu memuat tulisan perannya.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          ),
          child: Text(
            label.toUpperCase(),
            style: AppDisplayStyles.kicker
                .copyWith(fontSize: 9.5, letterSpacing: 1.2, color: color),
          ),
        ),
        if (shop.isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              shop,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ],
    );
  }
}

/// Teks sapaan menurut jam — dipakai `HomePage`.
String greetingText(BuildContext context) {
  final t = context.l10n;
  return switch (Greeting.now()) {
    Greeting.morning => t.homeGreetingMorning,
    Greeting.afternoon => t.homeGreetingAfternoon,
    Greeting.evening => t.homeGreetingEvening,
    Greeting.night => t.homeGreetingNight,
  };
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
