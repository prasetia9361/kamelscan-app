import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/session_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/failure_messages.dart';
import 'delete_account_view_model.dart';
import 'logout_view_model.dart';

/// Bab 9.6 — Owner menghapus akunnya sendiri.
///
/// 🔴 **Halaman ini ada karena App Store mewajibkannya**, bukan karena ada yang
/// memintanya. Review Guideline 5.1.1(v): aplikasi yang dapat membuat akun
/// wajib dapat menghapusnya dari dalam aplikasi. "Hubungi kami lewat surel"
/// adalah alasan penolakan yang sudah baku.
///
/// Karena itu bentuknya tidak boleh dibuat berbelit-belit untuk menahan orang
/// pergi. Yang boleh — dan wajib — hanyalah memastikan ia tahu apa yang hilang.
class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  final _ketikan = TextEditingController();

  @override
  void dispose() {
    _ketikan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final tenant = ref.watch(sessionProvider).value?.tenant;
    final state = ref.watch(deleteAccountViewModelProvider);

    // Nama usaha kosong tidak boleh menjadi kunci yang membuka apa pun —
    // `''.trim() == ''.trim()` selalu benar, dan tombolnya akan hidup tanpa
    // seorang pun mengetik satu huruf. Emailnya dipakai sebagai gantinya.
    final namaUsaha = (tenant?.businessName ?? '').trim().isEmpty
        ? (ref.watch(sessionProvider).value?.user.email ?? '')
        : tenant!.businessName!.trim();

    final cocok =
        _ketikan.text.trim().toLowerCase() == namaUsaha.toLowerCase() &&
        namaUsaha.isNotEmpty;
    final sibuk = state is DeleteAccountBusy;

    ref.listen(deleteAccountViewModelProvider, (_, next) async {
      if (next is DeleteAccountFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.failureMessage(next.failure))),
        );
        ref.read(deleteAccountViewModelProvider.notifier).clearError();
      }

      // Akun trial: sudah musnah. Tidak ada sesi yang masih berarti apa pun,
      // jadi ditutup di sini — penjaga rute akan memulangkannya ke layar Masuk.
      if (next is DeleteAccountPurged) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.deleteAccountDoneTrial)),
        );
        await ref.read(logoutViewModelProvider.notifier).signOut();
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(t.deleteAccountTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.dangerContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: colors.danger),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.deleteAccountWarnTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Text(t.deleteAccountWhatGoes, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),

            // 🔴 Tautan berbagi disebut dengan sengaja. Owner mengirimkannya ke
            // pembeli sebagai bukti, dan tautan itu mati bersama akunnya —
            // pembeli yang membukanya minggu depan akan menemui halaman kosong.
            // Hanya Owner yang dapat menimbang akibat itu, dan ia hanya dapat
            // menimbangnya bila diberi tahu sebelum menekan, bukan sesudah.
            _Butir(t.deleteAccountItemVideos),
            _Butir(t.deleteAccountItemPackers),
            _Butir(t.deleteAccountItemShops),

            const SizedBox(height: 16),
            Text(
              t.deleteAccountNoRefund,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 12),
            Text(
              tenant?.isTrial ?? false
                  ? t.deleteAccountGraceTrial
                  : t.deleteAccountGrace,
              style: theme.textTheme.bodyMedium,
            ),

            const SizedBox(height: 24),

            // Mengetik ulang nama usahanya adalah pola GitHub, dan alasannya
            // bukan seremoni: ia memaksa mata membaca nama akun yang sedang
            // dihapus. Menekan "Ya" dua kali tidak pernah memaksa siapa pun
            // memastikan ia sedang menghapus akun yang benar.
            TextField(
              controller: _ketikan,
              autocorrect: false,
              enabled: !sibuk,
              decoration: InputDecoration(
                labelText: t.deleteAccountTypeName(namaUsaha),
                helperMaxLines: 3,
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.danger,
                  foregroundColor: Colors.white,
                ),
                onPressed: cocok && !sibuk
                    ? () => ref
                          .read(deleteAccountViewModelProvider.notifier)
                          .request(_ketikan.text.trim())
                    : null,
                child: sibuk
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(t.deleteAccountConfirmButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Butir extends StatelessWidget {
  const _Butir(this.teks);
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(
            child: Text(teks, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
