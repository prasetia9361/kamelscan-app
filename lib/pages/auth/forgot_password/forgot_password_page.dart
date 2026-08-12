import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/page_scaffold_placeholder.dart';

/// ForgotPasswordPage — belum dikerjakan.
///
/// Spesifikasi: Bab 6.4. Saat digarap, ganti isi `build` dan tambahkan
/// `forgot_password_view_model.dart` sesuai pola Bab 3.4 (empat kondisi wajib:
/// loading, error, kosong, berisi).
class ForgotPasswordPage extends ConsumerWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffoldPlaceholder(
      title: context.l10n.authForgotPassword,
      specChapter: 'Bab 6.4',
      icon: Icons.lock_reset_rounded,
    );
  }
}
