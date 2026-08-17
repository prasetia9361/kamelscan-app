import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/upload_queue_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/failure_messages.dart';
import '../logout_view_model.dart';

/// Tombol **Keluar** (Bab 9.6 butir 6).
///
/// Spesifikasinya tiga hal: berada di paling bawah halaman Akun, berwarna
/// merah, dan selalu meminta konfirmasi. Konfirmasinya bukan basa-basi — pada
/// perangkat yang antriannya belum kosong, dialog ini adalah satu-satunya
/// tempat packer diberi tahu bahwa masih ada video yang belum terkirim
/// (Bab 8.7).
class LogoutButton extends ConsumerStatefulWidget {
  const LogoutButton({super.key});

  @override
  ConsumerState<LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends ConsumerState<LogoutButton> {
  Future<void> _confirmThenSignOut() async {
    // Antrian dibaca sebelum dialog dibuka. Bila alirannya belum sempat
    // memberi nilai pertama, 0 dipakai sebagai anggapan — dialog konfirmasi
    // tetap muncul, hanya tanpa baris peringatan.
    final pending = ref.read(pendingUploadCountProvider).value ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _LogoutConfirmDialog(pendingUploads: pending),
    );

    if (confirmed != true || !mounted) return;
    await ref.read(logoutViewModelProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;
    final state = ref.watch(logoutViewModelProvider);
    final busy = state is LogoutBusy;

    // Kegagalan keluar berarti pengguna **masih** masuk. Itu harus terlihat,
    // bukan berlalu diam-diam sementara ia mengira sudah keluar.
    ref.listen(logoutViewModelProvider, (_, next) {
      if (next is! LogoutFailed) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.failureMessage(next.failure))),
        );
      ref.read(logoutViewModelProvider.notifier).clearError();
    });

    return OutlinedButton.icon(
      onPressed: busy ? null : _confirmThenSignOut,
      icon: busy
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.danger,
              ),
            )
          : const Icon(Icons.logout_rounded),
      label: Text(busy ? t.accountLogoutBusy : t.accountLogout),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.danger,
        side: BorderSide(color: colors.danger),
        // Bab 9.10 — target sentuh besar; layar ini dipakai dengan sarung
        // tangan di gudang.
        minimumSize: const Size.fromHeight(52),
      ),
    );
  }
}

class _LogoutConfirmDialog extends StatelessWidget {
  const _LogoutConfirmDialog({required this.pendingUploads});

  final int pendingUploads;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return AlertDialog(
      icon: Icon(Icons.logout_rounded, color: colors.danger),
      title: Text(t.accountLogoutConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.accountLogoutConfirmBody),
          if (pendingUploads > 0) ...[
            const SizedBox(height: 16),
            _PendingUploadsNotice(count: pendingUploads),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: colors.danger),
          child: Text(t.accountLogout),
        ),
      ],
    );
  }
}

/// Bab 8.7 — *"Ada 4 video belum terunggah. Tetap keluar?"*
///
/// Kalimat kedua sama pentingnya: packer yang membaca peringatan pertama saja
/// akan mengira video itu hilang bila ia tetap keluar. Antrian justru sengaja
/// tidak dihapus, dan itu perlu dikatakan.
class _PendingUploadsNotice extends StatelessWidget {
  const _PendingUploadsNotice({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.warningContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // §0 palet — warna tidak boleh menjadi satu-satunya pembeda makna,
          // jadi peringatan ini selalu disertai ikon dan angka.
          Icon(Icons.cloud_upload_outlined, size: 20, color: colors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.accountLogoutPendingWarning(count),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  t.accountLogoutPendingBody,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
