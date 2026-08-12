import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/page_scaffold_placeholder.dart';

/// PackersPage — belum dikerjakan.
///
/// Spesifikasi: Bab 9.8 & Bab 7.4. Saat digarap, ganti isi `build` dan tambahkan
/// `packers_view_model.dart` sesuai pola Bab 3.4 (empat kondisi wajib:
/// loading, error, kosong, berisi).
class PackersPage extends ConsumerWidget {
  const PackersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffoldPlaceholder(
      title: context.l10n.navAccount,
      specChapter: 'Bab 9.8 & Bab 7.4',
      icon: Icons.groups_outlined,
    );
  }
}
