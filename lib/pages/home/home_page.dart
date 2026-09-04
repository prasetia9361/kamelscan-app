import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/models/enums.dart';
import '../../core/models/home_stats.dart';
import '../../core/models/queue_summary.dart';
import '../../core/providers/pipeline_providers.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/upload_queue_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles_display.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_state_views.dart';
import '../../core/widgets/failure_messages.dart';
import '../../core/widgets/k_section_header.dart';
import '../../core/widgets/quota_widgets.dart';
import '../../core/workers/upload_queue_runner.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../navigation/route_names.dart';
import '../../navigation/shells/mobile_app_bar.dart';
import 'home_view_model.dart';
import 'widgets/monitoring_band.dart';
import 'widgets/record_action_row.dart';

/// Beranda — pantauan + menu utama (Bab 9.2).
///
/// Halaman ini adalah satu-satunya tempat Owner dapat melihat saldo token dan
/// jumlah video tanpa membuka database, jadi ia dikerjakan lebih dulu di antara
/// seluruh Bab 9.
///
/// Tampilannya direvisi 31 Agustus 2026 (`PANDUAN_TAMPILAN.md` Langkah 3–5):
/// tiga kartu pantauan bergaris tepi menjadi dua petak ber-tint + satu petak
/// token, dan kisi menu 2×2 menjadi dua kartu perekaman berdampingan dengan
/// Pembayaran & Tutorial turun jadi baris tipis. Tidak ada fitur, rute, atau
/// ViewModel yang berubah.
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

/// Jarak bawah daftar saat tombol Rekam mengambang terlihat.
///
/// Tombolnya menumpang di atas isi halaman dan akan menutupi baris terakhir.
/// Alasan yang sama sudah tercatat di `AccountPage` dan `HistoryPage`.
const double kHomePadWithFab = 88;

/// Jarak bawah saat tombol itu disembunyikan (Bab 9.7).
const double kHomePadNoFab = 24;

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.stats});

  final HomeStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;
    final session = ref.watch(sessionProvider).value;
    final isTrial = session?.isTrial ?? false;
    final quota = stats.quota(isTrial: isTrial);
    final isOwner = session?.isOwner ?? false;
    final canRecord = session?.canRecord ?? false;
    final showFab = ref.watch(showRecordFabProvider);

    // Bab 7.5 — uji coba dibatasi JUMLAH VIDEO, bukan waktu, jadi saat uji coba
    // tidak ada tanggal perpanjangan yang jujur untuk ditampilkan.
    final periodEnd = session?.subscription.periodEnd;
    final percent = '${(quota.ratio * 100).round()}';
    final tokenMeta = quota.quota <= 0
        ? null
        : (periodEnd == null
            ? t.homeTokenMeta(percent)
            : t.homeTokenMetaWithDate(percent, Formatters.dayMonth(periodEnd)));

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        showFab ? kHomePadWithFab : kHomePadNoFab,
      ),
      children: [
        // Sapaan pindah ke sini dari bilah atas (revisi tampilan). Di bilah
        // atas ia terulang di setiap tab dan mendorong isi yang dicari turun
        // hampir seperlima layar; di sini ia hanya muncul sekali, di tempat
        // yang memang tentang orangnya.
        if (session != null) ...[
          Text(
            greetingText(context),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            session.user.fullName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          RoleBadge(
            role: session.user.role,
            businessName: session.tenant.businessName,
          ),
          const SizedBox(height: 16),
        ],

        // Bab 7.3 & 7.6 — keempat spanduk ini memang rumahnya di Beranda.
        // Semuanya menyembunyikan dirinya sendiri saat belum perlu, jadi tidak
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
        // petak. Ia menerangkan ketiga angka sekaligus.
        //
        // 🔴 Tetap wajib ada: tanpa ini angkanya benar tetapi pembacanya
        // menduga "bulan ini" — dan dugaan itu salah, karena periode dihitung
        // sejak dompet token dimulai (keputusan Product Owner 18 Agustus 2026).
        KSectionHeader(
          t.homeMonitoringTitle,
          trailing: Text(
            t.homePeriodSince(Formatters.date(stats.periodStart)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppDisplayStyles.metaMono
                .copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 10),

        // Ketiga angka tetap terlihat sekaligus tanpa gulir mendatar — syarat
        // Bab 9.2 dan keputusan Product Owner 18 Agustus 2026.
        // 🔴 Petak Pantauan memakai warna yang SAMA PERSIS dengan kartu Rekam
        // sejenisnya di bawah — keputusan Product Owner 3 September 2026,
        // sesudah melihat Beranda di mode terang dan gelap berdampingan.
        //
        // Sebelumnya petak Pantauan memakai pasangan *container* (pucat)
        // sedangkan kartu Rekam Packing memakai `primary` (penuh). Akibatnya
        // satu halaman memakai dua biru berbeda untuk satu hal yang sama, dan
        // hubungan "petak ini dan kartu itu bicara tentang packing yang sama"
        // hilang — padahal petaknya memang menuju riwayat jenis itu.
        //
        // ⚠️ Karena itu sumbernya sengaja disebut lewat `scheme.primary` /
        // `colors.returnContainer` yang sama dengan `record_action_row.dart`,
        // bukan disalin nilainya. Menyalin angka warna berarti keduanya akan
        // menyimpang diam-diam pada perubahan palet berikutnya.
        MonitoringBand(
          packingLabel: t.homeKickerPacking,
          packingCount: stats.packingCount,
          packingColor: scheme.onPrimary,
          packingBackground: scheme.primary,
          returnLabel: t.homeKickerReturn,
          returnCount: stats.returnCount,
          returnColor: colors.onReturnContainer,
          returnBackground: colors.returnContainer,
          tokenLabel: quota.isTrial ? t.trialQuotaLabel : t.tokenBalanceLabel,
          tokenValue: quota.balance,
          // Warna & ambangnya tetap datang dari aturan Bab 7.3 yang sudah
          // teruji, bukan ditentukan ulang di sini.
          tokenColor: colors.tokenIndicator(quota.ratio),
          tokenBackground: colors.tokenIndicatorContainer(quota.ratio),
          tokenTotal: quota.quota > 0 ? quota.quota : null,
          tokenRatio: quota.quota > 0 ? quota.ratio : null,
          tokenMeta: tokenMeta,
          onTapPacking: () => context
              .push(Routes.historyOf(typeWire: VideoType.packing.wire)),
          onTapReturn: () => context
              .push(Routes.historyOf(typeWire: VideoType.returned.wire)),
          onTapToken: isOwner ? () => context.push(Routes.payment) : null,
          numberFormatter: Formatters.number,
        ),

        if (stats.isEmpty) ...[
          const SizedBox(height: 10),
          Text(
            t.homeEmptyHint,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],

        const SizedBox(height: 18),
        KSectionHeader(t.homeMenuTitle),
        const SizedBox(height: 10),
        _RecordMenu(canRecord: canRecord, isOwner: isOwner),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bagian 2 — Menu utama
// ---------------------------------------------------------------------------

class _RecordMenu extends StatelessWidget {
  const _RecordMenu({required this.canRecord, required this.isOwner});

  final bool canRecord;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;

    // Bab 9.2 — saat saldo habis, kedua kartu perekaman tampil abu-abu dengan
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

    return Column(
      children: [
        // 🔴 `IntrinsicHeight` wajib di sini — alasan lengkapnya ada di
        // `MonitoringBand`. Singkatnya: Row ini anak `ListView`, jadi tingginya
        // tidak terbatas, dan `stretch` yang tingginya tidak terbatas meminta
        // anaknya setinggi tak hingga. Akibatnya bukan kartu yang jelek,
        // melainkan SELURUH sisa halaman berhenti tergambar.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: RecordActionCard(
                  label: t.homeMenuRecordPacking,
                  subtitle: t.homeMenuRecordPackingSub,
                  icon: Icons.inventory_2_rounded,
                  startLabel: t.homeActionStart,
                  background: scheme.primary,
                  foreground: scheme.onPrimary,
                  locked: !canRecord,
                  lockedLabel: t.tokenExhaustedMenuLabel,
                  onTap:
                      canRecord ? () => record(VideoType.packing) : whenLocked,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                // Kedua kartu berisi penuh warna jenisnya supaya terbaca
                // setara. Teks di atas ungu memakai pasangan `returnContainer`
                // / `onReturnContainer` yang sudah ada — bukan token baru.
                child: RecordActionCard(
                  label: t.homeMenuRecordReturn,
                  // 🔴 Subjudul per kartu, bukan dari jenis yang terpilih —
                  // kedua kartu berdiri bersamaan di Beranda.
                  subtitle: t.homeMenuRecordReturnSub,
                  icon: Icons.move_to_inbox_rounded,
                  startLabel: t.homeActionStart,
                  background: colors.returnContainer,
                  foreground: colors.onReturnContainer,
                  locked: !canRecord,
                  lockedLabel: t.tokenExhaustedMenuLabel,
                  onTap:
                      canRecord ? () => record(VideoType.returned) : whenLocked,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Untuk packer barisnya otomatis satu kolom penuh — Pembayaran hanya
        // untuk Owner, dan kartu setengah lebar yang berdiri sendirian
        // terlihat seperti ada yang hilang.
        Row(
          children: [
            if (isOwner) ...[
              Expanded(
                child: RecordSecondaryTile(
                  label: t.navPayment,
                  subtitle: t.homeMenuPaymentSub,
                  icon: Icons.wallet_rounded,
                  accent: colors.success,
                  onTap: () => context.push(Routes.payment),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: RecordSecondaryTile(
                label: t.navTutorial,
                subtitle: t.homeMenuTutorialSub,
                icon: Icons.play_circle_outline_rounded,
                accent: scheme.primary,
                // 🔴 [Routes.homeTutorial], bukan `Routes.tutorial`. Beranda
                // hanya dibangun di HP, dan di sana Tutorial hidup di bawah
                // `/home`. Sebelum 25 Agustus 2026 baris ini memakai
                // `/tutorial` dan mendarat di layar "halaman tidak ditemukan".
                onTap: () => context.push(Routes.homeTutorial),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Spanduk antrian
// ---------------------------------------------------------------------------

/// *"4 video dalam antrean — menunggu Wi-Fi"* beserta tombol **Unggah
/// sekarang**.
///
/// ⚠️ Angkanya diambil dari antrian **lokal**, bukan dari `pending_upload`
/// milik server. Bab 8.7 / L.5: baris `package_videos` baru dibuat saat
/// mengunggah, jadi video yang direkam di gudang tanpa sinyal belum punya baris
/// di server sama sekali — padahal justru itu yang perlu diberitahukan.
/// Spanduk antrean unggah (Bab 8.7).
///
/// 🔴 Ditulis ulang 3 September 2026 setelah dua laporan Product Owner yang
/// ternyata berakar pada hal yang sama: **layar ini mengarang sebab.**
///
/// Kalimatnya dulu ditulis mati — *"{n} video dalam antrean — menunggu
/// Wi-Fi"* — dan diucapkan tanpa peduli apa yang sebenarnya menahan. Saat
/// sebuah video gagal diberi watermark, layar tetap menyalahkan jaringan;
/// Product Owner lalu menyalakan "Unggah lewat data seluler", pengaturan yang
/// sama sekali tidak berhubungan, dan tentu saja tidak terjadi apa-apa.
///
/// Tombolnya pun tidak menjawab apa pun: `run()` dipanggil, berhenti diam-diam
/// di salah satu dari lima jalur, dan layarnya tidak berubah sedikit pun.
class _QueueBanner extends ConsumerStatefulWidget {
  const _QueueBanner();

  @override
  ConsumerState<_QueueBanner> createState() => _QueueBannerState();
}

class _QueueBannerState extends ConsumerState<_QueueBanner> {
  bool _sedang = false;

  /// 🔴 Metode State, bukan closure di dalam `build` — `context` milik `build`
  /// dianggap analyzer tidak berhubungan dengan `mounted` milik State, dan ia
  /// benar: keduanya memang dapat berbeda umur.
  Future<void> _unggahSekarang() async {
    if (_sedang) return;
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _sedang = true);
    final hasil = await ref.read(uploadQueueRunnerProvider).run();
    if (!mounted) return;
    setState(() => _sedang = false);

    // ⚠️ SELALU memberi kabar, termasuk saat tidak terjadi apa-apa. Ketukan
    // yang tidak menghasilkan apa pun adalah cara tercepat membuat orang
    // mengira aplikasinya rusak (Bab 9.10) — dan itulah yang dilaporkan.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_kabar(t, hasil))));
  }

  static String _kabar(AppL10n t, UploadRunOutcome hasil) => switch (hasil) {
        UploadRunOutcome.terunggah => t.queueRunUploaded,
        UploadRunOutcome.sedangBerjalan => t.queueRunBusy,
        UploadRunOutcome.tanpaJaringan => t.queueRunNoNetwork,
        UploadRunOutcome.menungguWifi => t.queueRunWaitingWifi,
        UploadRunOutcome.kosong => t.queueRunEmpty,
        UploadRunOutcome.tidakAdaYangSiap => t.queueRunNothingReady,
        UploadRunOutcome.semuaGagal => t.queueRunAllFailed,
        // Web tidak punya antrian lokal, jadi spanduk ini tidak pernah tampil
        // di sana — tetapi cabangnya tetap wajib ada.
        UploadRunOutcome.tidakDidukung => t.queueRunEmpty,
      };

  @override
  Widget build(BuildContext context) {
    final ringkas =
        ref.watch(queueSummaryProvider).value ?? const QueueSummary();
    if (ringkas.kosong) return const SizedBox.shrink();

    final t = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;
    final adaJaringan = ref.watch(networkOnlineProvider).value ?? true;

    // 🔴 Urutannya bukan selera: yang disebut adalah keadaan yang paling
    // menuntut perbuatan pengguna. Video yang menyerah tidak akan pernah
    // terkirim sendiri, jadi ia mengalahkan yang sekadar menunggu.
    final (String pesan, IconData ikon, Color warna) = switch (ringkas) {
      final r when r.gagal > 0 => (
          t.homeQueueFailedPermanent(r.gagal),
          Icons.error_outline,
          colors.danger,
        ),
      final r when r.siap > 0 && !adaJaringan => (
          t.homeQueueWaitingNetwork(r.siap),
          Icons.cloud_off_outlined,
          colors.warning,
        ),
      final r when r.siap > 0 => (
          t.homeQueueReady(r.siap),
          Icons.cloud_upload_outlined,
          colors.warning,
        ),
      final r when r.sedangDiproses > 0 => (
          t.homeQueueProcessing(r.sedangDiproses),
          Icons.hourglass_top_outlined,
          colors.warning,
        ),
      final r => (
          t.homeQueueRetryLater(r.tertunda),
          Icons.schedule_outlined,
          colors.warning,
        ),
    };

    return _InfoBanner(
      message: pesan,
      icon: ikon,
      color: warna,
      actionLabel: t.homeQueueUploadNow,
      // ⚠️ Tombolnya TIDAK dimatikan saat tidak ada yang siap. Bab 9.10
      // melarang tombol abu-abu tanpa penjelasan; menekannya sekarang
      // menghasilkan kalimat yang menyebutkan apa yang sedang terjadi, dan itu
      // jauh lebih menolong daripada tombol yang diam.
      onAction: _sedang ? null : _unggahSekarang,
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

  /// Null berarti sedang berjalan — bukan "tidak ada gunanya ditekan".
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
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
// Kondisi memuat
// ---------------------------------------------------------------------------

class _HomeSkeleton extends ConsumerWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final showFab = ref.watch(showRecordFabProvider);

    Widget block(double h, {double? w, double radius = 18}) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: colors.shimmerBase,
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    return Shimmer.fromColors(
      baseColor: colors.shimmerBase,
      highlightColor: colors.shimmerHighlight,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          showFab ? kHomePadWithFab : kHomePadNoFab,
        ),
        children: [
          block(14, w: 120, radius: 999),
          const SizedBox(height: 10),
          // Bentuknya menyamai isi yang akan menggantikannya — dua petak
          // berdampingan lalu satu petak token penuh lebar. Skeleton yang
          // berbeda bentuk membuat halaman melompat saat datanya tiba.
          Row(
            children: [
              Expanded(child: block(90)),
              const SizedBox(width: 10),
              Expanded(child: block(90)),
            ],
          ),
          const SizedBox(height: 10),
          block(99),
          const SizedBox(height: 18),
          block(14, w: 140, radius: 999),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: block(120)),
              const SizedBox(width: 10),
              Expanded(child: block(120)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: block(56, radius: 16)),
              const SizedBox(width: 10),
              Expanded(child: block(56, radius: 16)),
            ],
          ),
        ],
      ),
    );
  }
}
