import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/failure_messages.dart';
import '../widgets/auth_scaffold.dart';
import 'complete_profile_view_model.dart';

/// Lengkapi profil (Bab 6.2).
///
/// Muncul setelah masuk lewat Google, yang tidak pernah memberikan nomor HP
/// maupun kesempatan menyetujui Syarat & Ketentuan — padahal Bab 6.2 menandai
/// keduanya **wajib**.
///
/// ⚠️ Layar ini sengaja **tanpa tombol kembali dan tanpa lewati**. Membiarkan
/// pengguna melewatinya berarti membiarkan akun berjalan tanpa nomor kontak
/// dan tanpa catatan persetujuan — persis keadaan yang hendak diperbaiki.
class CompleteProfilePage extends ConsumerStatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  ConsumerState<CompleteProfilePage> createState() =>
      _CompleteProfilePageState();
}

class _CompleteProfilePageState extends ConsumerState<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  bool _agreed = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _submit() {
    final user = ref.read(sessionProvider).value?.user;
    final needsPhone = user?.needsPhoneInput ?? true;
    final needsTerms = user?.needsTermsAcceptance ?? true;

    if (needsPhone && !(_formKey.currentState?.validate() ?? false)) return;
    if (needsTerms && !_agreed) return;

    debugPrint('KAMELSCAN_PROFIL simpan · kirimHp=$needsPhone'
        ' kirimSetuju=$needsTerms');
    ref.read(completeProfileViewModelProvider.notifier).submit(
          phone: needsPhone ? _phone.text : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final state = ref.watch(completeProfileViewModelProvider);
    final user = ref.watch(sessionProvider).value?.user;

    final needsPhone = user?.needsPhoneInput ?? true;
    final needsTerms = user?.needsTermsAcceptance ?? true;
    final busy = state is CompleteProfileBusy;

    // 🔴 Jejak diagnosis — jangan dihapus tanpa penggantinya.
    //
    // 24 Agustus 2026 layar ini tampil **tanpa satu pun kolom**: hanya judul
    // dan tombol Simpan, dan aplikasi harus ditutup paksa. Keadaan itu hanya
    // mungkin bila `needsPhone` dan `needsTerms` sama-sama padam — dan bila
    // keduanya padam, route guard seharusnya sudah memindahkan layar ini.
    // Satu di antara dua anggapan itu keliru, dan tidak ada cara memilihnya
    // dari tangkapan layar. Baris ini yang akan memilihnya.
    debugPrint('KAMELSCAN_PROFIL bangun · sesiAda=${user != null}'
        ' peran=${user?.role.wire} hp=${user?.phone ?? '-'}'
        ' setuju=${user?.termsAcceptedAt ?? '-'}'
        ' butuhHp=$needsPhone butuhSetuju=$needsTerms'
        ' butuhLengkap=${user?.needsProfileCompletion}');

    // Route guard yang memindahkan halaman setelah selesai; layar ini tidak
    // menavigasi sendiri agar tidak ada dua pihak yang mengatur tujuan.
    return PopScope(
      canPop: false,
      child: AuthScaffold(
        title: t.completeProfileTitle,
        subtitle: t.completeProfileBody,
        children: [
          if (state is CompleteProfileFailed)
            AuthErrorBox(message: context.failureMessage(state.failure)),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (needsPhone) ...[
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    enabled: !busy,
                    decoration: InputDecoration(
                      labelText: t.authPhone,
                      prefixIcon: const Icon(Icons.phone_outlined),
                      helperText: t.completeProfilePhoneHelper,
                    ),
                    validator: (v) {
                      final key = Validators.phone(v, required: true);
                      return key == null ? null : context.messageForKey(key);
                    },
                  ),
                  const SizedBox(height: 20),
                ],
                if (needsTerms)
                  _TermsCheckbox(
                    value: _agreed,
                    enabled: !busy,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                    onOpenTerms: () => _openUrl(AppConstants.termsUrl),
                    onOpenPrivacy: () => _openUrl(AppConstants.privacyUrl),
                  ),
                const SizedBox(height: 28),
                AuthPrimaryButton(
                  label: t.completeProfileSubmit,
                  busy: busy,
                  // Tombol mati sampai persetujuan diberikan — persetujuan
                  // yang dapat dilewati bukan persetujuan.
                  onPressed: (needsTerms && !_agreed) || busy ? null : _submit,
                ),
                const SizedBox(height: 4),
                // 🔴 Jalan keluar, bukan jalan pintas.
                //
                // Layar ini tetap tidak boleh dilewati — menekan tombol ini
                // MENGELUARKAN pengguna, bukan meloloskannya. Yang diperbaiki
                // adalah keadaan tanpa jalan keluar sama sekali: 24 Agustus
                // 2026 pengguna terjebak di sini dengan tombol kembali mati,
                // dan satu-satunya cara pergi adalah menutup paksa aplikasi.
                // Aplikasi tidak boleh punya keadaan yang tidak dapat
                // ditinggalkan penggunanya.
                TextButton(
                  onPressed: busy
                      ? null
                      : () =>
                          ref.read(authRepositoryProvider).signOut(),
                  child: Text(t.accountLogout),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Seluruh baris dapat ditekan, bukan hanya kotak centangnya — target
        // 48 dp untuk tangan bersarung tangan (Bab 9.10).
        InkWell(
          onTap: enabled ? () => onChanged(!value) : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(value: value, onChanged: enabled ? onChanged : null),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      t.authAgreeTerms,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 48),
          child: Wrap(
            spacing: 16,
            children: [
              TextButton(
                onPressed: enabled ? onOpenTerms : null,
                style: _linkStyle,
                child: Text(t.completeProfileReadTerms,
                    style: TextStyle(color: scheme.primary)),
              ),
              TextButton(
                onPressed: enabled ? onOpenPrivacy : null,
                style: _linkStyle,
                child: Text(t.completeProfileReadPrivacy,
                    style: TextStyle(color: scheme.primary)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static final ButtonStyle _linkStyle = TextButton.styleFrom(
    padding: EdgeInsets.zero,
    minimumSize: const Size(0, 40),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}
