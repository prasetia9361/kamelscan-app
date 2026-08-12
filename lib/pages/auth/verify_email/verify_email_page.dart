import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/page_scaffold_placeholder.dart';

/// VerifyEmailPage — belum dikerjakan.
///
/// Spesifikasi: Bab 6.3. Saat digarap, ganti isi `build` dan tambahkan
/// `verify_email_view_model.dart` sesuai pola Bab 3.4 (empat kondisi wajib:
/// loading, error, kosong, berisi).
class VerifyEmailPage extends ConsumerWidget {
  const VerifyEmailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffoldPlaceholder(
      title: context.l10n.authRegister,
      specChapter: 'Bab 6.3',
      icon: Icons.mark_email_unread_outlined,
    );
  }
}
