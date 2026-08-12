import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/page_scaffold_placeholder.dart';

/// RecordingSetupPage — belum dikerjakan.
///
/// Spesifikasi: Bab 8.3. Saat digarap, ganti isi `build` dan tambahkan
/// `recording_setup_view_model.dart` sesuai pola Bab 3.4 (empat kondisi wajib:
/// loading, error, kosong, berisi).
class RecordingSetupPage extends ConsumerWidget {
  const RecordingSetupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffoldPlaceholder(
      title: context.l10n.navRecord,
      specChapter: 'Bab 8.3',
      icon: Icons.tune_rounded,
    );
  }
}
