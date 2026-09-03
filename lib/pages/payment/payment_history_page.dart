import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../core/models/payment_history_entry.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles_display.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_state_views.dart';
import '../../core/widgets/failure_messages.dart';
import '../../l10n/generated/app_localizations.dart';
import 'payment_history_view_model.dart';

/// Riwayat pembayaran (Bab 7.2).
///
/// 🔴 Kenapa layar ini ada, dan kenapa ia berhenti menjadi kemewahan. Diminta
/// Product Owner 3 September 2026 setelah melihat saldonya sendiri menjadi
/// 135.092 token dari tujuh pembelian dan menyadari **tidak ada satu layar pun
/// yang dapat menjelaskan angka itu**. Sejak token menjadi akumulatif (migrasi
/// 40), saldo akhir tidak lagi dapat diterka dari paket yang sedang aktif.
///
/// ⚠️ Satu halaman untuk HP dan web — keputusan Product Owner 3 September
/// 2026. Bentuk kartu, bukan tabel, mengikuti keputusan 29 Agustus yang
/// membatalkan versi tabel untuk layar-layar ini (utang nomor 8): tampilan HP
/// di dalam rangka web sudah dinilai cukup.
///
/// 🔴 Halaman ini juga akhirnya memberi `fetchLedger()` pemanggil pertamanya.
/// Sampai sekarang perbaikan `LedgerReason` (nilai jatuhan `unknown` dan
/// `fromWire`) hanya terbukti lewat tiga tes unit, karena tidak ada satu pun
/// layar yang membaca buku besar. Utang nomor 9 daftar kesiapan produksi.
class PaymentHistoryPage extends ConsumerWidget {
  const PaymentHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final async = ref.watch(paymentHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.paymentHistoryTitle)),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorView(
          failure: e,
          onRetry: () => ref.invalidate(paymentHistoryProvider),
        ),
        data: (daftar) {
          if (daftar.isEmpty) {
            return AppEmptyState(
              icon: Icons.receipt_long_outlined,
              title: t.paymentHistoryEmptyTitle,
              message: t.paymentHistoryEmptyBody,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: daftar.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _KartuPembayaran(entry: daftar[i]),
          );
        },
      ),
    );
  }
}

/// Satu pembayaran. Kelima keterangan yang diminta Product Owner:
/// waktu bayar, tier, jumlah token, kapan masa aktifnya berakhir, dan cara
/// membayarnya.
class _KartuPembayaran extends StatelessWidget {
  const _KartuPembayaran({required this.entry});

  final PaymentHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;
    final t = context.l10n;

    final waktu = entry.paidAt;
    final akhir = entry.periodEnd;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _namaTier(t, entry.plan),
                    style: theme.textTheme.titleMedium,
                  ),
                ),

                // Jumlah token yang benar-benar diberikan. Ditonjolkan karena
                // inilah satu-satunya alasan halaman ini diminta.
                Text(
                  entry.tokensGranted == null
                      // ⚠️ Tanda hubung, BUKAN nol. Nol berarti "tidak ada
                      // token yang diberikan"; yang sebenarnya terjadi adalah
                      // "tidak diketahui". Pada dokumen yang dipakai
                      // menyelesaikan sengketa dengan pelanggan (Bab 7.2 poin
                      // 5), menebak angka lebih berbahaya daripada mengaku
                      // tidak tahu.
                      ? '—'
                      : '+${Formatters.number(entry.tokensGranted!)}',
                  style: AppDisplayStyles.metaMono.copyWith(
                    fontSize: 15,
                    color: entry.tokensGranted == null
                        ? scheme.onSurfaceVariant
                        : colors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            _Baris(
              icon: Icons.event_available_outlined,
              label: t.paymentHistoryPaidAt,
              value: waktu == null ? '—' : Formatters.dateTime(waktu),
            ),
            _Baris(
              icon: Icons.hourglass_bottom_outlined,
              label: t.paymentHistoryPeriodEnd,
              value: akhir == null ? '—' : Formatters.dateTime(akhir),
            ),
            _Baris(
              icon: Icons.account_balance_wallet_outlined,
              label: t.paymentHistoryMethod,
              value: _namaMetode(t, entry.paymentMethod),
            ),
          ],
        ),
      ),
    );
  }

  static String _namaTier(AppL10n t, TierPlan plan) => switch (plan) {
        TierPlan.standar => t.tierStandar,
        TierPlan.pro => t.tierPro,
        TierPlan.bisnis => t.tierBisnis,
      };

  /// ⚠️ `payment_method` adalah **teks bebas** di database (migrasi 07), bukan
  /// enum. Nilai di luar keduanya karena itu ditampilkan apa adanya alih-alih
  /// dijatuhkan ke salah satunya — pada baris yang gunanya membuktikan cara
  /// pembayaran, menampilkan "Transfer manual" untuk sesuatu yang bukan itu
  /// berarti memalsukan bukti.
  static String _namaMetode(AppL10n t, String? metode) => switch (metode) {
        'midtrans' => t.paymentHistoryMethodMidtrans,
        'manual_transfer' => t.paymentHistoryMethodManual,
        null || '' => '—',
        _ => metode,
      };
}

class _Baris extends StatelessWidget {
  const _Baris({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 10),

          // 🔴 `Expanded` + rata kanan. Tanggal dan nama metode panjangnya
          // berbeda-beda, dan tanpa ini keduanya meluber di kolom sempit
          // rangka web (M.17).
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
