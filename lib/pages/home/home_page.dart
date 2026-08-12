import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/failure_messages.dart';
import '../../core/widgets/page_scaffold_placeholder.dart';

/// HomePage — belum dikerjakan.
///
/// Spesifikasi: Bab 9.3. Saat digarap, ganti isi `build` dan tambahkan
/// `home_view_model.dart` sesuai pola Bab 3.4 (empat kondisi wajib:
/// loading, error, kosong, berisi).
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffoldPlaceholder(
      title: context.l10n.navHome,
      specChapter: 'Bab 9.3',
      icon: Icons.dashboard_outlined,
    );
  }
}
