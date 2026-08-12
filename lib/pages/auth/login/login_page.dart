import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/page_scaffold_placeholder.dart';

/// LoginPage — belum dikerjakan.
///
/// Spesifikasi: Bab 6.2 & Bab 9.2. Saat digarap, ganti isi `build` dan tambahkan
/// `login_view_model.dart` sesuai pola Bab 3.4 (empat kondisi wajib:
/// loading, error, kosong, berisi).
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffoldPlaceholder(
      title: context.l10n.authLogin,
      specChapter: 'Bab 6.2 & Bab 9.2',
      icon: Icons.login_rounded,
    );
  }
}
