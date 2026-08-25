import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/enums.dart';
import '../../core/models/history_item.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_state_views.dart';
import '../../core/widgets/failure_messages.dart';
import '../../navigation/route_names.dart';
import 'history_view_model.dart';
import 'widgets/marketplace_badge.dart';
import 'widgets/video_status_chip.dart';

/// Riwayat rekaman (Bab 9.4).
///
/// Susunannya mengikuti acuan yang diberikan Product Owner 18 Agustus 2026:
/// judul, chip jenis, kolom pencarian, lalu daftar kartu.
///
/// [typeWire] datang dari kartu Beranda yang ditekan — `packing`, `return`,
/// atau kosong untuk semua.
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key, this.typeWire = '', this.initialQuery = ''});

  final String typeWire;

  /// Nomor resi yang sudah diketik di bilah atas web sebelum halaman ini
  /// dibuka (Bab 10.3). Kosong berarti dibuka lewat menu biasa.
  final String initialQuery;

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();

  HistoryViewModel get _vm =>
      ref.read(historyViewModelProvider(widget.typeWire).notifier);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _applyIncomingQuery();
  }

  /// Bab 10.3 — pencarian yang datang dari bilah atas web.
  ///
  /// Dipisahkan karena harus berjalan dua kali: saat halaman ini lahir, dan
  /// saat pencarian baru dikirim **selagi halaman ini sudah terbuka**. Yang
  /// kedua itu jalur yang lazim: petugas menangani satu komplain, lalu
  /// mengetik nomor resi berikutnya tanpa berpindah halaman. Tanpa
  /// [didUpdateWidget] di bawah, alamatnya berubah tetapi daftarnya tidak —
  /// cacat yang tidak menimbulkan error apa pun.
  void _applyIncomingQuery() {
    final q = widget.initialQuery.trim();
    if (q.isEmpty) return;
    _search.text = q;
    // ViewModel-nya baru lahir sesudah frame pertama; menyentuhnya di dalam
    // `initState` berarti mengubah provider selagi widget sedang dibangun.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _vm.search(q);
    });
  }

  @override
  void didUpdateWidget(HistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery) _applyIncomingQuery();
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  /// Gulir tak berujung: halaman berikutnya diminta **sebelum** benar-benar
  /// menyentuh dasar, supaya daftarnya tidak sempat terasa berhenti.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final sisa = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (sisa < 400) _vm.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final async = ref.watch(historyViewModelProvider(widget.typeWire));

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.historyTitle, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  t.historySubtitle,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                _TypeChips(
                  selected: async.value?.filter.type,
                  onSelect: _vm.selectType,
                ),
                const SizedBox(height: 10),
                _SearchField(controller: _search, onChanged: _vm.search),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _vm.refresh,
              child: switch (async) {
                AsyncValue(:final value?) =>
                  _HistoryList(data: value, scroll: _scroll),
                AsyncError(:final error) => ListView(
                    children: [
                      const SizedBox(height: 80),
                      AppErrorView(failure: error, onRetry: _vm.refresh),
                    ],
                  ),
                _ => const AppListSkeleton(),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChips extends StatelessWidget {
  const _TypeChips({required this.selected, required this.onSelect});

  final VideoType? selected;
  final ValueChanged<VideoType?> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return Wrap(
      spacing: 8,
      children: [
        for (final (type, label) in <(VideoType?, String)>[
          (null, t.historyFilterAll),
          (VideoType.packing, t.videoTypePacking),
          (VideoType.returned, t.videoTypeReturn),
        ])
          ChoiceChip(
            label: Text(label),
            selected: selected == type,
            onSelected: (_) => onSelect(type),
          ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: t.historySearchHint,
        prefixIcon: const Icon(Icons.search_rounded),
        isDense: true,
        border: const OutlineInputBorder(),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: t.commonClose,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.data, required this.scroll});

  final HistoryData data;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    if (data.isEmpty) {
      // Kondisi kosong wajib membedakan dua keadaan yang terasa sangat berbeda
      // bagi penggunanya: belum pernah merekam apa pun, atau pencariannya yang
      // tidak menemukan apa-apa. Menyamakan keduanya membuat orang mengira
      // datanya hilang.
      final menyaring = !data.filter.isEmpty;
      return ListView(
        children: [
          const SizedBox(height: 60),
          AppEmptyState(
            icon: menyaring
                ? Icons.search_off_rounded
                : Icons.videocam_off_outlined,
            title: menyaring ? t.historyNoMatchTitle : t.emptyHistoryTitle,
            message: menyaring ? t.historyNoMatchBody : t.emptyHistoryMessage,
          ),
        ],
      );
    }

    return ListView.separated(
      controller: scroll,
      // Jarak bawah 88 dp — tombol Rekam mengambang menumpang di atas isi
      // halaman dan akan menutupi baris terakhir.
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
      itemCount: data.items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == data.items.length) return _ListFooter(data: data);
        return _HistoryTile(item: data.items[index]);
      },
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.data});

  final HistoryData data;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: data.loadingMore
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Text(
                data.reachedEnd ? t.historyNoMore : '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
      ),
    );
  }
}

/// Satu baris riwayat: lencana marketplace, nomor resi, nama toko, waktu,
/// durasi dan ukuran, lalu dua lencana keadaan di kanan.
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final HistoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final video = item.video;

    final gagal = video.isFailed;
    final kedaluwarsa = video.status == VideoStatus.expired;

    return Card(
      margin: EdgeInsets.zero,
      // Bab 9.4 — video gagal berlatar merah muda, yang kedaluwarsa diredupkan.
      // Keduanya tetap dapat dibuka: yang gagal untuk dicoba lagi, yang
      // kedaluwarsa untuk membaca metadatanya — metadata itu tetap sah sebagai
      // catatan walau berkas videonya sudah dihapus sesuai retensi.
      color: gagal ? colors.dangerContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(Routes.videoDetailOf(video.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Opacity(
            opacity: kedaluwarsa ? 0.6 : 1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarketplaceBadge(marketName: item.marketName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔴 Nomor resi wajib monospace (§3.3 palet): pada huruf
                      // biasa `0`/`O` dan `1`/`l`/`I` nyaris sama, sedangkan
                      // packer membacakannya lewat telepon saat sengketa.
                      Text(
                        video.resiCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.resiInline
                            .copyWith(color: theme.colorScheme.onSurface),
                      ),
                      if (item.shopLabel.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.shopLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        Formatters.dateTime(video.scanDate),
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        _durasiUkuran(context),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _TypeChip(type: video.type),
                    const SizedBox(height: 6),
                    VideoStatusChip(status: video.status),
                  ],
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _durasiUkuran(BuildContext context) {
    final t = context.l10n;
    final durasi = t.historyDuration(
      Formatters.durationFromSeconds(item.video.durationSeconds),
    );
    final bytes = item.video.fileSizeBytes;
    if (bytes == null) return durasi;
    return '$durasi • ${Formatters.fileSize(bytes)}';
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final VideoType type;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;
    final packing = type == VideoType.packing;
    final color = packing ? colors.packing : colors.returnColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        packing ? t.videoTypePacking : t.videoTypeReturn,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
