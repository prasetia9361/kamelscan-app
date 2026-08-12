import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/page_scaffold_placeholder.dart';

/// AdminDashboardPage — belum dikerjakan.
///
/// Spesifikasi: Bab 11. Saat digarap, ganti isi `build` dan tambahkan
/// `admin_dashboard_view_model.dart` sesuai pola Bab 3.4 (empat kondisi wajib:
/// loading, error, kosong, berisi).
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffoldPlaceholder(
      title: context.l10n.navAdmin,
      specChapter: 'Bab 11',
      icon: Icons.admin_panel_settings_outlined,
    );
  }
}
