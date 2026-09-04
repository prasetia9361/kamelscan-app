import 'package:flutter/material.dart';

import '../theme/app_text_styles_display.dart';

/// Kepala bagian: label kecil berspasi lebar + garis rambut mengisi sisanya.
///
/// Menggantikan `_SectionTitle` di Beranda dan judul-judul `titleMedium` di
/// Pengaturan. Garisnya yang memisahkan bagian, bukan kartu — dan garis tidak
/// menambah satu pun kotak ke halaman.
class KSectionHeader extends StatelessWidget {
  const KSectionHeader(this.label, {super.key, this.trailing});

  final String label;

  /// Keterangan kanan, mis. "sejak 01 Agu 2026". Boleh null.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: AppDisplayStyles.kicker.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: scheme.outlineVariant, height: 1)),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          trailing!,
        ],
      ],
    );
  }
}
