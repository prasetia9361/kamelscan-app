import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
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

    // Navigasi dilakukan di listener, bukan di build — membangun ulang widget
    // tidak boleh punya efek samping.
    ref.listen(loginViewModelProvider, (_, next) {
      if (next is LoginSucceeded) {
        context.go(
          next.mustChangePassword ? Routes.changePassword : Routes.splash,
        );
      }
    });

    return AuthScaffold(
      showBack: false,
      title: t.authSignInTitle,
      subtitle: t.authSignInSubtitle,
      children: [
        if (state is LoginFailed)
          AuthErrorBox(message: context.failureMessage(state.failure)),
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
                onChanged: (_) =>
                    ref.read(loginViewModelProvider.notifier).clearError(),
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
                  onPressed: () => context.push(Routes.forgotPassword),
                  child: Text(t.authForgotPassword),
                ),
              ),
              const SizedBox(height: 8),
              AuthPrimaryButton(
                label: t.authLogin,
                busy: busy,
                onPressed: _submit,
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
            icon: const Icon(Icons.g_mobiledata, size: 28),
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
