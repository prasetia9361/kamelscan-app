import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/failure_messages.dart';
import '../../core/widgets/page_scaffold_placeholder.dart';

/// SettingsPage — belum dikerjakan.
///
/// Spesifikasi: Bab 9.9. Saat digarap, ganti isi `build` dan tambahkan
/// `settings_view_model.dart` sesuai pola Bab 3.4 (empat kondisi wajib:
/// loading, error, kosong, berisi).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffoldPlaceholder(
      title: context.l10n.navSettings,
      specChapter: 'Bab 9.9',
      icon: Icons.settings_outlined,
    );
  }
}
