import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/failure_messages.dart';
import '../../core/widgets/page_scaffold_placeholder.dart';

/// AccountPage — belum dikerjakan.
///
/// Spesifikasi: Bab 9.8. Saat digarap, ganti isi `build` dan tambahkan
/// `account_view_model.dart` sesuai pola Bab 3.4 (empat kondisi wajib:
/// loading, error, kosong, berisi).
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffoldPlaceholder(
      title: context.l10n.navAccount,
      specChapter: 'Bab 9.8',
      icon: Icons.person_outline_rounded,
    );
  }
}
