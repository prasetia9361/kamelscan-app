import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../navigation/route_names.dart';
import '../widgets/auth_scaffold.dart';
import 'reset_password_view_model.dart';

/// Buat password baru setelah membuka tautan dari email (Bab 6.8).
///
/// 🔴 Layar ini adalah **tujuan yang selama ini hilang**. Tautan reset sudah
/// dikirim dan sudah membentuk sesi, tetapi tidak ada satu pun layar yang
/// meminta password baru — sehingga alur *Lupa password* tidak pernah dapat
/// diselesaikan sampai tuntas.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _v(String? key) => key == null ? null : context.messageForKey(key);

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final state = ref.watch(resetPasswordViewModelProvider);

    ref.listen(resetPasswordViewModelProvider, (_, next) {
      if (!next.done) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.authPasswordChanged)),
      );
      // Layar pembuka menentukan tujuan berikutnya, sama seperti jalur masuk
      // biasa — supaya tidak ada dua pihak yang memutuskan tujuan.
      context.go(Routes.splash);
    });

    // Tombol perangkat diblokir, tetapi jalan keluarnya ada di layar: tombol
    // *Batal* di bawah mengakhiri pemulihan dan kembali ke layar Masuk.
    return PopScope(
      canPop: false,
      child: AuthScaffold(
        showBack: false,
        title: t.authResetTitle,
        subtitle: t.authResetBody,
        children: [
          if (state.failure != null)
            AuthErrorBox(message: context.failureMessage(state.failure!)),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                        .read(resetPasswordViewModelProvider.notifier)
                        .submit(_next.text);
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: state.busy
                      ? null
                      : () => ref
                          .read(resetPasswordViewModelProvider.notifier)
                          .cancel(),
                  child: Text(t.commonCancel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
