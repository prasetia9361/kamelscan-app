import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../navigation/route_names.dart';
import '../widgets/auth_scaffold.dart';
import 'login_view_model.dart';

/// Layar masuk (Bab 6.1, 6.2, 6.5, 6.6).
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    ref.read(loginViewModelProvider.notifier).signIn(
          identifier: _identifier.text,
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final state = ref.watch(loginViewModelProvider);
    final busy = state is LoginBusy;
    final busyGoogle = state is LoginBusy && state.viaGoogle;

    // Navigasi dilakukan di listener, bukan di build — membangun ulang widget
    // tidak boleh punya efek samping.
    ref.listen(loginViewModelProvider, (_, next) {
      if (next is LoginSucceeded) {
        context.go(
          next.mustChangePassword ? Routes.changePassword : Routes.splash,
        );
      }
    });

    // 🔴 Kegagalan tautan email tidak datang lewat tombol mana pun, jadi tidak
    // ada satu pun keadaan ViewModel yang membawanya. Tanpa kotak ini, tautan
    // reset yang kedaluwarsa terlihat persis seperti tautan yang tidak
    // melakukan apa-apa: aplikasi terbuka di layar Masuk, tanpa sepatah kata.
    final linkFailure = ref.watch(authLinkFailureProvider);

    return AuthScaffold(
      showBack: false,
      // Layar Masuk adalah satu-satunya layar yang dilihat orang sebelum tahu
      // aplikasi apa ini, jadi ia satu-satunya yang memakai kepala bermerek.
      header: AuthBrandHeader(tagline: t.authTagline),
      centerTitle: true,
      title: t.authSignInTitle,
      subtitle: t.authSignInSubtitle,
      children: [
        if (state is LoginFailed)
          AuthErrorBox(message: context.failureMessage(state.failure))
        else if (linkFailure != null)
          AuthErrorBox(message: context.failureMessage(linkFailure)),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _identifier,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                onChanged: (_) {
                  ref.read(loginViewModelProvider.notifier).clearError();
                  ref.read(authLinkFailureProvider.notifier).clear();
                },
                decoration: InputDecoration(
                  labelText: t.authIdentifier,
                  hintText: t.authIdentifierHint,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? t.validationRequired
                    : null,
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                label: t.authPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: _submit,
                validator: (v) => (v == null || v.isEmpty)
                    ? t.validationPasswordRequired
                    : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    ref.read(authLinkFailureProvider.notifier).clear();
                    context.push(Routes.forgotPassword);
                  },
                  child: Text(t.authForgotPassword),
                ),
              ),
              const SizedBox(height: 8),
              AuthPrimaryButton(
                label: t.authLogin,
                // Berputar hanya bila tombol INI yang ditekan; saat Google
                // sedang berjalan ia cukup mati, tidak ikut berputar.
                busy: busy && !busyGoogle,
                onPressed: busy ? null : _submit,
              ),
            ],
          ),
        ),

        // Bab 6.5 — tombol Google disembunyikan bila Client ID belum diisi,
        // daripada tampil lalu gagal saat ditekan.
        if (Env.googleSignInConfigured) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(t.authOr),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () => ref
                    .read(loginViewModelProvider.notifier)
                    .signInWithGoogle(),
            // 🔴 Putaran ini menggantikan tiga detik yang sebelumnya hening.
            // Alasannya beserta angka ukurannya ada di `LoginViewModel`.
            icon: busyGoogle
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                // Logo Google yang sebenarnya, bukan `Icons.g_mobiledata` —
                // ikon itu huruf G polos sewarna teks tombol, dan tombol masuk
                // pihak ketiga dikenali orang justru dari logonya. Panduan
                // merek Google juga meminta logo aslinya, bukan tiruan.
                : Image.asset(
                    'assets/images/google.png',
                    width: 20,
                    height: 20,
                  ),
            label: Text(t.authContinueWithGoogle),
          ),
        ],

        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(t.authNoAccount),
            TextButton(
              onPressed: () => context.push(Routes.register),
              child: Text(t.authRegister),
            ),
          ],
        ),
      ],
    );
  }
}

/// Dipakai layar lain yang perlu memvalidasi email dengan aturan sama.
String? validateEmailField(BuildContext context, String? value) {
  final key = Validators.email(value);
  return key == null ? null : context.messageForKey(key);
}
