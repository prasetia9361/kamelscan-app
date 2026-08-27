import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/models/daily_stats.dart';
import '../../../core/models/enums.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/repositories/dashboard_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../navigation/route_names.dart';
import 'web_dashboard_view_model.dart';

/// Dasbor web — empat kartu ringkasan dan dua grafik (Bab 10.4).
///
/// Empat kondisi wajib Bab 3.4 semuanya ada: kerangka saat memuat,
/// [AppErrorView] saat gagal, [AppEmptyState] saat rentangnya kosong, dan
/// isinya.
///
/// 🔴 Kondisi "kosong" sengaja **tetap menampilkan kartu dan pemilih rentang**.
/// Sebab tersering dasbor kosong bukan "belum pernah merekam", melainkan
/// rentang 7 hari yang kebetulan sepi — dan layar kosong yang menyembunyikan
/// tombol 30/90 hari menutup satu-satunya jalan keluar orang itu.
class WebDashboardPage extends ConsumerWidget {
  const WebDashboardPage({super.key});

  /// Titik henti jumlah kolom kartu, angka rancangan desainer.
  ///
  /// Yang diukur lebar **isi halaman** (sudah dipotong sidebar), bukan lebar
  /// jendela — karena itu tidak memakai `WebShell.cardBreakpoint`.
  static const double fourColumnWidth = 1200;
  static const double twoColumnWidth = 768;

  static const double minChartHeight = 220;
  static const double maxChartHeight = 460;

  /// Tinggi yang dipakai bagian halaman selain kedua grafiknya sendiri.
  static const double chartChromeHeight = 620;

  /// 🔴 Tinggi grafik dihitung dari tinggi jendela, bukan angka mati.
  ///
  /// Angka mati membuat dasbor berhenti di separuh layar dan menyisakan ruang
  /// kosong sebesar itu lagi di bawahnya — terlihat pada peramban Product
  /// Owner 26 Agustus 2026.
  static double chartHeightFor(double viewportHeight) =>
      ((viewportHeight - chartChromeHeight) / 2)
          .clamp(minChartHeight, maxChartHeight);

  /// Batang terbanyak yang masih terbaca pada grafik selebar layar penuh.
  ///
  /// 🔴 Di atas ini data dikelompokkan per minggu. Rancangan desainer butir 3:
  /// 90 batang tidak muat walau di layar lebar, dan batang selebar 6 px hanya
  /// terlihat seperti kabut. Ini keputusan **tampilan** — RPC-nya tetap
  /// mengembalikan harian, dan pengelompokannya terjadi di sini supaya server
  /// tidak perlu tahu apa pun tentang lebar layar.
  static const int maxBars = 45;

  /// Mengelompokkan deret harian menjadi mingguan bila terlalu rapat.
  ///
  /// Tanggal yang dipakai adalah **awal** tiap kelompok — itulah yang ditulis
  /// di sumbu, dan menuliskan tanggal akhir membuat batang pertama seolah
  /// mewakili minggu yang belum terjadi.
  static List<DailyPoint> groupIfNeeded(List<DailyPoint> series) {
    if (series.length <= maxBars) return series;

    final hasil = <DailyPoint>[];
    for (var i = 0; i < series.length; i += 7) {
      final akhir = (i + 7 <= series.length) ? i + 7 : series.length;
      final potong = series.sublist(i, akhir);
      hasil.add(DailyPoint(
        date: potong.first.date,
        packing: potong.fold(0, (a, p) => a + p.packing),
        returnCount: potong.fold(0, (a, p) => a + p.returnCount),
      ));
    }
    return hasil;
  }

  /// Versi mingguan untuk deret token, aturan dan alasan yang sama.
  static List<TokenPoint> groupTokensIfNeeded(List<TokenPoint> series) {
    if (series.length <= maxBars) return series;

    final hasil = <TokenPoint>[];
    for (var i = 0; i < series.length; i += 7) {
      final akhir = (i + 7 <= series.length) ? i + 7 : series.length;
      final potong = series.sublist(i, akhir);
      hasil.add(TokenPoint(
        date: potong.first.date,
        used: potong.fold(0, (a, p) => a + p.used),
      ));
    }
    return hasil;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(webDashboardViewModelProvider);
    final isOwner = ref.watch(sessionProvider).value?.isOwner ?? false;

    // `LayoutBuilder` berdiri DI LUAR gulir. Di dalamnya tinggi yang tersedia
    // tak terhingga, dan perhitungan apa pun akan jatuh ke batas atas.
    return LayoutBuilder(
      builder: (context, jendela) {
        final tinggiGrafik = chartHeightFor(jendela.maxHeight);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(stats: async.value),
              const SizedBox(height: 20),
              async.when(
                loading: () => _DashboardSkeleton(chartHeight: tinggiGrafik),
                error: (error, _) => SizedBox(
                  height: tinggiGrafik,
                  child: AppErrorView(
                    failure: error,
                    onRetry: () => ref
                        .read(webDashboardViewModelProvider.notifier)
                        .refresh(),
                  ),
                ),
                data: (stats) => _DashboardBody(
                  stats: stats,
                  chartHeight: tinggiGrafik,
                  isOwner: isOwner,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Kepala halaman — judul, rentang tanggal, pemilih 7/30/90/Kustom
// ---------------------------------------------------------------------------

class _Header extends ConsumerWidget {
  const _Header({this.stats});

  /// null selama memuat. Keterangan tanggalnya ikut disembunyikan, **bukan**
  /// diisi tebakan: menuliskan rentang sebelum server menjawab berarti
  /// menampilkan tanggal yang belum tentu sama dengan yang dihitung.
  final DailyStats? stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final terpilih = ref.watch(dashboardRangeProvider);
    final kustom = ref.watch(dashboardCustomRangeProvider);
    final data = stats;

    // 🔴 `Wrap`, bukan `Row`. Isi halaman menyempit dua kali: saat jendela
    // dikecilkan, dan lagi saat sidebar muncul. `Row` di sini akan meluber —
    // bentuk cacat yang sudah dua kali terjadi di proyek ini (M.12, M.17).
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.navHome, style: theme.textTheme.headlineMedium),
            if (data != null) ...[
              const SizedBox(height: 2),
              Text(
                '${Formatters.dayMonth(data.startDate)} – '
                '${Formatters.date(data.endDate)}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
        _PemilihRentang(terpilih: terpilih, kustomAktif: kustom != null),
      ],
    );
  }
}

class _PemilihRentang extends ConsumerWidget {
  const _PemilihRentang({required this.terpilih, required this.kustomAktif});

  final int terpilih;
  final bool kustomAktif;

  /// Nilai semu untuk segmen *Kustom* — tidak pernah dikirim ke server.
  static const int kustom = -1;

  Future<void> _pilihTanggal(BuildContext context, WidgetRef ref) async {
    final kini = DateTime.now();
    final hasil = await showDateRangePicker(
      context: context,
      // Batas bawah setahun: server pun menjepit rentang kustom di 366 hari,
      // dan pemilih yang mengizinkan 2019 hanya menghasilkan penolakan diam.
      firstDate: DateTime(kini.year - 1, kini.month, kini.day),
      lastDate: DateTime(kini.year, kini.month, kini.day),
    );
    if (hasil == null) return;
    ref
        .read(dashboardCustomRangeProvider.notifier)
        .select(hasil.start, hasil.end);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;

    void pilih(int nilai) {
      if (nilai == kustom) {
        _pilihTanggal(context, ref);
        return;
      }
      ref.read(dashboardCustomRangeProvider.notifier).clear();
      ref.read(dashboardRangeProvider.notifier).select(nilai);
    }

    return SegmentedButton<int>(
      segments: [
        for (final hari in DashboardRepository.allowedRanges)
          ButtonSegment<int>(
            value: hari,
            label: Text(t.dashboardRangeDays(hari)),
          ),
        ButtonSegment<int>(
          value: kustom,
          label: Text(t.dashboardRangeCustom),
        ),
      ],
      selected: {kustomAktif ? kustom : terpilih},
      showSelectedIcon: false,
      // Menekan *Kustom* saat rentang kustom sudah aktif tetap membuka
      // pemilihnya lagi — itu satu-satunya cara mengubah tanggalnya.
      onSelectionChanged: (pilihan) => pilih(pilihan.first),
    );
  }
}

// ---------------------------------------------------------------------------
// Isi
// ---------------------------------------------------------------------------

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.stats,
    required this.chartHeight,
    required this.isOwner,
  });

  final DailyStats stats;
  final double chartHeight;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryCards(stats: stats),
        const SizedBox(height: 20),
        _KartuGrafikVideo(stats: stats, chartHeight: chartHeight),

        // 🔴 Grafik token hanya untuk Owner, dan alasannya bukan sekadar
        // Bab 2.2. `token_ledger` dapat dibaca SELURUH anggota tenant
        // (`14_rls.sql`), sedangkan `package_videos` disaring per packer.
        // Menampilkan keduanya berdampingan kepada packer berarti ia melihat
        // pemakaian token se-toko di sebelah jumlah videonya sendiri — dua
        // angka yang tidak akan pernah cocok, tanpa satu pun keterangan
        // yang menjelaskan kenapa.
        if (isOwner) ...[
          const SizedBox(height: 20),
          _KartuGrafikToken(stats: stats, chartHeight: chartHeight),
        ],
      ],
    );
  }
}

/// Empat kartu ringkasan yang membungkus ke baris berikutnya bila sempit.
class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.stats});

  final DailyStats stats;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;
    final dompet = stats.wallet;

    return LayoutBuilder(
      builder: (context, batas) {
        final kolom = switch (batas.maxWidth) {
          >= WebDashboardPage.fourColumnWidth => 4,
          >= WebDashboardPage.twoColumnWidth => 2,
          _ => 1,
        };
        const jarak = 16.0;
        // Lebar dihitung, bukan diserahkan ke `Expanded` di dalam `Wrap` —
        // `Wrap` tidak punya sisa ruang untuk dibagi, dan `Expanded` di
        // dalamnya melempar saat dirender.
        final lebar = (batas.maxWidth - jarak * (kolom - 1)) / kolom;

        final kartu = <Widget>[
          _SummaryCard(
            label: t.homeCardPacking,
            value: Formatters.number(stats.total.packing),
            color: colors.packing,
            icon: Icons.inventory_2_outlined,
            footer: _ChangeLabel(change: stats.packingChange),
            onTap: () => context
                .go(Routes.historyOf(typeWire: VideoType.packing.wire)),
          ),
          _SummaryCard(
            label: t.homeCardReturn,
            value: Formatters.number(stats.total.returnCount),
            color: colors.returnColor,
            icon: Icons.assignment_return_outlined,
            footer: _ChangeLabel(change: stats.returnChange),
            onTap: () => context
                .go(Routes.historyOf(typeWire: VideoType.returned.wire)),
          ),
          _SummaryCard(
            label: t.dashboardCardToken,
            value: dompet == null
                ? '—'
                : Formatters.number(dompet.balance),
            total: dompet == null ? null : Formatters.number(dompet.quota),
            // Ambang warnanya datang dari aturan Bab 7.3 yang sudah teruji,
            // bukan ditentukan ulang di sini.
            color: colors.tokenIndicator(dompet?.ratio ?? 1),
            icon: Icons.confirmation_number_outlined,
            progress: dompet?.ratio,
            footer: _TokenFooter(stats: stats),
            onTap: () => context.go(Routes.payment),
          ),
          _SummaryCard(
            label: t.dashboardCardPending,
            value: Formatters.number(stats.pending.count),
            color: stats.pendingIsStale ? colors.warning : colors.success,
            icon: Icons.cloud_upload_outlined,
            footer: _PendingFooter(stats: stats),
            onTap: () => context.go(Routes.history),
          ),
        ];

        return Wrap(
          spacing: jarak,
          runSpacing: jarak,
          children: [
            for (final k in kartu) SizedBox(width: lebar, child: k),
          ],
        );
      },
    );
  }
}

/// Satu kartu ringkasan.
///
/// Bentuknya sengaja sama untuk keempatnya — alasan yang sama seperti
/// `_StatCard` di Beranda: dua bentuk berbeda yang berdiri bersebelahan
/// membuat mata membandingkan kotaknya, bukan angkanya.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.footer,
    required this.onTap,
    this.total,
    this.progress,
  });

  final String label;
  final String value;

  /// Penyebut: `371` **/ 1.000**. null pada kartu tanpa kuota.
  final String? total;
  final Color color;
  final IconData icon;

  /// Baris keterangan di bawah angkanya. Berbeda-beda per kartu, karena
  /// pertanyaan yang dijawab tiap kartu memang berbeda.
  final Widget footer;
  final double? progress;
  final VoidCallback? onTap;

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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Tenant sibuk dapat menembus lima digit pada rentang 90 hari.
              // Mengecilkan angka lebih baik daripada memotongnya.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: AppTextStyles.statNumber
                          .copyWith(color: color, fontSize: 32, height: 38 / 32),
                    ),
                    if (total != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '/ ${total!}',
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
              const SizedBox(height: 6),
              footer,
            ],
          ),
        ),
      ),
    );
  }
}

/// *▲ 12% vs periode lalu* — atau *belum ada pembanding*.
///
/// 🔴 Panah dan tandanya ikut, bukan warnanya saja. Bab 9.10 dan
/// `palet_warna_dan_tipografi.md` §7: makna tidak pernah disampaikan hanya
/// lewat warna. Hijau dan merah pada angka kecil adalah kasus terburuknya.
class _ChangeLabel extends StatelessWidget {
  const _ChangeLabel({required this.change});

  final double? change;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final nilai = change;

    if (nilai == null) {
      return _Keterangan(teks: t.dashboardNoComparison);
    }

    final naik = nilai >= 0;
    final persen = (nilai.abs() * 100).round();

    return Row(
      children: [
        Icon(
          naik ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 14,
          color: naik ? colors.success : colors.danger,
        ),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            t.dashboardVsPrevious('$persen%'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: naik ? colors.success : colors.danger),
          ),
        ),
      ],
    );
  }
}

/// *"Cukup ± 17 hari lagi pada laju sekarang"*, atau peringatan kuota.
///
/// 🔴 Rancangan desainer butir 4 dan Bab 7.3: saat kuota menipis, **warnanya
/// berubah DAN kalimatnya ikut berubah**. Palet melarang makna yang hanya
/// disampaikan lewat warna, dan bilah kemajuan yang berubah oranye tanpa satu
/// kata pun adalah bentuk paling murni dari pelanggaran itu.
class _TokenFooter extends StatelessWidget {
  const _TokenFooter({required this.stats});

  final DailyStats stats;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;
    final dompet = stats.wallet;

    if (dompet == null) return _Keterangan(teks: t.dashboardTokenNoWallet);

    if (dompet.balance == 0) {
      return _Keterangan(teks: t.dashboardTokenEmpty, warna: colors.danger);
    }
    if (dompet.ratio <= AppConstants.tokenWarningRatio) {
      return _Keterangan(teks: t.dashboardTokenLow, warna: colors.warning);
    }

    final hari = stats.estimatedDaysLeft;
    return _Keterangan(
      teks: hari == null
          ? t.dashboardTokenNoEstimate
          : t.dashboardTokenDaysLeft(Formatters.number(hari)),
    );
  }
}

/// *"Tertua menunggu 2 jam · Normal — di bawah batas 6 jam"*.
class _PendingFooter extends StatelessWidget {
  const _PendingFooter({required this.stats});

  final DailyStats stats;

  /// Umur dalam kata manusia: menit, jam, atau hari.
  ///
  /// Dipisah sebagai fungsi murni supaya dapat diuji tanpa merender apa pun —
  /// pembulatan umur adalah tempat yang mudah meleset, dan "menunggu 0 jam"
  /// terbaca seperti kerusakan.
  static String umur(Duration d, AppL10n t) {
    if (d.inHours < 1) {
      return t.dashboardAgeMinutes(Formatters.number(d.inMinutes));
    }
    if (d.inHours < 48) {
      return t.dashboardAgeHours(Formatters.number(d.inHours));
    }
    return t.dashboardAgeDays(Formatters.number(d.inDays));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;

    if (stats.pending.isEmpty) {
      return _Keterangan(teks: t.dashboardPendingNone);
    }

    final tua = stats.oldestPendingAge;
    if (tua == null) return _Keterangan(teks: t.dashboardPendingNormal);

    return _Keterangan(
      teks: stats.pendingIsStale
          ? t.dashboardPendingStale
          : t.dashboardPendingOldest(umur(tua, t)),
      warna: stats.pendingIsStale ? colors.warning : null,
    );
  }
}

class _Keterangan extends StatelessWidget {
  const _Keterangan({required this.teks, this.warna});

  final String teks;
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      teks,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall
          ?.copyWith(color: warna ?? theme.colorScheme.onSurfaceVariant),
    );
  }
}

// ---------------------------------------------------------------------------
// Grafik video harian — batang bertumpuk
// ---------------------------------------------------------------------------

class _KartuGrafikVideo extends StatelessWidget {
  const _KartuGrafikVideo({required this.stats, required this.chartHeight});

  final DailyStats stats;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                // 🔴 Kedua grafik di halaman ini menghitung TANGGAL YANG
                // BERBEDA, dan tanpa dua baris keterangan ini selisihnya
                // terbaca sebagai kesalahan.
                //
                // Video dihitung menurut `scan_date` — kapan direkam.
                // Token dihitung menurut `token_ledger.created_at` — kapan
                // unggahannya berhasil. Video yang direkam malam lalu
                // terunggah besok paginya muncul pada dua tanggal berbeda di
                // kedua grafik. Product Owner menanyakannya 28 Agustus 2026
                // setelah melihat jumlah keduanya tidak sama.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.dashboardChartTitle,
                        style: theme.textTheme.titleMedium),
                    Text(
                      t.dashboardChartVideoSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 16,
                  children: [
                    _Legenda(
                      color: colors.packing,
                      icon: Icons.inventory_2_outlined,
                      label: t.homeCardPacking,
                      bergaris: false,
                    ),
                    _Legenda(
                      color: colors.returnColor,
                      icon: Icons.assignment_return_outlined,
                      label: t.homeCardReturn,
                      bergaris: true,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: chartHeight,
              child: stats.isEmpty
                  ? AppEmptyState(
                      title: t.dashboardEmptyTitle,
                      message: t.dashboardEmptyMessage,
                      icon: Icons.insights_outlined,
                    )
                  : _GrafikVideo(stats: stats),
            ),
            if (!stats.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                t.dashboardTotalSummary(
                  Formatters.number(stats.days),
                  Formatters.number(stats.totalVideos),
                ),
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                t.dashboardTotalBreakdown(
                  Formatters.number(stats.total.packing),
                  Formatters.number(stats.total.returnCount),
                ),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Perhitungan sumbu, dipisah sebagai fungsi murni.
///
/// 🔴 Keduanya menghasilkan **grafik yang salah tanpa satu pun galat**. Sumbu
/// yang terlalu tinggi memipihkan seluruh batang; label yang terlalu rapat
/// menumpuk jadi gumpalan hitam. Dua-duanya hanya ketahuan dengan mata, dan
/// hanya pada rentang tertentu — 90 hari sudah rusak sementara 7 hari masih
/// tampak baik.
class DailyChartAxis {
  const DailyChartAxis._();

  /// Jumlah label yang muat di sumbu tanggal tanpa saling menimpa.
  ///
  /// Tujuh dipilih supaya rentang 7 hari memberi label pada **setiap** hari —
  /// rentang terpendek adalah yang paling sering dipakai memeriksa hari
  /// tertentu.
  static const int labelCount = 7;

  /// Batas atas sumbu tegak, dibulatkan ke atas ke kelipatan empat, agar
  /// keempat garis bantunya jatuh pada bilangan bulat. Sumbu berlabel
  /// `2,5 video` membuat pembaca bertanya apa artinya setengah video.
  static double maxYFor(int peak) {
    // Rentang tanpa rekaman tetap diberi sumbu 0..4. Tanpa ini `maxY` menjadi
    // nol dan fl_chart menggambar bidang bertinggi nol — grafik yang hilang
    // sama sekali, bukan grafik yang datar.
    if (peak <= 0) return 4;
    return ((peak / 4).ceil() * 4).toDouble();
  }

  static int labelStepFor(int pointCount) {
    if (pointCount <= labelCount) return 1;
    return (pointCount / labelCount).ceil();
  }
}

class _GrafikVideo extends StatelessWidget {
  const _GrafikVideo({required this.stats});

  final DailyStats stats;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;

    final titik = WebDashboardPage.groupIfNeeded(stats.series);

    // 🔴 Puncaknya JUMLAH keduanya, bukan yang tertinggi di antaranya —
    // batangnya bertumpuk. Pada grafik garis dulu justru sebaliknya. Salah
    // memilih di sini membuat batang tertinggi terpotong di ujung atas.
    final puncak = titik.fold<int>(0, (a, p) => p.total > a ? p.total : a);
    final maxY = DailyChartAxis.maxYFor(puncak);
    final langkah = maxY / 4;
    final labelStep = DailyChartAxis.labelStepFor(titik.length);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: langkah,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: scheme.outlineVariant, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: langkah,
              getTitlesWidget: (nilai, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  Formatters.number(nilai.round()),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (nilai, meta) {
                final i = nilai.round();
                if (i < 0 || i >= titik.length) return const SizedBox.shrink();
                if (i % labelStep != 0) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    Formatters.dayMonth(titik[i].date),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < titik.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: titik[i].total.toDouble(),
                  width: titik.length > 30 ? 6 : 12,
                  borderRadius: BorderRadius.circular(3),
                  color: colors.packing,
                  rodStackItems: [
                    BarChartRodStackItem(
                      0,
                      titik[i].packing.toDouble(),
                      colors.packing,
                    ),
                    // 🔴 Segmen Retur diberi GARIS TEPI, bukan sekadar warna
                    // lain. Rancangan desainer butir 5 memintanya diarsir;
                    // fl_chart tidak menyediakan arsir, dan yang dituju
                    // catatan itu adalah **batas antar segmen tetap terlihat**
                    // pada layar hitam-putih dan bagi pengguna buta warna
                    // biru-ungu. Garis tepi mencapai tujuan yang sama.
                    BarChartRodStackItem(
                      titik[i].packing.toDouble(),
                      titik[i].total.toDouble(),
                      colors.returnColor,
                      borderSide: BorderSide(
                        color: scheme.surface,
                        width: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItem: (group, _, rod, _) {
              final i = group.x;
              if (i < 0 || i >= titik.length) return null;
              final p = titik[i];
              return BarTooltipItem(
                '${Formatters.dayMonth(p.date)}\n'
                '${t.homeCardPacking}: ${Formatters.number(p.packing)}\n'
                '${t.homeCardReturn}: ${Formatters.number(p.returnCount)}',
                TextStyle(
                  color: scheme.onInverseSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grafik pemakaian token
// ---------------------------------------------------------------------------

class _KartuGrafikToken extends StatelessWidget {
  const _KartuGrafikToken({required this.stats, required this.chartHeight});

  final DailyStats stats;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.dashboardChartTokenTitle,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              t.dashboardChartTokenSubtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: chartHeight,
              child: _GrafikToken(stats: stats),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrafikToken extends StatelessWidget {
  const _GrafikToken({required this.stats});

  final DailyStats stats;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final titik = WebDashboardPage.groupTokensIfNeeded(stats.tokenSeries);
    final puncak = titik.fold<int>(0, (a, p) => p.used > a ? p.used : a);
    final maxY = DailyChartAxis.maxYFor(puncak);
    final langkah = maxY / 4;
    final labelStep = DailyChartAxis.labelStepFor(titik.length);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: langkah,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: scheme.outlineVariant, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: langkah,
              getTitlesWidget: (nilai, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  Formatters.number(nilai.round()),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (nilai, meta) {
                final i = nilai.round();
                if (i < 0 || i >= titik.length) return const SizedBox.shrink();
                if (i % labelStep != 0) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    Formatters.dayMonth(titik[i].date),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < titik.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: titik[i].used.toDouble(),
                  width: titik.length > 30 ? 6 : 12,
                  borderRadius: BorderRadius.circular(3),
                  color: scheme.primary,
                ),
              ],
            ),
        ],
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItem: (group, _, rod, _) {
              final i = group.x;
              if (i < 0 || i >= titik.length) return null;
              return BarTooltipItem(
                '${Formatters.dayMonth(titik[i].date)}\n'
                '${t.tokenRemaining(titik[i].used)}',
                TextStyle(
                  color: scheme.onInverseSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Keterangan satu deret: ikon, warna, **dan** bentuknya.
class _Legenda extends StatelessWidget {
  const _Legenda({
    required this.color,
    required this.icon,
    required this.label,
    required this.bergaris,
  });

  final Color color;
  final IconData icon;
  final String label;

  /// Segmen Retur digambar bergaris tepi. Inilah pembeda yang tetap terbaca
  /// oleh pengguna buta warna saat kedua segmen bersentuhan langsung.
  final bool bergaris;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: bergaris
                ? Border.all(color: theme.colorScheme.surface, width: 1.5)
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Kerangka
// ---------------------------------------------------------------------------

/// Kerangka saat memuat — bukan spinner di tengah layar (Bab 9.10).
///
/// Bentuknya sengaja menyerupai isi yang akan menggantikannya, supaya halaman
/// tidak melompat saat datanya tiba.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton({required this.chartHeight});

  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          height: 132,
          child: AppListSkeleton(itemCount: 1, itemHeight: 116),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: chartHeight + 100,
          child: AppListSkeleton(itemCount: 1, itemHeight: chartHeight + 84),
        ),
      ],
    );
  }
}
