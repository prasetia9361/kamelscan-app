import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/history_item.dart';
import '../../../core/repositories/video_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../navigation/route_names.dart';
import '../../../navigation/shells/web_shell.dart';
import '../../history/detail/video_detail_page.dart';
import '../../history/widgets/marketplace_badge.dart';
import '../../history/widgets/video_status_chip.dart';
import 'web_history_view_model.dart';

/// Riwayat versi web: tabel terurut, saringan, halaman bernomor, dan panel
/// samping berisi pemutar (Bab 10.5).
///
/// 🔴 Di bawah [WebShell.cardBreakpoint] tabelnya berubah menjadi kartu, dan
/// menekan kartu **berpindah halaman** alih-alih membuka panel samping. Panel
/// selebar 420 px di layar 700 px hanya menyisakan 280 px untuk tabelnya —
/// dua-duanya jadi tidak terbaca. Halaman detail yang sudah ada justru bentuk
/// yang benar di lebar itu, dan ia sudah terbukti dipakai di HP.
class WebHistoryPage extends ConsumerStatefulWidget {
  const WebHistoryPage({
    super.key,
    this.initialQuery,
    this.typeWire = 'semua',
  });

  /// Nomor resi yang dibawa dari kolom cari di bilah atas (Bab 10.3).
  final String? initialQuery;

  /// `packing`, `return`, atau apa pun yang berarti "semua".
  final String typeWire;

  /// Lebar panel samping. Cukup untuk pemutar 16:9 beserta keterangannya
  /// tanpa memaksa tabelnya menyempit sampai kolomnya berguguran.
  static const double panelWidth = 420;

  @override
  ConsumerState<WebHistoryPage> createState() => _WebHistoryPageState();
}

class _WebHistoryPageState extends ConsumerState<WebHistoryPage> {
  final TextEditingController _cari = TextEditingController();

  WebHistoryViewModel get _vm =>
      ref.read(webHistoryViewModelProvider(widget.typeWire).notifier);

  @override
  void initState() {
    super.initState();
    _seed();
  }

  @override
  void didUpdateWidget(WebHistoryPage old) {
    super.didUpdateWidget(old);
    // Alamat berubah tanpa halaman dibongkar — pencarian baru dari bilah atas
    // saat halaman ini sudah terbuka.
    if (old.initialQuery != widget.initialQuery) _seed();
  }

  void _seed() {
    final q = widget.initialQuery?.trim() ?? '';
    if (q.isEmpty || q == _cari.text) return;
    _cari.text = q;
    // Setelah bingkai pertama: ViewModel-nya belum tentu sudah punya keadaan
    // saat `initState` berjalan, dan `search` yang dipanggil terlalu awal
    // dibuang diam-diam.
    WidgetsBinding.instance.addPostFrameCallback((_) => _vm.search(q));
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(webHistoryViewModelProvider(widget.typeWire));

    return LayoutBuilder(
      builder: (context, batas) {
        final lebar = batas.maxWidth >= WebShell.cardBreakpoint;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilterBar(
              controller: _cari,
              filter: async.value?.filter,
              onSearch: _vm.search,
              onType: _vm.selectType,
              onStatus: _vm.selectStatus,
              onClear: () {
                _cari.clear();
                _vm.clearFilters();
              },
            ),
            Expanded(
              child: async.when(
                loading: () => const AppListSkeleton(itemCount: 8, itemHeight: 52),
                error: (error, _) => AppErrorView(
                  failure: error,
                  onRetry: _vm.refresh,
                ),
                data: (data) => _Isi(
                  data: data,
                  wide: lebar,
                  onSort: _vm.sortBy,
                  onSelect: (id) => lebar
                      ? _vm.select(id)
                      : context.go(Routes.videoDetailOf(id)),
                  onClosePanel: () => _vm.select(null),
                  onPrev: _vm.previousPage,
                  onNext: _vm.nextPage,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Saringan
// ---------------------------------------------------------------------------

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.controller,
    required this.filter,
    required this.onSearch,
    required this.onType,
    required this.onStatus,
    required this.onClear,
  });

  final TextEditingController controller;
  final VideoFilter? filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<VideoType?> onType;
  final ValueChanged<VideoStatus?> onStatus;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final f = filter;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: controller,
              onChanged: onSearch,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: t.historySearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
              ),
            ),
          ),
          _Pilihan<VideoType?>(
            label: t.tableColType,
            value: f?.type,
            options: [
              (null, t.historyFilterAll),
              (VideoType.packing, t.videoTypePacking),
              (VideoType.returned, t.videoTypeReturn),
            ],
            onChanged: onType,
          ),
          _Pilihan<VideoStatus?>(
            label: t.tableColStatus,
            value: f?.status,
            options: [
              (null, t.historyFilterAll),
              (VideoStatus.uploaded, t.videoStatusUploaded),
              (VideoStatus.pendingUpload, t.videoStatusPendingUpload),
              (VideoStatus.failed, t.videoStatusFailed),
              (VideoStatus.expired, t.videoStatusExpired),
            ],
            onChanged: onStatus,
          ),
          if (f != null && !f.isEmpty)
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: Text(t.tableClearFilters),
            ),
        ],
      ),
    );
  }
}

/// Satu menu turun saringan.
///
/// 🔴 Dibungkus [SizedBox] berlebar tetap dengan sengaja. `DropdownButton`
/// melebar mengikuti pilihan terpanjangnya, sehingga bilah saringan bergeser
/// setiap kali pilihannya berganti — bentuk gelisah yang membuat tombol
/// berpindah tepat saat hendak ditekan.
class _Pilihan<T> extends StatelessWidget {
  const _Pilihan({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isDense: true,
        // 🔴 `isExpanded` wajib, dan ketiadaannya sudah tertangkap tes sekali.
        //
        // Tanpa ini, `DropdownButton` mengukur pilihan yang sedang terpilih
        // pada lebar aslinya lalu meluber ke kanan — "Menunggu unggah" saja
        // sudah melebihi 130 px yang tersisa setelah label dan panahnya.
        // `isExpanded` membuat teksnya dibatasi kotaknya, sehingga ia
        // dipotong dengan elipsis alih-alih menembus tepi.
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          for (final (nilai, teks) in options)
            DropdownMenuItem<T>(
              value: nilai,
              child: Text(teks, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) => onChanged(v as T),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Isi: tabel / kartu + panel samping + halaman bernomor
// ---------------------------------------------------------------------------

class _Isi extends StatelessWidget {
  const _Isi({
    required this.data,
    required this.wide,
    required this.onSort,
    required this.onSelect,
    required this.onClosePanel,
    required this.onPrev,
    required this.onNext,
  });

  final WebHistoryData data;
  final bool wide;
  final ValueChanged<HistorySort> onSort;
  final ValueChanged<String> onSelect;
  final VoidCallback onClosePanel;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final terpilih = data.selectedId;

    if (data.isEmpty) {
      return AppEmptyState(
        title: data.filter.isEmpty
            ? t.emptyHistoryTitle
            : t.historyNoMatchTitle,
        message: data.filter.isEmpty
            ? t.emptyHistoryMessage
            : t.historyNoMatchBody,
        icon: Icons.video_library_outlined,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: wide
                    ? _Tabel(data: data, onSort: onSort, onSelect: onSelect)
                    : _Kartu(data: data, onSelect: onSelect),
              ),
              _Halaman(data: data, onPrev: onPrev, onNext: onNext),
            ],
          ),
        ),
        if (wide && terpilih != null)
          SizedBox(
            width: WebHistoryPage.panelWidth,
            child: _PanelSamping(
              videoId: terpilih,
              onClose: onClosePanel,
            ),
          ),
      ],
    );
  }
}

/// Kolom tabel beserta lebar nisbinya.
///
/// 🔴 Kolom Toko dan Packer sengaja **tidak dapat diurutkan**, dan itu bukan
/// kelalaian — lihat catatan pada [HistorySort]. Judulnya karena itu tidak
/// dibuat dapat ditekan: judul yang dapat ditekan tetapi tidak melakukan apa
/// pun lebih membingungkan daripada judul biasa.
enum _Kolom {
  date(flex: 3, sort: HistorySort.date),
  resi(flex: 3, sort: HistorySort.resi),
  shop(flex: 3, minWidth: 900),
  packer(flex: 2, minWidth: 1180),
  type(flex: 2, sort: HistorySort.type),
  status(flex: 2, sort: HistorySort.status),
  duration(flex: 2, sort: HistorySort.duration, minWidth: 1180);

  const _Kolom({required this.flex, this.sort, this.minWidth = 0});

  final int flex;
  final HistorySort? sort;

  /// Lebar isi tabel minimal sebelum kolom ini ikut ditampilkan.
  ///
  /// Kolom dibuang, bukan dipersempit. Tujuh kolom yang dipaksa muat pada
  /// 800 px menyisakan ± 100 px per kolom, dan nomor resi — satu-satunya isi
  /// yang tidak boleh terpotong — akan berakhir sebagai `JX12…`.
  final double minWidth;

  String label(AppL10n t) => switch (this) {
        _Kolom.date => t.tableColDate,
        _Kolom.resi => t.tableColResi,
        _Kolom.shop => t.tableColShop,
        _Kolom.packer => t.tableColPacker,
        _Kolom.type => t.tableColType,
        _Kolom.status => t.tableColStatus,
        _Kolom.duration => t.tableColDuration,
      };

  static List<_Kolom> visibleFor(double width) =>
      [for (final k in _Kolom.values) if (width >= k.minWidth) k];
}

class _Tabel extends StatelessWidget {
  const _Tabel({
    required this.data,
    required this.onSort,
    required this.onSelect,
  });

  final WebHistoryData data;
  final ValueChanged<HistorySort> onSort;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, batas) {
        final kolom = _Kolom.visibleFor(batas.maxWidth);

        return Column(
          children: [
            _BarisJudul(kolom: kolom, data: data, onSort: onSort),
            Expanded(
              child: ListView.builder(
                itemCount: data.items.length,
                itemBuilder: (context, i) {
                  final item = data.items[i];
                  return _BarisData(
                    kolom: kolom,
                    item: item,
                    selected: item.video.id == data.selectedId,
                    onTap: () => onSelect(item.video.id),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BarisJudul extends StatelessWidget {
  const _BarisJudul({
    required this.kolom,
    required this.data,
    required this.onSort,
  });

  final List<_Kolom> kolom;
  final WebHistoryData data;
  final ValueChanged<HistorySort> onSort;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      height: 44,
      child: Row(
        children: [
          for (final k in kolom)
            Expanded(
              flex: k.flex,
              child: _JudulKolom(
                label: k.label(t),
                sort: k.sort,
                active: k.sort != null && k.sort == data.sort,
                ascending: data.ascending,
                onSort: onSort,
              ),
            ),
        ],
      ),
    );
  }
}

class _JudulKolom extends StatelessWidget {
  const _JudulKolom({
    required this.label,
    required this.sort,
    required this.active,
    required this.ascending,
    required this.onSort,
  });

  final String label;
  final HistorySort? sort;
  final bool active;
  final bool ascending;
  final ValueChanged<HistorySort> onSort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kolom = sort;

    final isi = Row(
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: active ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
        if (active) ...[
          const SizedBox(width: 2),
          Icon(
            ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 14,
            color: scheme.primary,
          ),
        ],
      ],
    );

    if (kolom == null) return isi;

    return InkWell(
      onTap: () => onSort(kolom),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: isi,
      ),
    );
  }
}

class _BarisData extends StatelessWidget {
  const _BarisData({
    required this.kolom,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final List<_Kolom> kolom;
  final HistoryItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;
    final video = item.video;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : null,
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            for (final k in kolom)
              Expanded(
                flex: k.flex,
                child: switch (k) {
                  _Kolom.date => Text(
                      Formatters.shortDateTime(video.scanDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  // 🔴 Monospace, bukan pilihan gaya. Pada huruf biasa `0`/`O`
                  // dan `1`/`l`/`I` nyaris identik, dan packer yang
                  // membacakan resi lewat telepon akan salah
                  // (`palet_warna_dan_tipografi.md` §3.1).
                  _Kolom.resi => Text(
                      video.resiCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.resiInline
                          .copyWith(color: scheme.onSurface),
                    ),
                  _Kolom.shop => Row(
                      children: [
                        MarketplaceBadge(marketName: item.marketName, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.shopName ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  _Kolom.packer => Text(
                      item.recorderName ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  _Kolom.type => Align(
                      alignment: Alignment.centerLeft,
                      child: _TipeChip(type: video.type, colors: colors),
                    ),
                  _Kolom.status => Align(
                      alignment: Alignment.centerLeft,
                      child: VideoStatusChip(status: video.status),
                    ),
                  _Kolom.duration => Text(
                      Formatters.durationFromSeconds(video.durationSeconds),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Lencana Packing / Return.
///
/// Memakai ikon **dan** warna, bukan warna saja — packing dan return tidak
/// boleh hanya dibedakan lewat warna (`palet_warna_dan_tipografi.md` §7).
class _TipeChip extends StatelessWidget {
  const _TipeChip({required this.type, required this.colors});

  final VideoType type;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final packing = type == VideoType.packing;
    final warna = packing ? colors.packing : colors.returnColor;
    final latar = packing ? colors.packingContainer : colors.returnContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            packing
                ? Icons.inventory_2_outlined
                : Icons.assignment_return_outlined,
            size: 13,
            color: warna,
          ),
          const SizedBox(width: 4),
          Text(
            packing ? t.videoTypePacking : t.videoTypeReturn,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: warna),
          ),
        ],
      ),
    );
  }
}

/// Bentuk kartu untuk layar sempit — tabel yang sama, dilipat.
class _Kartu extends StatelessWidget {
  const _Kartu({required this.data, required this.onSelect});

  final WebHistoryData data;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: data.items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final item = data.items[i];
        final video = item.video;

        return Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: () => onSelect(video.id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  MarketplaceBadge(marketName: item.marketName, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.resiCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.resiInline
                              .copyWith(color: scheme.onSurface),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.shopLabel} · '
                          '${Formatters.shortDateTime(video.scanDate)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  VideoStatusChip(status: video.status),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Panel samping: halaman detail yang sudah ada, dipasang tanpa bilah judul.
///
/// 🔴 Sengaja memakai [VideoDetailPage] yang sama persis dengan HP, bukan
/// susunan baru. Halaman itu sudah menangani pemutar, unduh, tautan publik,
/// dan penghapusan beserta seluruh keadaan gagalnya — menyalinnya ke sini
/// berarti dua tempat yang harus diperbaiki setiap kali salah satunya keliru,
/// dan yang kedua selalu ketinggalan.
class _PanelSamping extends StatelessWidget {
  const _PanelSamping({required this.videoId, required this.onClose});

  final String videoId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(left: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.videoDetailTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  tooltip: t.commonClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: VideoDetailPage(
              // 🔴 `key` wajib memakai id videonya. Tanpa itu, memilih baris
              // lain memakai ulang State yang sama dan panelnya tetap
              // menampilkan video sebelumnya — pemutarnya pun ikut bertahan.
              key: ValueKey(videoId),
              videoId: videoId,
              embedded: true,
              onClose: onClose,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Halaman bernomor
// ---------------------------------------------------------------------------

class _Halaman extends StatelessWidget {
  const _Halaman({
    required this.data,
    required this.onPrev,
    required this.onNext,
  });

  final WebHistoryData data;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              // Angka barisnya ikut ditulis, bukan hanya nomor halaman.
              // "1–25 dari 431" menjawab pertanyaan yang benar-benar diajukan
              // orang saat menelusuri bukti: berapa banyak lagi yang tersisa.
              t.tableRowRange(
                Formatters.number(data.firstRow),
                Formatters.number(data.lastRow),
                Formatters.number(data.total),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          IconButton(
            onPressed: data.hasPrevious ? onPrev : null,
            tooltip: t.commonBack,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            t.tablePagePosition(
              Formatters.number(data.page + 1),
              Formatters.number(data.pageCount),
            ),
            style: theme.textTheme.bodyMedium,
          ),
          IconButton(
            onPressed: data.hasNext ? onNext : null,
            tooltip: t.commonNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
