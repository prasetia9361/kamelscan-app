import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/session_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/failure_messages.dart';
import 'delete_account_view_model.dart';
import 'widgets/logout_button.dart';

/// Layar kunci akun yang sedang menunggu dimusnahkan (Bab 9.6, migrasi 37).
///
/// 🔴 **Inilah satu-satunya layar yang boleh dibuka akun seperti itu.**
/// `RouteGuards` mengalihkan setiap rute lain ke sini. Janjinya — *"akun
/// langsung tidak dapat digunakan"* — dibuat pada layar konfirmasi, dan sebuah
/// janji yang hanya ditegakkan pada sebagian layar sama saja dengan tidak
/// ditegakkan.
///
/// ⚠️ Layar ini **tidak** punya kerangka navigasi. Ia sengaja didaftarkan di
/// luar `StatefulShellRoute`: bilah tab di bawah adalah jalan masuk ke
/// layar-layar yang justru sedang dikunci, dan menampilkannya di sini hanya
/// menawarkan pintu yang akan ditolak penjaga rute begitu ditekan.
class DeletionPendingPage extends ConsumerWidget {
  const DeletionPendingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final tenant = ref.watch(sessionProvider).value?.tenant;
    final state = ref.watch(deleteAccountViewModelProvider);
    final sibuk = state is DeleteAccountBusy;

    final sisa = tenant?.daysUntilPurge() ?? 0;

    ref.listen(deleteAccountViewModelProvider, (prev, next) {
      if (next is DeleteAccountFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.failureMessage(next.failure))),
        );
        ref.read(deleteAccountViewModelProvider.notifier).clearError();
        return;
      }

      // Pembatalan berhasil. Penjaga rute yang memulangkan penggunanya begitu
      // sesi termuat ulang; halaman ini hanya mengucapkan hasilnya.
      if (prev is DeleteAccountBusy && next is DeleteAccountIdle) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.deletionPendingCancelled)),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.delete_forever_outlined,
                    size: 56,
                    color: colors.danger,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.deletionPendingTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    // Hitung mundurnya disebut angka, bukan tanggal. "3 hari
                    // lagi" langsung terasa mendesak; "3 September" menuntut
                    // pembacanya menghitung sendiri, dan yang salah menghitung
                    // kehilangan seluruh datanya.
                    sisa <= 0
                        ? t.deletionPendingToday
                        : t.deletionPendingBody(sisa),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),

                  FilledButton.icon(
                    onPressed: sibuk
                        ? null
                        : () => ref
                              .read(deleteAccountViewModelProvider.notifier)
                              .cancel(),
                    icon: const Icon(Icons.restore_rounded),
                    label: Text(t.deletionPendingCancel),
                  ),

                  const SizedBox(height: 12),
                  const LogoutButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
