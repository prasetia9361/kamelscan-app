import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/payment_methods.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import 'admin_settings_view_model.dart';

/// Metode pembayaran (Bab 11.6).
///
/// 🔴 **Tidak ada kolom untuk kunci rahasia Midtrans di halaman ini, dan itu
/// bukan kelalaian.** Bab 11.6 menuliskannya sebagai larangan: tabel
/// `platform_settings` hanya berisi sakelar aktif/nonaktif. `MIDTRANS_SERVER_KEY`
/// hidup di Edge Function secrets, karena baris `platform_settings` dapat
/// dibaca siapa pun yang berhasil masuk sebagai admin — dan kunci server
/// Midtrans cukup untuk menagih atas nama Anda.
///
/// 🔴 Sakelar Midtrans dapat dinyalakan **tanpa merilis aplikasi baru**. Itu
/// seluruh alasan tabel ini ada: verifikasi merchant Midtrans memakan 5–14
/// hari kerja dan di luar kendali tim, jadi aplikasinya dibangun agar kedua
/// metode hidup berdampingan sejak awal (Bab 12.1).
class AdminPaymentMethodsPage extends ConsumerStatefulWidget {
  const AdminPaymentMethodsPage({super.key});

  @override
  ConsumerState<AdminPaymentMethodsPage> createState() =>
      _AdminPaymentMethodsPageState();
}

class _AdminPaymentMethodsPageState
    extends ConsumerState<AdminPaymentMethodsPage> {
  bool _sedang = false;

  AdminPaymentMethodsViewModel get _vm =>
      ref.read(adminPaymentMethodsViewModelProvider.notifier);

  Future<void> _simpan(PaymentMethods baru) async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _sedang = true);
    final gagal = await _vm.save(baru);
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

  /// 🔴 Mematikan **kedua** metode sekaligus membuat halaman Pembayaran
  /// pelanggan berhenti di "Belum ada metode pembayaran yang aktif" — tidak
  /// ada satu pun jalan membeli paket, dan pendapatan berhenti sampai
  /// seseorang menyadarinya. Karena itu ditanyakan lebih dulu, bukan ditolak:
  /// mematikan keduanya sesekali memang dibutuhkan saat pemeliharaan.
  Future<bool> _izinMatikanSemua() async {
    final t = context.l10n;
    final yakin = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t.adminMethodsAllOffTitle),
        content: Text(t.adminMethodsAllOffBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(d).colorScheme.error,
            ),
            child: Text(t.adminMethodsAllOffConfirm),
          ),
        ],
      ),
    );
    return yakin == true;
  }

  Future<void> _ubahSakelar(PaymentMethods kini, PaymentMethods baru) async {
    if (!baru.midtransEnabled && !baru.manualTransferEnabled) {
      if (!await _izinMatikanSemua()) return;
      if (!mounted) return;
    }
    await _simpan(baru);
  }

  Future<void> _rekening(PaymentMethods kini, {BankAccount? ubah}) async {
    final hasil = await showDialog<BankAccount>(
      context: context,
      builder: (d) => _DialogRekening(awal: ubah),
    );
    if (hasil == null || !mounted) return;

    final daftar = [...kini.bankAccounts];
    final i = ubah == null ? -1 : daftar.indexOf(ubah);
    if (i >= 0) {
      daftar[i] = hasil;
    } else {
      daftar.add(hasil);
    }
    await _simpan(kini.copyWith(bankAccounts: daftar));
  }

  Future<void> _hapusRekening(PaymentMethods kini, BankAccount rek) async {
    final t = context.l10n;
    final yakin = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t.adminMethodsBankDeleteTitle),
        content: Text(t.adminMethodsBankDeleteBody(rek.bank, rek.number)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(d).colorScheme.error,
            ),
            child: Text(t.commonDelete),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    await _simpan(
      kini.copyWith(bankAccounts: [...kini.bankAccounts]..remove(rek)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final async = ref.watch(adminPaymentMethodsViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.adminMethodsTitle)),
      body: async.when(
        loading: () => const AppListSkeleton(itemCount: 3, itemHeight: 90),
        error: (error, _) => AppErrorView(failure: error, onRetry: _vm.refresh),
        data: (m) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    value: m.manualTransferEnabled,
                    onChanged: _sedang
                        ? null
                        : (v) => _ubahSakelar(
                            m,
                            m.copyWith(manualTransferEnabled: v),
                          ),
                    title: Text(t.adminMethodsManual),
                    subtitle: Text(t.adminMethodsManualHelp),
                    isThreeLine: true,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: m.midtransEnabled,
                    onChanged: _sedang
                        ? null
                        : (v) =>
                              _ubahSakelar(m, m.copyWith(midtransEnabled: v)),
                    title: Text(t.adminMethodsMidtrans),
                    subtitle: Text(t.adminMethodsMidtransHelp),
                    isThreeLine: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            // 🔴 Peringatan kunci rahasia berdiri sebagai kartu tersendiri,
            // bukan teks kecil di bawah sakelar. Ini satu-satunya tempat di
            // aplikasi tempat seseorang mungkin tergoda menempelkan kunci
            // server Midtrans, dan akibatnya tidak dapat dibatalkan dengan
            // menghapusnya kembali — kunci yang pernah tersimpan harus
            // diputar ulang di dasbor Midtrans.
            Card(
              margin: EdgeInsets.zero,
              color: colors.warning.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.key_off_outlined,
                      size: 20,
                      color: colors.warning,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.adminMethodsSecretTitle,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.adminMethodsSecretBody,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.adminMethodsBankTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _sedang ? null : () => _rekening(m),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(t.adminMethodsBankAdd),
                ),
              ],
            ),
            const SizedBox(height: 4),

            if (m.bankAccounts.isEmpty)
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    // ⚠️ Transfer manual yang aktif tanpa satu pun rekening
                    // menghasilkan halaman instruksi transfer yang kosong —
                    // pelanggan diminta mentransfer ke mana pun.
                    m.manualTransferEnabled
                        ? t.adminMethodsBankEmptyWarning
                        : t.adminMethodsBankEmpty,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: m.manualTransferEnabled
                          ? colors.danger
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              for (final rek in m.bankAccounts) ...[
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_outlined),
                    title: Text(rek.bank),
                    subtitle: Text('${rek.number} · ${rek.holder}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _sedang
                              ? null
                              : () => _rekening(m, ubah: rek),
                          tooltip: t.commonEdit,
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                        IconButton(
                          onPressed: _sedang
                              ? null
                              : () => _hapusRekening(m, rek),
                          tooltip: t.commonDelete,
                          icon: Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: colors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

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
        ),
      ),
    );
  }
}

/// Formulir satu rekening tujuan transfer.
///
/// 🔴 Ketiga kolomnya wajib. Nomor rekening tanpa nama pemilik tidak dapat
/// diverifikasi pelanggan sebelum ia mengirim uang, dan itu persis keadaan
/// yang dipakai penipu.
class _DialogRekening extends StatefulWidget {
  const _DialogRekening({this.awal});

  final BankAccount? awal;

  @override
  State<_DialogRekening> createState() => _DialogRekeningState();
}

class _DialogRekeningState extends State<_DialogRekening> {
  late final TextEditingController _bank = TextEditingController(
    text: widget.awal?.bank ?? '',
  );
  late final TextEditingController _nomor = TextEditingController(
    text: widget.awal?.number ?? '',
  );
  late final TextEditingController _atasNama = TextEditingController(
    text: widget.awal?.holder ?? '',
  );

  @override
  void dispose() {
    _bank.dispose();
    _nomor.dispose();
    _atasNama.dispose();
    super.dispose();
  }

  bool get _lengkap =>
      _bank.text.trim().isNotEmpty &&
      _nomor.text.trim().isNotEmpty &&
      _atasNama.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return AlertDialog(
      title: Text(
        widget.awal == null ? t.adminMethodsBankAdd : t.adminMethodsBankEdit,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _bank,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: t.adminMethodsBankName,
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nomor,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: t.adminMethodsBankNumber,
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _atasNama,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: t.adminMethodsBankHolder,
                helperText: t.adminMethodsBankHolderHelp,
                helperMaxLines: 2,
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.commonCancel),
        ),
        FilledButton(
          onPressed: _lengkap
              ? () => Navigator.pop(
                  context,
                  BankAccount(
                    bank: _bank.text.trim(),
                    number: _nomor.text.trim(),
                    holder: _atasNama.text.trim(),
                  ),
                )
              : null,
          child: Text(t.commonSave),
        ),
      ],
    );
  }
}
