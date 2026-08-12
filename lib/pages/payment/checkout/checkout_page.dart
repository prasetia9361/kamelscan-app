import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/page_scaffold_placeholder.dart';

/// CheckoutPage — belum dikerjakan.
///
/// Spesifikasi: Bab 12. Saat digarap, ganti isi `build` dan tambahkan
/// `checkout_view_model.dart` sesuai pola Bab 3.4 (empat kondisi wajib:
/// loading, error, kosong, berisi).
class CheckoutPage extends ConsumerWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffoldPlaceholder(
      title: context.l10n.navPayment,
      specChapter: 'Bab 12',
      icon: Icons.receipt_long_outlined,
    );
  }
}
