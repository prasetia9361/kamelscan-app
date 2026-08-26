import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/daily_stats.dart';
import '../../../core/models/enums.dart';
import '../../../core/repositories/dashboard_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../navigation/route_names.dart';
import 'web_dashboard_view_model.dart';

/// Dasbor web — empat kartu ringkasan dan grafik harian (Bab 10.4).
///
/// Empat kondisi wajib Bab 3.4 semuanya ada: kerangka saat memuat, [AppErrorView]
/// saat gagal, [AppEmptyState] saat rentangnya kosong, dan isinya.
///
/// 🔴 Kondisi "kosong" sengaja **tetap menampilkan kartu dan pemilih rentang**,
/// dan hanya mengganti grafiknya. Alasannya: yang paling sering menyebabkan
/// dasbor kosong bukan "belum pernah merekam", melainkan rentang 7 hari yang
/// kebetulan sepi. Layar kosong yang menyembunyikan tombol 30/90 hari
/// menghilangkan satu-satunya jalan keluar yang dibutuhkan orang itu.
class WebDashboardPage extends ConsumerWidget {
  const WebDashboardPage({super.key});

  /// Titik henti jumlah kolom kartu. Berdiri sendiri, tidak memakai
  /// `WebShell.cardBreakpoint`: yang diukur di sini lebar **isi halaman**
  /// (sudah dipotong sidebar), bukan lebar jendela.
  static const double fourColumnWidth = 900;
  static const double twoColumnWidth = 520;

  /// Batas bawah dan atas tinggi grafik.
  ///
  /// Bawah menjaga grafik tetap terbaca di jendela pendek; atas menjaganya
  /// tetap proporsional di layar tinggi — grafik setinggi 900 px membuat
  /// naik-turun satu video terlihat seperti perubahan besar.
  static const double minChartHeight = 260;
  static const double maxChartHeight = 640;

  /// Tinggi yang dipakai bagian halaman selain grafiknya sendiri: padding 48,
  /// kepala halaman 60, dua jarak 20, kartu 132, dan bingkai kotak grafik 84.
  static const double chartChromeHeight = 364;

  /// 🔴 Tinggi grafik dihitung dari tinggi jendela, bukan angka mati.
  ///
  /// Angka mati 280 px membuat dasbor berhenti di separuh layar dan
  /// menyisakan ruang kosong sebesar itu lagi di bawahnya — terlihat pada
  /// peramban Product Owner 26 Agustus 2026. Dihitung begini, grafiknya
  /// memanjang mengisi sisa jendela dan pola hariannya jauh lebih terbaca.
  static double chartHeightFor(double viewportHeight) =>
      (viewportHeight - chartChromeHeight)
          .clamp(minChartHeight, maxChartHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(webDashboardViewModelProvider);

    // `LayoutBuilder` berdiri DI LUAR gulir. Di dalamnya tinggi yang tersedia
    // tak terhingga, dan perhitungan apa pun yang memakainya akan selalu
    // menghasilkan batas atas.
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
// Kepala halaman — judul, rentang tanggal, pemilih 7/30/90
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
    final data = stats;

    // 🔴 `Wrap`, bukan `Row`. Isi halaman menyempit dua kali: saat jendela
    // dikecilkan, dan lagi saat sidebar muncul. `Row` di sini akan meluber
    // dengan garis kuning-hitam — bentuk cacat yang sudah dua kali terjadi di
    // proyek ini (M.12 dan M.17).
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
            Text(t.navDashboard, style: theme.textTheme.headlineMedium),
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
        SegmentedButton<int>(
          segments: [
            for (final hari in DashboardRepository.allowedRanges)
              ButtonSegment<int>(
                value: hari,
                label: Text(t.dashboardRangeDays(hari)),
              ),
          ],
          selected: {terpilih},
          showSelectedIcon: false,
          onSelectionChanged: (pilihan) =>
              ref.read(dashboardRangeProvider.notifier).select(pilihan.first),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Isi
// ---------------------------------------------------------------------------

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.stats, required this.chartHeight});

  final DailyStats stats;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryCards(stats: stats),
        const SizedBox(height: 20),
        _ChartCard(stats: stats, chartHeight: chartHeight),
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
    final scheme = Theme.of(context).colorScheme;

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
            change: stats.packingChange,
            color: colors.packing,
            icon: Icons.inventory_2_outlined,
            onTap: () => context
                .go(Routes.historyOf(typeWire: VideoType.packing.wire)),
          ),
          _SummaryCard(
            label: t.homeCardReturn,
            value: Formatters.number(stats.total.returnCount),
            change: stats.returnChange,
            color: colors.returnColor,
            icon: Icons.assignment_return_outlined,
            onTap: () => context
                .go(Routes.historyOf(typeWire: VideoType.returned.wire)),
          ),
          _SummaryCard(
            label: t.dashboardCardTotal,
            value: Formatters.number(stats.totalVideos),
            change: stats.totalChange,
            color: scheme.primary,
            icon: Icons.video_library_outlined,
            onTap: () => context.go(Routes.history),
          ),
          _SummaryCard(
            label: t.dashboardCardAverage,
            value: Formatters.decimal1(stats.averagePerDay),
            // Sengaja tanpa pembanding: rata-rata sudah merupakan
            // perbandingan, dan "naik 12%" di atas "rata-rata" menyuruh
            // pembaca membandingkan dua hal yang berbeda tingkatannya.
            change: null,
            color: colors.success,
            icon: Icons.timeline_outlined,
            onTap: null,
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
/// Bentuknya sengaja sama untuk keempatnya, termasuk kartu rata-rata yang
/// tidak punya pembanding — alasan yang sama seperti `_StatCard` di Beranda:
/// dua bentuk berbeda yang berdiri bersebelahan membuat mata membandingkan
/// kotaknya, bukan angkanya.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.change,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;

  /// Pecahan perubahan terhadap periode sebelumnya; null bila tidak ada
  /// pembanding atau kartunya memang tidak membandingkan.
  final double? change;
  final Color color;
  final IconData icon;
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
                child: Text(
                  value,
                  style: AppTextStyles.statNumber
                      .copyWith(color: color, fontSize: 32, height: 38 / 32),
                ),
              ),
              const SizedBox(height: 6),
              _ChangeLabel(change: change),
            ],
          ),
        ),
      ),
    );
  }
}

/// *▲ 12% vs periode sebelumnya* — atau *belum ada pembanding*.
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
      return Text(
        t.dashboardNoComparison,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
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
            style: theme.textTheme.bodySmall?.copyWith(
              color: naik ? colors.success : colors.danger,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Grafik
// ---------------------------------------------------------------------------

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.stats, required this.chartHeight});

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
                Text(t.dashboardChartTitle,
                    style: theme.textTheme.titleMedium),
                Wrap(
                  spacing: 16,
                  children: [
                    _LegendItem(
                      color: colors.packing,
                      icon: Icons.inventory_2_outlined,
                      label: t.homeCardPacking,
                      dashed: false,
                    ),
                    _LegendItem(
                      color: colors.returnColor,
                      icon: Icons.assignment_return_outlined,
                      label: t.homeCardReturn,
                      dashed: true,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: chartHeight,
              child: stats.isEmpty
                  ? AppEmptyState(
                      title: t.dashboardEmptyTitle,
                      message: t.dashboardEmptyMessage,
                      icon: Icons.insights_outlined,
                    )
                  : _DailyChart(stats: stats),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keterangan satu garis: ikon, warna, **dan** pola garisnya.
class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.icon,
    required this.label,
    required this.dashed,
  });

  final Color color;
  final IconData icon;
  final String label;

  /// Garis return digambar putus-putus. Inilah pembeda yang tetap terbaca
  /// oleh pengguna buta warna saat kedua garis bertumpuk.
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 3,
          child: CustomPaint(painter: _LinePainter(color: color, dashed: dashed)),
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

class _LinePainter extends CustomPainter {
  const _LinePainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final cat = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;

    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), cat);
      return;
    }
    // Panjang garis dan celah disamakan dengan `dashArray` grafiknya supaya
    // keterangan dan garisnya benar-benar terlihat sama.
    const panjang = 5.0;
    const celah = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + panjang).clamp(0, size.width), y),
        cat,
      );
      x += panjang + celah;
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.color != color || old.dashed != dashed;
}

/// Perhitungan sumbu grafik, dipisah sebagai fungsi murni.
///
/// 🔴 Dipisah dengan alasan yang sama seperti `WebShell.menuFor`: keduanya
/// menghasilkan **grafik yang salah tanpa satu pun galat**. Sumbu yang terlalu
/// tinggi memipihkan seluruh garis; label yang terlalu rapat menumpuk jadi
/// gumpalan hitam. Dua-duanya hanya ketahuan dengan mata, dan hanya pada
/// rentang tertentu — 90 hari sudah rusak sementara 7 hari masih tampak baik.
class DailyChartAxis {
  const DailyChartAxis._();

  /// Jumlah label yang muat di sumbu tanggal tanpa saling menimpa.
  ///
  /// Tujuh dipilih supaya rentang 7 hari memberi label pada **setiap** hari —
  /// rentang terpendek adalah yang paling sering dipakai memeriksa hari
  /// tertentu, dan di situlah tanggal paling perlu terbaca satu per satu.
  static const int labelCount = 7;

  /// Batas atas sumbu tegak, dibulatkan ke atas ke kelipatan empat.
  ///
  /// Kelipatan empat agar keempat garis bantunya jatuh pada bilangan bulat.
  /// Sumbu berlabel `2,5 video` membuat pembaca berhenti dan bertanya-tanya
  /// apa artinya setengah video.
  static double maxYFor(int peak) {
    // Rentang tanpa rekaman tetap diberi sumbu 0..4. Tanpa ini `maxY` menjadi
    // nol, dan fl_chart menggambar bidang bertinggi nol — grafik yang hilang
    // sama sekali, bukan grafik yang datar.
    if (peak <= 0) return 4;
    return ((peak / 4).ceil() * 4).toDouble();
  }

  /// Setiap label ke berapa yang digambar pada sumbu tanggal.
  static int labelStepFor(int pointCount) {
    if (pointCount <= labelCount) return 1;
    return (pointCount / labelCount).ceil();
  }
}

class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.stats});

  final DailyStats stats;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;
    final titik = stats.series;

    final maxY = DailyChartAxis.maxYFor(stats.peak);
    final langkah = maxY / 4;
    final labelStep = DailyChartAxis.labelStepFor(titik.length);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (titik.length - 1).toDouble(),
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
              interval: labelStep.toDouble(),
              getTitlesWidget: (nilai, meta) {
                final i = nilai.round();
                // Penjagaan terhadap pembulatan pecahan: `interval` sudah
                // membatasi pemanggilannya, tetapi nilai di luar deret akan
                // melempar `RangeError` yang muncul sebagai grafik merah.
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
        lineBarsData: [
          _garis(
            [for (var i = 0; i < titik.length; i++) FlSpot(i.toDouble(), titik[i].packing.toDouble())],
            colors.packing,
            null,
          ),
          _garis(
            [for (var i = 0; i < titik.length; i++) FlSpot(i.toDouble(), titik[i].returnCount.toDouble())],
            colors.returnColor,
            const [5, 4],
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItems: (sentuhan) => [
              for (var k = 0; k < sentuhan.length; k++)
                _tooltip(
                  spot: sentuhan[k],
                  // Tanggal ditulis sekali saja, pada baris pertama.
                  // Mengulanginya di baris kedua membuat kotak keterangan
                  // dua kali lebih lebar tanpa menambah satu pun keterangan.
                  withDate: k == 0,
                  titik: titik,
                  packingLabel: t.homeCardPacking,
                  returnLabel: t.homeCardReturn,
                  color: scheme.onInverseSurface,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static LineChartBarData _garis(
    List<FlSpot> spots,
    Color color,
    List<int>? dashArray,
  ) =>
      LineChartBarData(
        spots: spots,
        color: color,
        barWidth: 2.5,
        isCurved: false,
        isStrokeCapRound: true,
        dashArray: dashArray,
        // Titik bulat disembunyikan: pada rentang 90 hari, 90 bulatan
        // menutupi garisnya sendiri.
        dotData: const FlDotData(show: false),
      );

  static LineTooltipItem _tooltip({
    required LineBarSpot spot,
    required bool withDate,
    required List<DailyPoint> titik,
    required String packingLabel,
    required String returnLabel,
    required Color color,
  }) {
    final i = spot.x.round();
    final tanggal = (withDate && i >= 0 && i < titik.length)
        ? '${Formatters.dayMonth(titik[i].date)}\n'
        : '';
    final nama = spot.barIndex == 0 ? packingLabel : returnLabel;
    return LineTooltipItem(
      '$tanggal$nama: ${Formatters.number(spot.y.round())}',
      TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
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

  /// Sama persis dengan tinggi grafik yang akan menggantikannya, supaya
  /// halaman tidak melompat saat datanya tiba.
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
          height: chartHeight + 84,
          child: AppListSkeleton(itemCount: 1, itemHeight: chartHeight + 68),
        ),
      ],
    );
  }
}
