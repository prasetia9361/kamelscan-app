import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/domain/quota_status.dart';
import '../../core/models/enums.dart';
import '../../core/models/home_stats.dart';
import '../../core/providers/pipeline_providers.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/upload_queue_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_state_views.dart';
import '../../core/widgets/failure_messages.dart';
import '../../core/widgets/quota_widgets.dart';
import '../../navigation/route_names.dart';
import 'home_view_model.dart';

/// Beranda — kartu monitoring + menu utama (Bab 9.2).
///
/// Halaman ini adalah satu-satunya tempat Owner dapat melihat saldo token dan
/// jumlah video tanpa membuka database, jadi ia dikerjakan lebih dulu di antara
/// seluruh Bab 9.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(homeViewModelProvider);

    // 🔴 Jejak diagnosis — pasangan `KAMELSCAN_SHELL`, lihat alasannya di
    // `MobileShell`. Bila baris ini tidak pernah tercetak saat Beranda kosong,
    // HomePage memang tidak pernah dibangun dan sebabnya di navigasi.
    debugPrint('KAMELSCAN_HOME bangun · ${stats.runtimeType} '
        'punyaNilai=${stats.hasValue} error=${stats.hasError}');

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: ref.read(homeViewModelProvider.notifier).refresh,
        // Urutannya disengaja: begitu angkanya pernah ada, angka itu tetap
        // berdiri walaupun pemuatan ulang sedang berjalan atau gagal. Layar
        // yang berkedip jadi skeleton tiap kali disegarkan akan terasa rusak,
        // padahal isinya masih benar.
        child: switch (stats) {
          AsyncValue(:final value?) => _HomeBody(stats: value),
          AsyncError(:final error) => ListView(
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                AppErrorView(
                  failure: error,
                  onRetry: ref.read(homeViewModelProvider.notifier).refresh,
                ),
              ],
            ),
          // Bab 9.10 — skeleton, bukan spinner di tengah layar.
          _ => const _HomeSkeleton(),
        },
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.stats});

  final HomeStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final session = ref.watch(sessionProvider).value;
    final isTrial = session?.isTrial ?? false;
    final quota = stats.quota(isTrial: isTrial);
    final isOwner = session?.isOwner ?? false;

    return ListView(
      // Jarak bawah 88 dp: tombol Rekam mengambang di sudut kanan bawah
      // menumpang di atas isi halaman dan akan menutupi baris terakhir.
      // Alasan yang sama sudah tercatat di `AccountPage`.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        // Bab 7.3 & 7.6 — kedua spanduk ini memang rumahnya di Beranda.
        // Keduanya menyembunyikan dirinya sendiri saat belum perlu, jadi tidak
        // ada syarat yang perlu diperiksa di sini.
        QuotaBanner(
          quota: quota,
          onAction: isOwner ? () => context.push(Routes.payment) : null,
        ),
        if (session != null)
          SubscriptionExpiryBanner(
            subscription: session.subscription,
            onAction: isOwner ? () => context.push(Routes.payment) : null,
          ),
        const _QueueBanner(),
        if (stats.hasFailedUploads) _FailedBanner(count: stats.failedUpload),

        // Keterangan periode berdiri sekali di sini, bukan diulang di tiap
        // kartu. Ia menerangkan ketiga angka sekaligus, dan pada lebar
        // sepertiga layar pengulangannya memakan ruang yang dibutuhkan
        // angkanya sendiri.
        //
        // 🔴 Tetap wajib ada: tanpa ini angkanya benar tetapi pembacanya
        // menduga "bulan ini" — dan dugaan itu salah, karena periode dihitung
        // sejak dompet token dimulai (keputusan Product Owner 18 Agustus 2026).
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            _SectionTitle(t.homeMonitoringTitle),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t.homePeriodSince(Formatters.date(stats.periodStart)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _MonitoringRow(stats: stats, quota: quota, isOwner: isOwner),

        if (stats.isEmpty) ...[
          const SizedBox(height: 12),
          Text(
            t.homeEmptyHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],

        const SizedBox(height: 24),
        _SectionTitle(t.homeMenuTitle),
        const SizedBox(height: 8),
        _MenuGrid(canRecord: session?.canRecord ?? false, isOwner: isOwner),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleMedium);
}

// ---------------------------------------------------------------------------
// Bagian 1 — Monitoring
// ---------------------------------------------------------------------------

/// Tiga kartu **muat sekaligus** dalam satu layar (Bab 9.2).
///
/// 🔴 Semula tergulir mendatar dengan lebar tetap 200 dp, persis seperti bunyi
/// Bab 9.2. Product Owner mengujinya di Redmi Note 9 pada 18 Agustus 2026 dan
/// menolaknya: kartu ketiga — **saldo token** — berada di luar layar, sehingga
/// angka yang paling sering dicari justru satu-satunya yang harus dicari.
///
/// Bab 9.2 menyebut "dapat digulir horizontal" sebagai bentuk, bukan tujuan.
/// Tujuannya adalah ketiga angka terlihat; menggulir hanya jalan keluar bila
/// tidak muat. Pada lebar 360 dp ke atas ketiganya muat, jadi tidak digulir.
class _MonitoringRow extends StatelessWidget {
  const _MonitoringRow({
    required this.stats,
    required this.quota,
    required this.isOwner,
  });

  final HomeStats stats;
  final QuotaStatus quota;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;

    return SizedBox(
      height: 138,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatCard(
              label: t.homeCardPacking,
              value: stats.packingCount,
              color: colors.packing,
              icon: Icons.inventory_2_outlined,
              onTap: () => context
                  .push(Routes.historyOf(typeWire: VideoType.packing.wire)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              label: t.homeCardReturn,
              value: stats.returnCount,
              color: colors.returnColor,
              icon: Icons.assignment_return_outlined,
              onTap: () => context
                  .push(Routes.historyOf(typeWire: VideoType.returned.wire)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              label: quota.isTrial ? t.trialQuotaLabel : t.tokenBalanceLabel,
              value: quota.balance,
              // Warna & ambangnya tetap datang dari aturan Bab 7.3 yang sudah
              // teruji, bukan ditentukan ulang di sini.
              color: colors.tokenIndicator(quota.ratio),
              icon: Icons.confirmation_number_outlined,
              total: quota.quota > 0 ? quota.quota : null,
              progress: quota.quota > 0 ? quota.ratio : null,
              onTap: isOwner ? () => context.push(Routes.payment) : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu kartu pantauan. Lebarnya ditentukan induknya — sepertiga layar.
///
/// Ketiganya memakai bentuk yang **sama persis**, termasuk kartu token. Dua
/// bentuk berbeda yang berdiri bersebelahan membuat mata membandingkan
/// kotaknya, bukan angkanya.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.onTap,
    this.total,
    this.progress,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  /// Penyebut untuk kartu token: `73` **/ 100**. null pada kartu video.
  final int? total;

  /// Palang sisa kuota 0..1. null pada kartu video.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              // Sepertiga layar itu sempit, dan tenant sibuk bisa menembus
              // empat digit. FittedBox mengecilkan angkanya alih-alih
              // memotongnya — angka bukti yang terpotong lebih buruk daripada
              // angka yang kecil.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      Formatters.number(value),
                      style: AppTextStyles.statNumber
                          .copyWith(color: color, fontSize: 30, height: 34 / 30),
                    ),
                    if (total != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '/ ${Formatters.number(total!)}',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Spanduk antrian
// ---------------------------------------------------------------------------

/// *"4 video menunggu diunggah"* beserta tombol **Unggah sekarang**.
///
/// ⚠️ Angkanya diambil dari antrian **lokal**, bukan dari `pending_upload`
/// milik server. Bab 8.7 / L.5: baris `package_videos` baru dibuat saat
/// mengunggah, jadi video yang direkam di gudang tanpa sinyal belum punya baris
/// di server sama sekali — padahal justru itu yang perlu diberitahukan.
class _QueueBanner extends ConsumerWidget {
  const _QueueBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pendingUploadCountProvider).value ?? 0;
    if (count == 0) return const SizedBox.shrink();

    final t = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;

    return _InfoBanner(
      message: t.homeQueueWaiting(count),
      icon: Icons.cloud_upload_outlined,
      color: colors.warning,
      actionLabel: t.homeQueueUploadNow,
      onAction: () => ref.read(uploadQueueRunnerProvider).run(),
    );
  }
}

class _FailedBanner extends StatelessWidget {
  const _FailedBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;

    return _InfoBanner(
      message: t.homeFailedUploads(count),
      icon: Icons.error_outline_rounded,
      color: colors.danger,
      actionLabel: t.homeFailedAction,
      onAction: () => context.push(Routes.history),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.message,
    required this.icon,
    required this.color,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final IconData icon;
  final Color color;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bagian 2 — Menu utama
// ---------------------------------------------------------------------------

class _MenuGrid extends ConsumerWidget {
  const _MenuGrid({required this.canRecord, required this.isOwner});

  final bool canRecord;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;

    // Bab 9.2 — saat saldo habis, kedua menu perekaman tampil abu-abu dengan
    // label kecil "Token habis" dan menekannya membuka Pembayaran. Untuk packer
    // jalan itu buntu (Pembayaran hanya Owner), jadi ia diberi kalimat yang
    // dapat ditindaklanjuti alih-alih pintu yang tertutup.
    void whenLocked() {
      if (isOwner) {
        context.push(Routes.payment);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.homeTokenExhaustedPacker)),
        );
      }
    }

    // Jenis paket dibawa ke layar setup lewat query, dan diteruskan dari sana
    // sampai ke baris `package_videos`. Sebelum 18 Agustus 2026 seluruh alur
    // rekam memaku `packing`, sehingga menu ini akan menyimpan video return
    // dengan tipe yang salah — dan indeks `uq_resi_per_tenant_type` membuat
    // akibatnya baru terasa jauh kemudian.
    void record(VideoType type) =>
        context.push(Routes.recordSetupOf(typeWire: type.wire));

    final tiles = <Widget>[
      _MenuTile(
        label: t.homeMenuRecordPacking,
        icon: Icons.inventory_2_outlined,
        color: colors.packing,
        locked: !canRecord,
        lockedLabel: t.tokenExhaustedMenuLabel,
        onTap: canRecord ? () => record(VideoType.packing) : whenLocked,
      ),
      _MenuTile(
        label: t.homeMenuRecordReturn,
        icon: Icons.assignment_return_outlined,
        color: colors.returnColor,
        locked: !canRecord,
        lockedLabel: t.tokenExhaustedMenuLabel,
        onTap: canRecord ? () => record(VideoType.returned) : whenLocked,
      ),
      if (isOwner)
        _MenuTile(
          label: t.navPayment,
          icon: Icons.credit_card_rounded,
          color: colors.success,
          onTap: () => context.push(Routes.payment),
        ),
      _MenuTile(
        label: t.navTutorial,
        icon: Icons.school_outlined,
        color: Theme.of(context).colorScheme.primary,
        onTap: () => context.push(Routes.tutorial),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: tiles,
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.locked = false,
    this.lockedLabel,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool locked;
  final String? lockedLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Abu-abu, tetapi **tetap dapat ditekan** — Bab 7.3: tombol mati tanpa
    // penjelasan adalah cara tercepat membuat pengguna mengira aplikasinya
    // rusak.
    final tint = locked ? scheme.outline : color;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 30, color: tint),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: locked ? scheme.onSurfaceVariant : scheme.onSurface,
                    ),
              ),
              if (locked && lockedLabel != null)
                Text(
                  lockedLabel!,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.error),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kondisi memuat
// ---------------------------------------------------------------------------

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    Widget block(double h, {double? w}) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: colors.shimmerBase,
            borderRadius: BorderRadius.circular(16),
          ),
        );

    return Shimmer.fromColors(
      baseColor: colors.shimmerBase,
      highlightColor: colors.shimmerHighlight,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          block(20, w: 120),
          const SizedBox(height: 12),
          // Bentuknya menyamai isi yang akan menggantikannya — tiga kartu
          // sepertiga layar. Skeleton yang berbeda bentuk membuat halaman
          // melompat saat datanya tiba.
          SizedBox(
            height: 138,
            child: Row(
              children: [
                Expanded(child: block(138)),
                const SizedBox(width: 10),
                Expanded(child: block(138)),
                const SizedBox(width: 10),
                Expanded(child: block(138)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          block(20, w: 140),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: block(110)),
              const SizedBox(width: 12),
              Expanded(child: block(110)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: block(110)),
              const SizedBox(width: 12),
              Expanded(child: block(110)),
            ],
          ),
        ],
      ),
    );
  }
}
