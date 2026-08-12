import 'package:flutter/material.dart';

/// Penanda layar yang **belum dikerjakan** karena spesifikasinya berada di bab
/// yang belum digarap.
///
/// Dipakai agar rute, guard, shell, dan navigasi dapat diuji utuh sejak
/// Bab 3–4 tanpa berpura-pura layarnya sudah jadi. Setiap layar yang selesai
/// mengganti penanda ini dengan `<nama>_page.dart` + `<nama>_view_model.dart`
/// sesuai pola Bab 3.4.
class PageScaffoldPlaceholder extends StatelessWidget {
  const PageScaffoldPlaceholder({
    super.key,
    required this.title,
    required this.specChapter,
    this.icon = Icons.construction_outlined,
  });

  final String title;

  /// Bab yang menetapkan layar ini, mis. "Bab 9.3".
  final String specChapter;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Spesifikasi layar ini ada di $specChapter.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
