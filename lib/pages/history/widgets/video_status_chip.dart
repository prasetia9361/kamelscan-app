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
      VideoStatus.uploaded => (colors.success, t.videoStatusUploaded, null),
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
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
