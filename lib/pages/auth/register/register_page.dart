import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../navigation/route_names.dart';
import '../widgets/auth_scaffold.dart';
import 'register_view_model.dart';

/// Form registrasi Owner (Bab 6.2).
///
/// Registrasi mandiri **selalu** menghasilkan role `owner`. Tidak ada jalur
/// menjadi `admin` maupun `packer` dari layar ini (Bab 2.1).
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _username = TextEditingController();
  final _businessName = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _agreed = false;
  bool _agreeTouched = false;

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _email,
      _phone,
      _username,
      _businessName,
      _password,
      _confirm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _v(String? key) => key == null ? null : context.messageForKey(key);

  void _submit() {
    setState(() => _agreeTouched = true);
    if (!_formKey.currentState!.validate() || !_agreed) return;
    FocusScope.of(context).unfocus();

    ref.read(registerViewModelProvider.notifier).submit(
          email: _email.text,
          password: _password.text,
          fullName: _fullName.text,
          phone: _phone.text,
          username: _username.text,
          businessName: _businessName.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final state = ref.watch(registerViewModelProvider);
    final busy = state is RegisterBusy;

    ref.listen(registerViewModelProvider, (_, next) {
      if (next is RegisterSucceeded) {
        // Bab 6.4 — arahkan ke layar tunggu verifikasi, bukan langsung Home.
        context.go('${Routes.verifyEmail}?email=${Uri.encodeComponent(next.email)}');
      }
    });

    return AuthScaffold(
      title: t.authRegisterTitle,
      subtitle: t.authRegisterSubtitle,
      children: [
        if (state is RegisterFailed)
          AuthErrorBox(message: context.failureMessage(state.failure)),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _fullName,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(labelText: t.authFullName),
                validator: (v) => _v(Validators.fullName(v)),
                onChanged: (_) =>
                    ref.read(registerViewModelProvider.notifier).clearError(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: t.authEmail),
                validator: (v) => _v(Validators.email(v)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: InputDecoration(
                  labelText: t.authPhone,
                  hintText: '08xxxxxxxxxx',
                ),
                validator: (v) => _v(Validators.phone(v, required: true)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _username,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: t.authUsername,
                  helperText: t.authUsernameHelp,
                  helperMaxLines: 2,
                ),
                validator: (v) => _v(Validators.username(v)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _businessName,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: t.authBusinessName),
                validator: (v) => (v != null && v.trim().length > 80)
                    ? t.validationNameTooLong
                    : null,
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                label: t.authPassword,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) => _v(Validators.password(v)),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirm,
                label: t.authConfirmPassword,
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
                validator: (v) =>
                    _v(Validators.confirmPassword(v, _password.text)),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(t.authAgreeTerms, style: const TextStyle(fontSize: 14)),
              ),
              if (_agreeTouched && !_agreed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    t.authMustAgreeTerms,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 14,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              AuthPrimaryButton(
                label: t.authRegister,
                busy: busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(t.authHaveAccount),
            TextButton(
              onPressed: () => context.pop(),
              child: Text(t.authLogin),
            ),
          ],
        ),
      ],
    );
  }
}
