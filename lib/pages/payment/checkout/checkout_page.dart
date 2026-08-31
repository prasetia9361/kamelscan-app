import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/payment_methods.dart';
import '../../../core/models/subscription.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../navigation/route_names.dart';
import 'checkout_view_model.dart';

/// Instruksi transfer manual + unggah bukti (Bab 12.2 langkah 3–5).
class CheckoutPage extends ConsumerWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final async = ref.watch(checkoutViewModelProvider);
    final vm = ref.read(checkoutViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(t.checkoutTitle)),
      body: switch (async) {
        AsyncValue(:final value?) => _Body(data: value),
        AsyncError(:final error) => AppErrorView(
          failure: error,
          onRetry: vm.refresh,
        ),
        _ => const AppListSkeleton(),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.data});

  final CheckoutData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final tagihan = data.bill;

    if (tagihan == null) {
      return AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: t.paymentNoMethodTitle,
        message: t.paymentPendingBody,
      );
    }

    // Sudah dibayar dan buktinya terkirim — yang tersisa menunggu Admin.
    // Layar ini berhenti menyuruh melakukan apa pun.
    if (tagihan.isWaitingVerification) {
      return _WaitingVerification(data: data, bill: tagihan);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _Countdown(bill: tagihan),
        const SizedBox(height: 16),
        _AmountCard(bill: tagihan),
        const SizedBox(height: 16),
        _BankList(accounts: data.accounts),
        const SizedBox(height: 16),
        _UploadCard(bill: tagihan),
        if (data.whatsapp != null) ...[
          const SizedBox(height: 16),
          _HelpCard(whatsapp: data.whatsapp!),
        ],
      ],
    );
  }
}

/// Hitung mundur 24 jam (Bab 12.2 langkah 3).
///
/// Berdetak tiap detik, tetapi angkanya dihitung dari `created_at` — bukan
/// dikurangi satu tiap kali. Penghitung yang mengurangi dirinya sendiri akan
/// meleset begitu aplikasi masuk latar belakang, dan melesetnya selalu ke arah
/// yang menguntungkan aplikasi: layar mengaku masih ada waktu padahal habis.
class _Countdown extends ConsumerStatefulWidget {
  const _Countdown({required this.bill});

  final Subscription bill;

  @override
  ConsumerState<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends ConsumerState<_Countdown> {
  Timer? _detak;
  late Duration _sisa;
  bool _sedangBatal = false;

  /// Membatalkan tagihan basi ini, lalu kembali ke halaman paket.
  ///
  /// 🔴 Sampai 31 Agustus 2026 tombol di bawah hanya berpindah halaman tanpa
  /// membatalkan apa pun — dan di halaman paket tagihan lamanya masih berdiri
  /// dengan tombol Bayar yang mati. Tombolnya menjanjikan jalan keluar lalu
  /// memutar kembali ke tempat yang sama, dan Product Owner tersangkut di
  /// putaran itu dari Kamis sampai Minggu.
  Future<void> _batalkanLaluBaru() async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    setState(() => _sedangBatal = true);
    final gagal = await ref
        .read(checkoutViewModelProvider.notifier)
        .cancelBill();
    if (!mounted) return;
    setState(() => _sedangBatal = false);

    if (gagal != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.failureMessage(gagal))),
      );
      return;
    }

    messenger.showSnackBar(SnackBar(content: Text(t.paymentCancelled)));
    router.go(Routes.payment);
  }

  @override
  void initState() {
    super.initState();
    _sisa = widget.bill.remainingToTransfer(DateTime.now());
    _detak = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _sisa = widget.bill.remainingToTransfer(DateTime.now()));
    });
  }

  @override
  void dispose() {
    _detak?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final habis = _sisa == Duration.zero;

    if (habis) {
      return Card(
        margin: EdgeInsets.zero,
        color: colors.danger.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.timer_off_rounded, size: 20, color: colors.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.checkoutExpiredTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(t.checkoutExpiredBody, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: _sedangBatal ? null : _batalkanLaluBaru,
                  child: _sedangBatal
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(t.checkoutNewBill),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final jam = _sisa.inHours;
    final menit = _sisa.inMinutes % 60;
    final detik = _sisa.inSeconds % 60;
    final teks =
        '${jam}j ${menit.toString().padLeft(2, '0')}m '
        '${detik.toString().padLeft(2, '0')}d';

    return Row(
      children: [
        Icon(Icons.schedule_rounded, size: 18, color: colors.warning),
        const SizedBox(width: 8),
        Text(
          t.checkoutDeadline(teks),
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.warning),
        ),
      ],
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.bill});

  final Subscription bill;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    final nama = bill.plan == TierPlan.pro ? t.planPro : t.planStandar;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.checkoutBillFor(nama), style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(t.checkoutAmountLabel, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    Formatters.currency(bill.amount),
                    // Huruf monospace dengan alasan yang sama seperti nomor
                    // resi dan password sementara: angka ini akan disalin
                    // dengan tangan ke aplikasi bank, dan pada huruf biasa
                    // `0`/`O` serta `1`/`l` nyaris tidak terbedakan.
                    style: AppTextStyles.resiInline.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: t.commonCopy,
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(
                      // Disalin sebagai angka polos, tanpa "Rp" dan tanpa titik
                      // ribuan — begitulah bentuk yang diterima kolom nominal
                      // aplikasi bank.
                      ClipboardData(text: bill.amount.toStringAsFixed(0)),
                    );
                    messenger.showSnackBar(
                      SnackBar(content: Text(t.commonCopied)),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 20),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: colors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.checkoutUniqueNote,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BankList extends StatelessWidget {
  const _BankList({required this.accounts});

  final List<BankAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);

    if (accounts.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Text(t.paymentNoMethodBody, style: theme.textTheme.bodyMedium),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.checkoutBankTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final akun in accounts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(akun.bank, style: theme.textTheme.bodySmall),
                          Text(
                            akun.number,
                            style: AppTextStyles.resiInline.copyWith(
                              fontSize: 18,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            t.checkoutAccountHolder(akun.holder),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: t.commonCopy,
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await Clipboard.setData(
                          ClipboardData(text: akun.number),
                        );
                        messenger.showSnackBar(
                          SnackBar(content: Text(t.commonCopied)),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UploadCard extends ConsumerStatefulWidget {
  const _UploadCard({required this.bill});

  final Subscription bill;

  @override
  ConsumerState<_UploadCard> createState() => _UploadCardState();
}

class _UploadCardState extends ConsumerState<_UploadCard> {
  bool _sedangKirim = false;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.checkoutUploadTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(t.checkoutUploadBody, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _sedangKirim ? null : _pilihBukti,
                icon: _sedangKirim
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(t.checkoutUploadButton),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bukti transfer **tidak dipotong**, berbeda dari foto profil.
  ///
  /// Yang dicari Admin di gambar itu ada di beberapa tempat sekaligus: nominal,
  /// jam transfer, nama penerima, dan status berhasil. Memaksa Owner memotongnya
  /// menjadi persegi hampir pasti membuang salah satunya, dan buktinya menjadi
  /// tidak dapat diverifikasi.
  ///
  /// Dikecilkan seperlunya saja: bucket `payment-proofs` menolak berkas di atas
  /// 5 MB (migrasi 25), sementara tangkapan layar m-banking biasanya jauh di
  /// bawah itu.
  Future<void> _pilihBukti() async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    final Uint8List bytes = await picked.readAsBytes();
    if (!mounted) return;

    setState(() => _sedangKirim = true);
    final failure = await ref
        .read(checkoutViewModelProvider.notifier)
        .uploadProof(bytes);

    if (!mounted) return;
    setState(() => _sedangKirim = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failure == null
              ? t.checkoutUploaded
              : context.failureMessage(failure),
        ),
      ),
    );
  }
}

class _WaitingVerification extends ConsumerWidget {
  const _WaitingVerification({required this.data, required this.bill});

  final CheckoutData data;
  final Subscription bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        Icon(Icons.hourglass_top_rounded, size: 56, color: colors.warning),
        const SizedBox(height: 16),
        Text(
          t.checkoutWaitingTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          t.checkoutWaitingBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        _AmountCard(bill: bill),
        const SizedBox(height: 16),

        // Tetap dapat mengganti bukti selama Admin belum memeriksanya —
        // Owner yang terlanjur mengunggah gambar yang salah tidak punya jalan
        // lain, dan menunggu penolakan Admin memakan sehari penuh.
        _UploadCard(bill: bill),

        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: () => _lihatBukti(context, ref),
            icon: const Icon(Icons.image_outlined, size: 18),
            label: Text(t.checkoutViewProof),
          ),
        ),

        if (data.whatsapp != null) ...[
          const SizedBox(height: 8),
          _HelpCard(whatsapp: data.whatsapp!),
        ],
      ],
    );
  }

  Future<void> _lihatBukti(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final t = context.l10n;

    final url = await ref.read(checkoutViewModelProvider.notifier).proofUrl();
    if (!context.mounted) return;

    if (url == null) {
      messenger.showSnackBar(SnackBar(content: Text(t.errorUnknown)));
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(
            url,
            errorBuilder: (_, _, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(t.errorUnknown),
            ),
          ),
        ),
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.whatsapp});

  final String whatsapp;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                t.checkoutHelpTitle,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://wa.me/$whatsapp'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: Text(t.checkoutHelpWhatsapp),
            ),
          ],
        ),
      ),
    );
  }
}
