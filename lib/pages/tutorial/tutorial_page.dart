import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/failure_messages.dart';
import '../../core/widgets/page_scaffold_placeholder.dart';

/// TutorialPage — belum dikerjakan.
///
/// Spesifikasi: Bab 9.x. Saat digarap, ganti isi `build` dan tambahkan
/// `tutorial_view_model.dart` sesuai pola Bab 3.4 (empat kondisi wajib:
/// loading, error, kosong, berisi).
class TutorialPage extends ConsumerWidget {
  const TutorialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffoldPlaceholder(
      title: context.l10n.navTutorial,
      specChapter: 'Bab 9.x',
      icon: Icons.ondemand_video_outlined,
    );
  }
}
