import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/page_scaffold_placeholder.dart';

/// RecordingCameraPage — belum dikerjakan.
///
/// Spesifikasi: Bab 8.1–8.5. Saat digarap, ganti isi `build` dan tambahkan
/// `recording_camera_view_model.dart` sesuai pola Bab 3.4 (empat kondisi wajib:
/// loading, error, kosong, berisi).
class RecordingCameraPage extends ConsumerWidget {
  const RecordingCameraPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffoldPlaceholder(
      title: context.l10n.navRecord,
      specChapter: 'Bab 8.1–8.5',
      icon: Icons.videocam_outlined,
    );
  }
}
