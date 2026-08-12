import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/page_scaffold_placeholder.dart';

/// AdminPaymentsPage — belum dikerjakan.
///
/// Spesifikasi: Bab 11 & Bab 12. Saat digarap, ganti isi `build` dan tambahkan
/// `admin_payments_view_model.dart` sesuai pola Bab 3.4 (empat kondisi wajib:
/// loading, error, kosong, berisi).
class AdminPaymentsPage extends ConsumerWidget {
  const AdminPaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffoldPlaceholder(
      title: context.l10n.navAdmin,
      specChapter: 'Bab 11 & Bab 12',
      icon: Icons.fact_check_outlined,
    );
  }
}
