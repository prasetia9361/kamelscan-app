import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/failure_messages.dart';
import '../../core/widgets/page_scaffold_placeholder.dart';

/// PlanPage — belum dikerjakan.
///
/// Spesifikasi: Bab 12. Saat digarap, ganti isi `build` dan tambahkan
/// `plan_view_model.dart` sesuai pola Bab 3.4 (empat kondisi wajib:
/// loading, error, kosong, berisi).
class PlanPage extends ConsumerWidget {
  const PlanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffoldPlaceholder(
      title: context.l10n.navPayment,
      specChapter: 'Bab 12',
      icon: Icons.workspace_premium_outlined,
    );
  }
}
