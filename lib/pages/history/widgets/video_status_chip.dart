import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/failure_messages.dart';

/// Lencana status unggah pada baris dan halaman detail Riwayat (Bab 9.4).
///
/// §0 palet — warna tidak pernah menjadi satu-satunya pembeda makna: tiap
/// keadaan membawa tulisannya sendiri, dan yang paling penting (gagal) juga
/// membawa ikon.
class VideoStatusChip extends StatelessWidget {
  const VideoStatusChip({super.key, required this.status});

  final VideoStatus status;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    final (color, label, icon) = switch (status) {
      // 🔴 Ikonnya dulu `null`. Rancangan desainer Bab 10.5 butir 6: SETIAP
      // status punya ikon sendiri, bukan sekadar warna berbeda — satu-satunya
      // status tanpa ikon justru menjadi satu-satunya yang hanya dapat
      // dibedakan lewat warna.
      VideoStatus.uploaded => (
          colors.success,
          t.videoStatusUploaded,
          Icons.cloud_done_outlined,
        ),
      VideoStatus.uploading => (
          colors.packing,
          t.videoStatusUploading,
          Icons.cloud_upload_outlined,
        ),
      VideoStatus.pendingUpload => (
          colors.warning,
          t.videoStatusPendingUpload,
          Icons.schedule_rounded,
        ),
      VideoStatus.failed => (
          colors.danger,
          t.videoStatusFailed,
          Icons.error_outline_rounded,
        ),
      VideoStatus.expired => (
          theme.colorScheme.outline,
          t.videoStatusExpired,
          Icons.auto_delete_outlined,
        ),
      VideoStatus.deleted => (
          theme.colorScheme.outline,
          t.videoStatusDeleted,
          Icons.delete_outline_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tanpa syarat: keenam status wajib berikon. Yang satu tanpa ikon
          // akan menjadi satu-satunya yang hanya dapat dibedakan lewat warna.
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          // 🔴 `Flexible` — chip ber-`mainAxisSize.min` menuntut lebar aslinya
          // dan menolak menyusut. "Menunggu unggah" adalah label terpanjang di
          // sini, dan di kolom tabel web yang sempit ia meluber. Cacat sebentuk
          // sudah tertangkap pada chip Tipe (Bab 10.5).
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
