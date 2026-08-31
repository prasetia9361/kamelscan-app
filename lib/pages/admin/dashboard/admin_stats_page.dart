import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/platform_stats.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import 'admin_stats_view_model.dart';
import 'widgets/capacity_card.dart';

/// Dasbor platform Admin (Bab 11.1).
///
/// 🔴 Satu-satunya layar yang menampilkan angka **lintas seluruh pelanggan**.
/// Penjagaannya berada di server: `get_platform_stats()` menolak siapa pun
/// yang bukan admin dengan galat, bukan dengan angka nol. Yang bukan admin
/// karena itu melihat pesan "tidak memiliki akses", bukan dasbor kosong yang
/// terbaca sebagai "platform belum punya pelanggan".
class AdminStatsPage extends ConsumerWidget {
  const AdminStatsPage({super.key});

  static const double fourColumnWidth = 1000;
  static const double twoColumnWidth = 600;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final async = ref.watch(adminStatsViewModelProvider);
    final vm = ref.read(adminStatsViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.adminStatsTitle),
        actions: [
          IconButton(
            onPressed: vm.refresh,
            tooltip: t.commonRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: async.when(
        loading: () => const AppListSkeleton(itemCount: 4, itemHeight: 110),
        error: (error, _) => AppErrorView(failure: error, onRetry: vm.refresh),
        data: (stats) => _Isi(stats: stats),
      ),
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.stats});

  final PlatformStats stats;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    /// Margin negatif. Dihitung sekali di sini supaya warna, ikon, dan
    /// kalimatnya tidak mungkin berbeda pendapat.
    final rugi = (stats.margin ?? 0) < 0;

    return LayoutBuilder(
      builder: (context, batas) {
        final kolom = switch (batas.maxWidth) {
          >= AdminStatsPage.fourColumnWidth => 4,
          >= AdminStatsPage.twoColumnWidth => 2,
          _ => 1,
        };
        const jarak = 12.0;
        const padding = 16.0;
        // Lebar dihitung, bukan diserahkan ke `Expanded` di dalam `Wrap` —
        // `Wrap` tidak punya sisa ruang untuk dibagi.
        final lebar =
            (batas.maxWidth - padding * 2 - jarak * (kolom - 1)) / kolom;

        final kartu = <Widget>[
          _Kartu(
            label: t.adminStatsCustomers,
            value: Formatters.number(stats.paidActive),
            note: t.adminStatsPlanBreakdown(
              Formatters.number(stats.standarActive),
              Formatters.number(stats.proActive),
            ),
            icon: Icons.workspace_premium_outlined,
            color: colors.success,
          ),
          _Kartu(
            label: t.adminStatsTrial,
            value: Formatters.number(stats.trialCount),
            note: t.adminStatsSuspended,
            noteValue: Formatters.number(stats.suspendedCount),
            icon: Icons.hourglass_bottom_outlined,
            color: colors.warning,
          ),
          _Kartu(
            label: t.adminStatsNewThisMonth,
            value: Formatters.number(stats.newThisMonth),
            icon: Icons.person_add_alt_outlined,
            color: colors.packing,
          ),
          _Kartu(
            label: t.adminStatsMrr,
            value: Formatters.currency(stats.mrr),
            note: t.adminStatsMrrNote,
            icon: Icons.payments_outlined,
            color: colors.success,
          ),

          // 🔴 DUA hal yang keduanya soal kejujuran angka ini.
          //
          // Pertama: margin yang belum dapat dihitung ditulis sebagai belum
          // diisi, BUKAN sama dengan MRR. MRR dikurangi nol menghasilkan angka
          // yang persis sama, dan di layar ia terbaca sebagai "seluruh
          // pendapatan adalah keuntungan".
          //
          // Kedua: margin MINUS tidak boleh berwarna hijau.
          //
          // Terlihat pertama kali di layar Product Owner 29 Agustus 2026:
          // margin -Rp 53.000 tertulis dengan warna keberhasilan. Pada dasbor
          // keuangan itu jenis kesalahan yang paling menyesatkan — mata
          // membaca warnanya lebih dulu daripada tanda minusnya, dan yang
          // membacanya sekilas akan menyimpulkan usahanya untung.
          //
          // Warnanya berubah DAN ikonnya ikut berubah: palet §7 melarang
          // makna yang hanya disampaikan lewat warna, dan rugi-untung adalah
          // makna yang paling mahal bila salah dibaca.
          _Kartu(
            label: t.adminStatsMargin,
            value: stats.margin == null
                ? '—'
                : Formatters.currency(stats.margin!),
            note: stats.needsInfraCost
                ? t.adminStatsNoInfraCost
                : (rugi
                    ? t.adminStatsLoss
                    : t.adminStatsInfraCost(
                        Formatters.currency(stats.infraCost!))),
            noteColor: stats.needsInfraCost
                ? colors.warning
                : (rugi ? colors.danger : null),
            icon: rugi
                ? Icons.trending_down_rounded
                : Icons.savings_outlined,
            color: stats.needsInfraCost
                ? theme.colorScheme.outline
                : (rugi ? colors.danger : colors.success),
          ),

          _Kartu(
            label: t.adminStatsVideos,
            value: Formatters.number(stats.totalVideos),
            // ⚠️ Keterangan ini WAJIB. Angka ini dan angka penyimpanan di
            // sebelahnya memang tidak akan pernah cocok — yang satu menghitung
            // yang pernah direkam, yang lain yang masih tersimpan. Selisih
            // yang tidak dijelaskan terbaca sebagai kerusakan (O.16).
            note: t.adminStatsVideosNote,
            icon: Icons.video_library_outlined,
            color: colors.packing,
          ),
          _Kartu(
            label: t.adminStatsStorage,
            value: Formatters.fileSize(stats.storageBytes),
            note: t.adminStatsStorageNote,
            icon: Icons.cloud_outlined,
            color: colors.returnColor,
          ),
        ];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: jarak,
                runSpacing: jarak,
                children: [
                  for (final k in kartu) SizedBox(width: lebar, child: k),
                ],
              ),

              // Kartu Kapasitas berdiri sendiri di bawah, selebar layar.
              //
              // 🔴 Sengaja TIDAK ikut ke dalam `Wrap` di atas. Kartu-kartu itu
              // menjawab "berapa"; yang ini menjawab "kapan harus bertindak",
              // dan menempatkannya sebagai kotak kesekian membuatnya terbaca
              // sebagai angka lain yang boleh dilewati.
              const SizedBox(height: jarak),
              const CapacityCard(),
            ],
          ),
        );
      },
    );
  }
}

class _Kartu extends StatelessWidget {
  const _Kartu({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.note,
    this.noteValue,
    this.noteColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? note;

  /// Angka kedua yang ditempelkan ke [note] — dipakai kartu yang menampung
  /// dua keadaan sekaligus (uji coba + ditangguhkan).
  final String? noteValue;

  /// Warna keterangan bila ia membawa peringatan. null = warna biasa.
  ///
  /// 🔴 Dipisah dari warna angkanya supaya keduanya tidak mungkin berbeda
  /// pendapat — kartu yang angkanya merah tetapi keterangannya oranye membuat
  /// pembacanya berhenti menebak mana yang benar.
  final Color? noteColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final keterangan = note;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Nominal rupiah pada platform yang tumbuh bisa menembus sembilan
            // digit. Mengecilkan angka lebih baik daripada memotongnya.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppTextStyles.statNumber
                    .copyWith(color: color, fontSize: 26, height: 32 / 26),
              ),
            ),
            if (keterangan != null) ...[
              const SizedBox(height: 6),
              Text(
                noteValue == null ? keterangan : '$keterangan: $noteValue',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: noteColor ?? scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
