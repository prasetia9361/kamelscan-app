import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/failure_messages.dart';
import '../widgets/auth_scaffold.dart';
import 'forgot_password_view_model.dart';

/// Lupa password (Bab 6.8).
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final state = ref.watch(forgotPasswordViewModelProvider);

    // Setelah terkirim, form diganti pesan — bukan ditumpuk snackbar yang
    // hilang sebelum sempat dibaca.
    if (state.sent) {
      return AuthScaffold(
        title: t.authForgotTitle,
        children: [
          Icon(
            Icons.mark_email_read_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            t.authForgotSent,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 28),
          AuthPrimaryButton(
            label: t.commonBack,
            onPressed: () => context.pop(),
          ),
        ],
      );
    }

    return AuthScaffold(
      title: t.authForgotTitle,
      subtitle: t.authForgotBody,
      children: [
        if (state.failure != null)
          AuthErrorBox(message: context.failureMessage(state.failure!)),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: t.authEmail),
                validator: (v) {
                  final key = Validators.email(v);
                  return key == null ? null : context.messageForKey(key);
                },
              ),
              const SizedBox(height: 20),
              AuthPrimaryButton(
                label: t.authSendResetLink,
                busy: state.sending,
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  FocusScope.of(context).unfocus();
                  ref
                      .read(forgotPasswordViewModelProvider.notifier)
                      .submit(_email.text);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
