import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/failure_messages.dart';
import '../../core/widgets/page_scaffold_placeholder.dart';

/// ShopsPage — belum dikerjakan.
///
/// Spesifikasi: Bab 9.7. Saat digarap, ganti isi `build` dan tambahkan
/// `shops_view_model.dart` sesuai pola Bab 3.4 (empat kondisi wajib:
/// loading, error, kosong, berisi).
class ShopsPage extends ConsumerWidget {
  const ShopsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffoldPlaceholder(
      title: context.l10n.navShops,
      specChapter: 'Bab 9.7',
      icon: Icons.storefront_outlined,
    );
  }
}
