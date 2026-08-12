import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../navigation/route_names.dart';
import '../widgets/auth_scaffold.dart';
import 'change_password_view_model.dart';

/// Ganti password (Bab 6.8), sekaligus layar paksa bagi packer yang masih
/// memakai password sementara (Bab 6.7).
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _v(String? key) => key == null ? null : context.messageForKey(key);

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final state = ref.watch(changePasswordViewModelProvider);
    final forced = ref.read(changePasswordViewModelProvider.notifier).isForced;

    ref.listen(changePasswordViewModelProvider, (_, next) {
      if (next.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.authPasswordChanged)),
        );
        context.go(Routes.splash);
      }
    });

    // Saat dipaksa, tombol kembali dihilangkan dan tombol perangkat diblokir —
    // packer tidak boleh masuk ke aplikasi dengan password yang sudah dilihat
    // orang lain.
    return PopScope(
      canPop: !forced,
      child: AuthScaffold(
        showBack: !forced,
        title: forced ? t.authMustChangeTitle : t.authChangePasswordTitle,
        subtitle: forced ? t.authMustChangeBody : null,
        children: [
          if (state.failure != null)
            AuthErrorBox(message: context.failureMessage(state.failure!)),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PasswordField(
                  controller: _current,
                  label: t.authCurrentPassword,
                  autofillHints: const [AutofillHints.password],
                  validator: (v) => (v == null || v.isEmpty)
                      ? t.validationPasswordRequired
                      : null,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _next,
                  label: t.authNewPassword,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) => _v(Validators.password(v)),
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _confirm,
                  label: t.authConfirmPassword,
                  textInputAction: TextInputAction.done,
                  validator: (v) =>
                      _v(Validators.confirmPassword(v, _next.text)),
                ),
                const SizedBox(height: 24),
                AuthPrimaryButton(
                  label: t.commonSave,
                  busy: state.busy,
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    FocusScope.of(context).unfocus();
                    ref
                        .read(changePasswordViewModelProvider.notifier)
                        .submit(
                          currentPassword: _current.text,
                          newPassword: _next.text,
                        );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
