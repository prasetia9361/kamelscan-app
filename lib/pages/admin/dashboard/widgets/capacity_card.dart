import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/capacity_status.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/failure_messages.dart';
import '../capacity_view_model.dart';

/// Kartu *Kapasitas platform* (Bab 11.1).
///
/// 🔴 Kartu ini lahir dari satu pertanyaan Product Owner, 31 Agustus 2026:
/// *"apa nanti saya perlu cek setiap hari atau bulan untuk tahu penggunanya
/// berapa dan penggunaan datanya udah berapa?"* — dan jawaban yang jujur
/// adalah **tidak boleh bergantung pada ingatan siapa pun**.
///
/// Supabase tidak mengirim peringatan apa pun sebelum batas 8 GB tercapai.
/// Yang terjadi saat tercapai bukan aplikasi melambat, melainkan penulisan
/// ditolak: packer tidak dapat menyimpan satu video pun, dan tidak ada satu
/// layar pun yang dapat menjelaskan kenapa.
///
/// ⚠️ Yang ditonjolkan adalah **"berapa lama lagi"**, bukan "sudah berapa".
/// Angka 4,2 GB tidak memberi tahu siapa pun kapan harus bertindak.
class CapacityCard extends ConsumerWidget {
  const CapacityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final async = ref.watch(capacityViewModelProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: async.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          // Kegagalannya sengaja tidak menyeret apa pun. Angka pendapatan dan
          // jumlah pelanggan adalah alasan halaman ini dibuka.
          error: (e, _) => SizedBox(
            height: 120,
            child: Center(
              child: Text(
                // `CapacityViewModel` melempar `AppFailure` apa adanya, tetapi
                // galat lain (mis. gagal parse) tetap mungkin sampai ke sini.
                e is AppFailure ? context.failureMessage(e) : t.errorUnknown,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          data: (s) => _Isi(stats: s, colors: colors),
        ),
      ),
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.stats, required this.colors});

  final CapacityStats stats;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);

    final (warna, label) = switch (stats.level) {
      CapacityLevel.aman => (colors.success, t.capacityLevelAman),
      CapacityLevel.siapkan => (colors.warning, t.capacityLevelSiapkan),
      CapacityLevel.bertindak => (colors.danger, t.capacityLevelBertindak),
    };

    final bulan = stats.bulanSampaiPenuh;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.storage_rounded, color: warna),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t.capacityTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Chip status memakai `Wrap` di induknya lewat Expanded di atas,
            // sehingga label panjang tidak pernah mendorong ikonnya keluar.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: warna.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: warna,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 🔴 Ramalannya ditulis paling besar, di atas angka mentahnya.
        // Inilah satu-satunya baris yang menuntut keputusan.
        Text(
          switch (bulan) {
            null => t.capacityForecastNone,
            final b when b < 1 => t.capacityForecastSoon,
            final b => t.capacityForecast(b.toStringAsFixed(0)),
          },
          style: theme.textTheme.titleMedium?.copyWith(
            color: warna,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t.capacityGrowth(Formatters.fileSize(stats.bytes30d)),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: stats.dbRatio,
            minHeight: 8,
            color: warna,
            backgroundColor: warna.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: 8),

        _Baris(
          label: t.capacityDb,
          nilai: '${Formatters.fileSize(stats.dbBytes)} / '
              '${Formatters.fileSize(stats.dbLimitBytes)}',
        ),
        _Baris(
          label: t.capacityRows,
          nilai: Formatters.number(stats.videoRows),
        ),
        _Baris(
          label: t.capacityQueue,
          nilai: Formatters.number(stats.purgeQueue),
          catatan: stats.purgeFailed > 0
              ? t.capacityQueueFailed(stats.purgeFailed)
              : null,
          warnaCatatan: colors.danger,
        ),

        const SizedBox(height: 12),
        Text(
          t.capacityHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({
    required this.label,
    required this.nilai,
    this.catatan,
    this.warnaCatatan,
  });

  final String label;
  final String nilai;
  final String? catatan;
  final Color? warnaCatatan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: theme.textTheme.bodyMedium),
              ),
              const SizedBox(width: 12),
              Text(
                nilai,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (catatan != null)
            Text(
              catatan!,
              style: theme.textTheme.bodySmall?.copyWith(color: warnaCatatan),
            ),
        ],
      ),
    );
  }
}
