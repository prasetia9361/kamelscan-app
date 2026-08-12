import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/page_scaffold_placeholder.dart';

/// VideoDetailPage — belum dikerjakan.
///
/// Spesifikasi: Bab 9.6. Saat digarap, ganti isi `build` dan tambahkan
/// `video_detail_view_model.dart` sesuai pola Bab 3.4 (empat kondisi wajib:
/// loading, error, kosong, berisi).
class VideoDetailPage extends ConsumerWidget {
  const VideoDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffoldPlaceholder(
      title: context.l10n.navHistory,
      specChapter: 'Bab 9.6',
      icon: Icons.play_circle_outline_rounded,
    );
  }
}
