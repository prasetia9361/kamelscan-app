import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/failure_messages.dart';
import '../../core/widgets/page_scaffold_placeholder.dart';

/// HistoryPage — belum dikerjakan.
///
/// Spesifikasi: Bab 9.5. Saat digarap, ganti isi `build` dan tambahkan
/// `history_view_model.dart` sesuai pola Bab 3.4 (empat kondisi wajib:
/// loading, error, kosong, berisi).
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffoldPlaceholder(
      title: context.l10n.navHistory,
      specChapter: 'Bab 9.5',
      icon: Icons.history_rounded,
    );
  }
}
