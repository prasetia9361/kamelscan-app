import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/pending_payment.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import 'admin_payments_view_model.dart';

/// Verifikasi pembayaran manual (Bab 12.2).
///
/// 🔴 Ini satu-satunya layar di seluruh aplikasi yang menyentuh **uang
/// sungguhan**. Menekan *Setujui* menaikkan tier tenant, mengisi ulang dompet
/// tokennya, dan memulai periode 30 hari — seluruhnya lewat trigger
/// `activate_subscription()` (migrasi 28). **Tidak ada tombol pembatalan.**
///
/// Sampai 28 Agustus 2026 halaman ini hanya berisi 23 baris placeholder,
/// sehingga setiap pembayaran harus dilayani lewat SQL Editor. Product Owner
/// mengalaminya sendiri: transfer 22 Agustus baru menjadi langganan aktif
/// empat hari kemudian, lewat perintah SQL yang ditulis tangan.
class AdminPaymentsPage extends ConsumerWidget {
  const AdminPaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final async = ref.watch(adminPaymentsViewModelProvider);
    final vm = ref.read(adminPaymentsViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.adminPaymentsTitle),
        actions: [
          IconButton(
            onPressed: vm.refresh,
            tooltip: t.commonRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: async.when(
        loading: () => const AppListSkeleton(itemCount: 3, itemHeight: 180),
        error: (error, _) => AppErrorView(failure: error, onRetry: vm.refresh),
        data: (daftar) => daftar.isEmpty
            ? AppEmptyState(
                title: t.adminPaymentsEmptyTitle,
                message: t.adminPaymentsEmptyBody,
                icon: Icons.fact_check_outlined,
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: daftar.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) =>
                    _KartuPembayaran(item: daftar[i]),
              ),
      ),
    );
  }
}

class _KartuPembayaran extends ConsumerStatefulWidget {
  const _KartuPembayaran({required this.item});

  final PendingPayment item;

  @override
  ConsumerState<_KartuPembayaran> createState() => _KartuPembayaranState();
}

class _KartuPembayaranState extends ConsumerState<_KartuPembayaran> {
  bool _sedang = false;

  AdminPaymentsViewModel get _vm =>
      ref.read(adminPaymentsViewModelProvider.notifier);

  /// Membuka bukti transfer di jendela terpisah.
  ///
  /// URL-nya diterbitkan saat ditekan, bukan saat daftar dimuat: bucket-nya
  /// privat dan tautannya hanya hidup 5 menit. Menerbitkannya untuk seluruh
  /// baris di awal berarti sebagian besar sudah mati sebelum sempat dibuka.
  Future<void> _lihatBukti() async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final path = widget.item.subscription.proofUrl;
    if (path == null || path.isEmpty) return;

    setState(() => _sedang = true);
    final url = await _vm.proofUrl(path);
    if (!mounted) return;
    setState(() => _sedang = false);

    if (url == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(t.adminPaymentsProofFailed)),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(t.adminPaymentsViewProof),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  tooltip: t.commonClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Flexible(
              // `InteractiveViewer`: nomor rekening dan nominal pada tangkapan
              // layar m-banking sering kecil sekali. Bukti yang tidak dapat
              // diperbesar sama saja dengan bukti yang tidak dapat dibaca.
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(t.adminPaymentsProofFailed),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setujui() async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final sub = widget.item.subscription;

    // 🔴 Konfirmasi menyebut NAMA USAHA dan PAKETNYA, bukan sekadar "Anda
    // yakin?". Yang ditekan Admin adalah baris ke-sekian dalam daftar, dan
    // satu-satunya penjagaan terhadap menyetujui baris yang salah adalah
    // melihat namanya tertulis ulang sebelum menekan.
    final yakin = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t.adminPaymentsApproveTitle),
        content: Text(t.adminPaymentsApproveBody(
          widget.item.label,
          sub.plan == TierPlan.pro ? t.tierPro : t.tierStandar,
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(t.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(t.adminPaymentsApprove),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    setState(() => _sedang = true);
    final gagal = await _vm.approve(sub.id);
    if (!mounted) return;
    setState(() => _sedang = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          gagal == null
              ? t.adminPaymentsApproved
              : context.failureMessage(gagal),
        ),
      ),
    );
  }

  Future<void> _tolak() async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final alasan = await showDialog<String>(
      context: context,
      builder: (d) => const _DialogTolak(),
    );
    if (alasan == null || !mounted) return;

    setState(() => _sedang = true);
    final gagal = await _vm.reject(widget.item.subscription.id, alasan);
    if (!mounted) return;
    setState(() => _sedang = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          gagal == null
              ? t.adminPaymentsRejected
              : context.failureMessage(gagal),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;
    final sub = widget.item.subscription;
    final dibuat = sub.createdAt;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.packingContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    sub.plan == TierPlan.pro ? t.tierPro : t.tierStandar,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: colors.packing),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 🔴 Nominalnya besar dan memakai angka bertabulasi. Inilah yang
            // dicocokkan Admin dengan mutasi rekening, dan sering berbeda
            // beberapa ratus rupiah karena kode unik transfer — selisih yang
            // hanya terlihat bila angkanya terbaca jelas.
            Text(
              Formatters.currency(sub.amount),
              style: AppTextStyles.statNumber
                  .copyWith(color: scheme.onSurface, fontSize: 28, height: 34 / 28),
            ),
            if (dibuat != null) ...[
              const SizedBox(height: 2),
              Text(
                t.adminPaymentsWaitingSince(Formatters.dateTime(dibuat)),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 14),

            OutlinedButton.icon(
              onPressed: _sedang ? null : _lihatBukti,
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: Text(t.adminPaymentsViewProof),
            ),
            const SizedBox(height: 10),

            // 🔴 `Expanded` di kedua sisi, bukan `SizedBox`. Tombol bertema
            // proyek ini menuntut lebar TAK TERHINGGA
            // (`filledButtonTheme.minimumSize: Size.fromHeight`), dan
            // menaruhnya di dalam `Row` tanpa `Expanded` menggencet
            // tetangganya sampai nol — sudah terjadi dua kali (M.12, M.17).
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _sedang ? null : _tolak,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.danger,
                      ),
                      child: Text(t.adminPaymentsReject),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _sedang ? null : _setujui,
                      child: _sedang
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(t.adminPaymentsApprove),
                    ),
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

/// Dialog penolakan — alasannya wajib, dan **dibaca pelanggan**.
///
/// 🔴 Sampai 29 Agustus 2026 dialog ini hanya bertanya "Anda yakin?". Yang
/// terjadi sesudah Admin menekan Tolak: status berubah menjadi `failed`,
/// spanduk "menunggu verifikasi" di layar pelanggan lenyap, dan tidak ada apa
/// pun yang menggantikannya — tagihannya seolah menguap. Ditemukan Product
/// Owner saat menguji tombol ini pada baris sungguhan.
///
/// Sekarang alasannya tersimpan di `subscriptions.rejection_reason` dan
/// ditampilkan apa adanya kepada pelanggan. Karena itu labelnya menyebut hal
/// itu dengan terang: ini bukan catatan internal, dan singkatan yang hanya
/// dimengerti Admin akan sampai ke orang yang uangnya sudah keluar.
class _DialogTolak extends StatefulWidget {
  const _DialogTolak();

  /// Alasan yang paling sering dipakai, supaya tidak perlu diketik ulang.
  static const List<String> contohAlasan = [
    'Nominal transfer tidak cocok',
    'Bukti transfer tidak terbaca',
    'Transfer tidak ditemukan di mutasi',
  ];

  @override
  State<_DialogTolak> createState() => _DialogTolakState();
}

class _DialogTolakState extends State<_DialogTolak> {
  final TextEditingController _alasan = TextEditingController();

  @override
  void dispose() {
    _alasan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final isi = _alasan.text.trim();

    return AlertDialog(
      title: Text(t.adminPaymentsRejectTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dikatakan apa adanya: aplikasi tidak mengembalikan uang dan
            // tidak mengirim pemberitahuan ke mana pun. Dialog yang
            // menyembunyikan itu membuat Admin mengira keduanya sudah diurus.
            Text(t.adminPaymentsRejectBody, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 14),
            TextField(
              controller: _alasan,
              autofocus: true,
              maxLength: 200,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: t.adminPaymentsRejectReason,
                helperText: t.adminPaymentsRejectReasonHelp,
                helperMaxLines: 2,
                isDense: true,
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final contoh in _DialogTolak.contohAlasan)
                  ActionChip(
                    label: Text(contoh),
                    onPressed: () => setState(() => _alasan.text = contoh),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.commonCancel),
        ),
        TextButton(
          // Mati sampai alasannya terisi. Penjagaan sesungguhnya ada di server
          // (`REASON_REQUIRED`); yang di sini hanya membuat penolakannya
          // terjadi sebelum tombol ditekan, bukan sesudah.
          onPressed: isi.isEmpty ? null : () => Navigator.pop(context, isi),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(t.adminPaymentsReject),
        ),
      ],
    );
  }
}
