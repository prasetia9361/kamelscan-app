import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/platform_contact.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import 'admin_settings_view_model.dart';

/// Kontak dukungan (Bab 11.5).
///
/// 🔴 Nomor WhatsApp di sini adalah **satu-satunya jalan pelanggan menghubungi
/// Anda** saat pembayarannya ditolak, tokennya habis, atau langganannya
/// terkunci — dan sejak hari ini penolakan pembayaran memang mengarahkan
/// pelanggan untuk menghubungi. Satu angka yang keliru mematikan seluruh jalur
/// itu tanpa satu pun galat yang muncul di mana pun.
class AdminContactPage extends ConsumerStatefulWidget {
  const AdminContactPage({super.key});

  @override
  ConsumerState<AdminContactPage> createState() => _AdminContactPageState();
}

class _AdminContactPageState extends ConsumerState<AdminContactPage> {
  final _wa = TextEditingController();
  final _email = TextEditingController();
  final _alamat = TextEditingController();

  bool _sedang = false;
  bool _terisi = false;

  @override
  void dispose() {
    _wa.dispose();
    _email.dispose();
    _alamat.dispose();
    super.dispose();
  }

  /// Diisi sekali saja — penyegaran sesudah menyimpan tidak boleh menimpa apa
  /// yang sedang diketik.
  void _isiSekali(PlatformContact c) {
    if (_terisi) return;
    _terisi = true;
    _wa.text = c.whatsapp;
    _email.text = c.email;
    _alamat.text = c.address;
  }

  PlatformContact get _isian => PlatformContact(
    whatsapp: _wa.text.trim(),
    email: _email.text.trim(),
    address: _alamat.text.trim(),
  );

  Future<void> _simpan() async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final isian = _isian;

    // 🔴 Nomor lokal `08…` menghasilkan tautan `wa.me` yang TERBUKA tetapi
    // tidak menemukan siapa-siapa — gagal dengan cara yang paling sulit
    // disadari, karena tidak ada galat sama sekali. Ditanyakan sebelum
    // disimpan, bukan ditolak: nomor luar negeri juga sah.
    if (isian.whatsapp.isNotEmpty && !isian.waLooksInternational) {
      final lanjut = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(t.adminContactWaFormatTitle),
          content: Text(t.adminContactWaFormatBody(isian.whatsapp)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(t.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text(t.adminContactWaFormatConfirm),
            ),
          ],
        ),
      );
      if (lanjut != true || !mounted) return;
    }

    setState(() => _sedang = true);
    final gagal = await ref
        .read(adminContactViewModelProvider.notifier)
        .save(isian);
    if (!mounted) return;
    setState(() => _sedang = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          gagal == null ? t.adminSettingsSaved : context.failureMessage(gagal),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final async = ref.watch(adminContactViewModelProvider);
    final vm = ref.read(adminContactViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(t.adminContactTitle)),
      body: async.when(
        loading: () => const AppListSkeleton(itemCount: 3, itemHeight: 72),
        error: (error, _) => AppErrorView(failure: error, onRetry: vm.refresh),
        data: (c) {
          _isiSekali(c);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Card(
                margin: EdgeInsets.zero,
                color: colors.packingContainer.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    t.adminContactIntro,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _wa,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: t.adminContactWhatsapp,
                  helperText: t.adminContactWhatsappHelp,
                  helperMaxLines: 2,
                  prefixIcon: const Icon(Icons.chat_outlined),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: t.adminContactEmail,
                  prefixIcon: const Icon(Icons.mail_outline),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _alamat,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: t.adminContactAddress,
                  helperText: t.adminContactAddressHelp,
                  helperMaxLines: 2,
                  isDense: true,
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _sedang ? null : _simpan,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(t.commonSave),
                ),
              ),
              if (_sedang) ...[
                const SizedBox(height: 16),
                const Center(
                  child: SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
