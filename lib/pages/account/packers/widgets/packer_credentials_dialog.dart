import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/repositories/user_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/failure_messages.dart';

/// Dialog kredensial akun packer yang baru dibuat (Bab 6.7 / Bab 9.6).
///
/// 🔴 Password sementara ini **hanya ada sekali**. Server menyimpannya dalam
/// bentuk ter-hash dan tidak dapat mengembalikannya; menutup dialog tanpa
/// menyalinnya berarti akunnya tidak dapat dipakai siapa pun, dan satu-satunya
/// jalan keluar adalah mengirim tautan atur ulang password.
///
/// Karena itu dialognya tidak dapat ditutup dengan mengetuk di luar, dan
/// tombol salin berdiri lebih menonjol daripada tombol tutup.
class PackerCredentialsDialog extends StatelessWidget {
  const PackerCredentialsDialog({super.key, required this.credentials});

  final NewPackerCredentials credentials;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return AlertDialog(
      icon: Icon(Icons.check_circle_outline_rounded, color: colors.success),
      title: Text(t.packersCreatedTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.packersCreatedBody, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),

          _Baris(label: t.authEmail, value: credentials.email),
          const SizedBox(height: 10),
          _Baris(
            label: t.packersTempPassword,
            value: credentials.tempPassword,
            // Password memakai huruf monospace dengan alasan yang sama seperti
            // nomor resi (§3.3 palet): Owner akan membacakannya ke packer, dan
            // pada huruf biasa `0`/`O` serta `1`/`l`/`I` nyaris tidak terbedakan.
            monospace: true,
          ),

          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: colors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.packersCreatedWarning,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.commonClose),
        ),
        FilledButton.icon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await Clipboard.setData(
              ClipboardData(
                text: '${t.authEmail}: ${credentials.email}\n'
                    '${t.packersTempPassword}: ${credentials.tempPassword}',
              ),
            );
            messenger.showSnackBar(
              SnackBar(content: Text(t.commonCopied)),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: Text(t.commonCopy),
        ),
      ],
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        SelectableText(
          value,
          style: monospace
              ? AppTextStyles.resiInline
                  .copyWith(color: theme.colorScheme.onSurface)
              : theme.textTheme.bodyLarge,
        ),
      ],
    );
  }
}
