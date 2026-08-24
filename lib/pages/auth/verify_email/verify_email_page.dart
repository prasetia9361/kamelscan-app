import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../navigation/route_names.dart';
import '../widgets/auth_scaffold.dart';
import 'verify_email_view_model.dart';

/// Layar tunggu verifikasi email (Bab 6.4).
class VerifyEmailPage extends ConsumerWidget {
  const VerifyEmailPage({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final vm = verifyEmailViewModelProvider(email);
    final state = ref.watch(vm);

    // Bab 6.4 — begitu pengguna menekan tautan di email, deep link membuka
    // aplikasi dan sesi menjadi valid. Listener ini yang menangkapnya.
    ref.listen(isSignedInProvider, (_, signedIn) {
      if (signedIn) context.go(Routes.splash);
    });

    return AuthScaffold(
      title: t.authVerifyTitle,
      children: [
        Icon(
          Icons.mark_email_unread_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          t.authVerifyBody(email),
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 12),

        // 🔴 Kalimat ini menutup jalan buntu, bukan sekadar basa-basi.
        //
        // Terbukti di perangkat Product Owner 24 Agustus 2026: mendaftar
        // memakai email yang sudah terpakai sebagai packer membawa pengguna ke
        // layar ini juga, lengkap dengan *"Menunggu verifikasi…"* yang berputar
        // selamanya — padahal Supabase tidak pernah mengirim email apa pun dan
        // tidak pernah membuat akun baru.
        //
        // Supabase sengaja menyamarkan penolakannya agar tidak ada yang bisa
        // menebak-nebak email siapa saja yang menjadi pelanggan. Penyamaran itu
        // BENAR dan tidak boleh dilucuti — pilihan yang sama sudah diambil di
        // layar Lupa Password ("Jika email tersebut terdaftar…"). Yang keliru
        // hanyalah layar ini yang berlagak seolah emailnya pasti terkirim.
        //
        // Karena itu perbaikannya di kalimatnya, bukan di mekanismenya:
        // katakan kemungkinan itu ada, tanpa memastikan yang mana — dan beri
        // jalan keluarnya.
        Text(
          t.authVerifyMaybeRegistered,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),

        if (state.failure != null)
          AuthErrorBox(message: context.failureMessage(state.failure!)),

        if (state.justSent)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(t.authResendSent)),
              ],
            ),
          ),

        AuthPrimaryButton(
          label: state.canResend
              ? t.authResendEmail
              : t.authResendIn(state.secondsLeft),
          busy: state.sending,
          onPressed:
              state.canResend ? () => ref.read(vm.notifier).resend() : null,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () async {
            await ref.read(vm.notifier).cancelAndSignOut();
            if (context.mounted) context.go(Routes.register);
          },
          child: Text(t.authChangeEmail),
        ),
        TextButton(
          onPressed: () async {
            await ref.read(vm.notifier).cancelAndSignOut();
            if (context.mounted) context.go(Routes.login);
          },
          child: Text(t.authLogin),
        ),

        const SizedBox(height: 24),
        Row(
          children: [
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              t.authVerifyWaiting,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),
        // Bab 6.4 — Supabase Free membatasi ± 3–4 email/jam. Bila email tidak
        // kunjung datang, pengguna butuh jalan keluar selain menunggu.
        Text(
          'Email tidak datang? Cek folder spam, '
          'atau hubungi ${AppConstants.supportEmail}.',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
