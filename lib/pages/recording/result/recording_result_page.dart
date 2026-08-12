import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/page_scaffold_placeholder.dart';

/// RecordingResultPage — belum dikerjakan.
///
/// Spesifikasi: Bab 8.6. Saat digarap, ganti isi `build` dan tambahkan
/// `recording_result_view_model.dart` sesuai pola Bab 3.4 (empat kondisi wajib:
/// loading, error, kosong, berisi).
class RecordingResultPage extends ConsumerWidget {
  const RecordingResultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffoldPlaceholder(
      title: context.l10n.navRecord,
      specChapter: 'Bab 8.6',
      icon: Icons.check_circle_outline_rounded,
    );
  }
}
