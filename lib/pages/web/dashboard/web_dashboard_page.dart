import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/page_scaffold_placeholder.dart';

/// WebDashboardPage — belum dikerjakan.
///
/// Spesifikasi: Bab 10.3. Saat digarap, ganti isi `build` dan tambahkan
/// `web_dashboard_view_model.dart` sesuai pola Bab 3.4 (empat kondisi wajib:
/// loading, error, kosong, berisi).
class WebDashboardPage extends ConsumerWidget {
  const WebDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffoldPlaceholder(
      title: context.l10n.navDashboard,
      specChapter: 'Bab 10.3',
      icon: Icons.insights_outlined,
    );
  }
}
