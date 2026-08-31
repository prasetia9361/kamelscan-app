import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/history_item.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/repositories/video_repository.dart';
import '../../../core/services/file_download.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/csv_export.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../navigation/route_names.dart';
import '../../../navigation/shells/web_shell.dart';
import '../../account/packers/packers_view_model.dart';
import '../../history/detail/video_detail_page.dart';
import '../../history/widgets/marketplace_badge.dart';
import '../../history/widgets/video_status_chip.dart';
import '../../shops/shops_view_model.dart';
import 'web_history_view_model.dart';
import 'widgets/export_csv_dialog.dart';

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

  /// Lebar panel samping.
  ///
  /// 440 = 16 padding + 200 pemutar tegak + 16 jarak + 192 keterangan + 16.
  /// Angka pemutarnya dari rancangan desainer; sisanya mengikuti agar nomor
  /// resi berukuran besar tetap muat satu baris di sebelahnya.
  static const double panelWidth = 440;

  @override
  ConsumerState<WebHistoryPage> createState() => _WebHistoryPageState();
}

class _WebHistoryPageState extends ConsumerState<WebHistoryPage> {
  final TextEditingController _cari = TextEditingController();

  WebHistoryViewModel get _vm =>
      ref.read(webHistoryViewModelProvider(widget.typeWire).notifier);

  bool _sedangEkspor = false;

  /// Ekspor CSV (Bab 10, keputusan Product Owner 31 Agustus 2026).
  ///
  /// Urutannya disengaja: **ambil dulu, baru tanya kolom**. Kebalikannya —
  /// tanya kolom lalu ambil — membuat Owner memilih sepuluh kotak centang
  /// untuk kemudian diberi tahu bahwa saringannya tidak cocok dengan satu baris
  /// pun. Jumlah barisnya ditampilkan di dialog justru karena sudah diketahui
  /// pada saat itu.
  Future<void> _ekspor() async {
    if (_sedangEkspor) return;
    setState(() => _sedangEkspor = true);

    final data = ref.read(webHistoryViewModelProvider(widget.typeWire)).value;
    final messenger = ScaffoldMessenger.of(context);

    final hasil = await ref
        .read(videoRepositoryProvider)
        .fetchHistoryForExport(
          filter: data?.filter ?? const VideoFilter(),
          sort: data?.sort ?? HistorySort.date,
          ascending: data?.ascending ?? false,
        );

    if (!mounted) return;
    setState(() => _sedangEkspor = false);

    if (hasil case Err(:final failure)) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.failureMessage(failure))),
      );
      return;
    }

    final halaman = hasil.unwrap();
    final t = context.l10n;

    final kolom = await showDialog<PilihanEkspor>(
      context: context,
      builder: (_) => ExportCsvDialog(
        total: halaman.total,
        maks: AppConstants.csvExportMaxRows,
      ),
    );

    if (kolom == null || kolom.isEmpty || !mounted) return;

    unduhTeks(
      namaBerkas: CsvExport.namaBerkas(DateTime.now()),
      isi: CsvExport.bangun(
        items: halaman.items,
        kolom: kolom,
        label: (k) => labelKolomCsv(t, k),
        nilai: (k, item) => nilaiKolomCsv(t, k, item),
      ),
    );

    messenger.showSnackBar(SnackBar(content: Text(t.exportDone)));
  }

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
              onShop: _vm.selectShop,
              onPacker: _vm.selectPacker,
              onDays: _vm.selectDays,
              onClear: () {
                _cari.clear();
                _vm.clearFilters();
              },
              onExport: _ekspor,
            ),
            Expanded(
              child: async.when(
                loading: () => const AppListSkeleton(itemCount: 8, itemHeight: 56),
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
                  onGoto: _vm.goToPage,
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

class _FilterBar extends ConsumerWidget {
  const _FilterBar({
    required this.controller,
    required this.filter,
    required this.onSearch,
    required this.onType,
    required this.onStatus,
    required this.onShop,
    required this.onPacker,
    required this.onDays,
    required this.onClear,
    required this.onExport,
  });

  final TextEditingController controller;
  final VideoFilter? filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<VideoType?> onType;
  final ValueChanged<VideoStatus?> onStatus;
  final ValueChanged<String?> onShop;
  final ValueChanged<String?> onPacker;
  final ValueChanged<int?> onDays;
  final VoidCallback onClear;
  final VoidCallback onExport;

  /// Rentang tanggal yang disediakan, dalam hari.
  static const List<int> rentangHari = [7, 30, 90];

  /// Menerjemahkan `filter.from` kembali menjadi salah satu [rentangHari].
  ///
  /// 🔴 Mengembalikan null bila tidak cocok persis dengan salah satunya, dan
  /// itu bukan kehati-hatian berlebihan: `DropdownButtonFormField` **melempar**
  /// bila nilai terpilihnya tidak ada di daftar pilihan. Filter yang datang
  /// dari alamat atau dari keadaan lama akan meruntuhkan seluruh halaman,
  /// bukan sekadar salah menyorot.
  static int? hariDari(DateTime? from) {
    if (from == null) return null;
    final kini = DateTime.now();
    final tengahMalam = DateTime(kini.year, kini.month, kini.day);
    final awal = DateTime(from.year, from.month, from.day);
    final hari = tengahMalam.difference(awal).inDays + 1;
    return rentangHari.contains(hari) ? hari : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final f = filter;
    final isOwner = ref.watch(sessionProvider).value?.isOwner ?? false;

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

          // 🔴 Toko dan Packer hanya untuk Owner (Bab 2.2). Bagi packer
          // keduanya tidak menyaring apa pun yang berarti: ia sudah hanya
          // melihat rekamannya sendiri, jadi menyaring "menurut packer" adalah
          // menu berisi satu nama — dirinya.
          if (isOwner) ...[
            _PilihanToko(value: f?.shopId, onChanged: onShop),
            _PilihanPacker(value: f?.userId, onChanged: onPacker),
          ],

          _Pilihan<int?>(
            label: t.tableColDate,
            value: hariDari(f?.from),
            options: [
              (null, t.historyFilterAll),
              for (final h in rentangHari) (h, t.dashboardRangeDays(h)),
            ],
            onChanged: onDays,
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

          // 🔴 Hanya Owner. Packer melihat riwayat tokonya untuk bekerja, bukan
          // untuk membawa keluar daftar seluruh pesanan beserta nomor resinya.
          //
          // ⚠️ Halaman ini memang hanya hidup di web (Bab 10), jadi tidak ada
          // penjagaan `kIsWeb` di sini — rutenya sendiri yang tidak terdaftar
          // di HP. Menambahkannya justru menyiratkan halaman ini pernah
          // dirender di HP, dan itu tidak pernah terjadi.
          if (isOwner)
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: Text(t.historyExportButton),
            ),
        ],
      ),
    );
  }
}

/// Menu turun daftar toko.
///
/// ⚠️ Selama daftarnya belum tiba atau gagal diambil, menunya tetap digambar
/// berisi *Semua* saja — bukan dihilangkan. Bilah saringan yang jumlah
/// menunya berubah-ubah membuat menu lain berpindah tempat tepat saat hendak
/// ditekan.
class _PilihanToko extends ConsumerWidget {
  const _PilihanToko({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final daftar = ref.watch(shopsViewModelProvider).value ?? const [];

    // Nilai yang tidak ada di daftar akan MELEMPAR pada DropdownButtonFormField.
    final ada = daftar.any((s) => s.shop.id == value);

    return _Pilihan<String?>(
      label: t.tableColShop,
      value: ada ? value : null,
      options: [
        (null, t.historyFilterAll),
        for (final s in daftar) (s.shop.id, s.shop.shopName),
      ],
      onChanged: onChanged,
    );
  }
}

/// Menu turun daftar packer.
class _PilihanPacker extends ConsumerWidget {
  const _PilihanPacker({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final daftar = ref.watch(packersViewModelProvider).value ?? const [];
    final ada = daftar.any((p) => p.user.id == value);

    return _Pilihan<String?>(
      label: t.tableColPacker,
      value: ada ? value : null,
      options: [
        (null, t.historyFilterAll),
        for (final p in daftar) (p.user.id, p.user.fullName),
      ],
      onChanged: onChanged,
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
    required this.onGoto,
  });

  final WebHistoryData data;
  final bool wide;
  final ValueChanged<HistorySort> onSort;
  final ValueChanged<String> onSelect;
  final VoidCallback onClosePanel;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<int> onGoto;

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
              _Halaman(
                data: data,
                onPrev: onPrev,
                onNext: onNext,
                onGoto: onGoto,
              ),
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
  resi(lebar: 200, sort: HistorySort.resi),
  type(lebar: 112, sort: HistorySort.type),
  shop(lebar: 156),
  packer(lebar: 140),
  date(lebar: 176, sort: HistorySort.date),
  duration(lebar: 88, sort: HistorySort.duration),
  status(lebar: 160, sort: HistorySort.status),
  action(lebar: 72);

  const _Kolom({required this.lebar, this.sort});

  /// Lebar rancangan desainer pada isi 1104 px (lebar jendela 1200).
  ///
  /// Dipakai sebagai **perbandingan**, bukan ukuran mati: pada layar lebih
  /// lebar kolomnya tumbuh menurut perbandingan yang sama, sehingga tabelnya
  /// mengisi ruang tanpa menyisakan jalur kosong di kanan.
  final double lebar;

  final HistorySort? sort;

  String label(AppL10n t) => switch (this) {
        _Kolom.date => t.tableColDate,
        _Kolom.resi => t.tableColResi,
        _Kolom.shop => t.tableColShop,
        _Kolom.packer => t.tableColPacker,
        _Kolom.type => t.tableColType,
        _Kolom.status => t.tableColStatus,
        _Kolom.duration => t.tableColDuration,
        _Kolom.action => t.tableColAction,
      };

  /// Jarak kiri-kanan isi tabel.
  static const double paddingH = 16;

  /// 🔴 Urutan kolom yang dibuang saat ruang menyempit — ditetapkan desainer,
  /// dan urutannya bukan selera.
  ///
  /// Resi, Tipe, Tanggal, dan Status **tidak pernah** dibuang: keempatnya yang
  /// dibutuhkan saat menangani komplain, dan komplain adalah satu-satunya
  /// alasan halaman ini dibuka dalam keadaan terburu-buru. Yang dibuang tetap
  /// dapat dilihat di panel samping.
  static const List<_Kolom> urutanBuang = [
    _Kolom.action,
    _Kolom.duration,
    _Kolom.packer,
    _Kolom.shop,
  ];

  /// Kolom dibuang, bukan dipersempit.
  ///
  /// Delapan kolom yang dipaksa muat pada 800 px menyisakan ± 95 px per kolom,
  /// dan nomor resi — satu-satunya isi yang tidak boleh terpotong — akan
  /// berakhir sebagai `JX12…`.
  static List<_Kolom> visibleFor(double tersedia) {
    final kolom = [..._Kolom.values];
    double butuh() =>
        kolom.fold<double>(0, (a, k) => a + k.lebar) + paddingH * 2;

    for (final k in urutanBuang) {
      if (butuh() <= tersedia) break;
      kolom.remove(k);
    }
    return kolom;
  }
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
      padding: const EdgeInsets.symmetric(horizontal: _Kolom.paddingH),
      // Tinggi kepala 48 dan baris 56 — angka rancangan desainer. Baris 56
      // dipilih supaya tombol aksi 48x48 muat utuh dengan sisa 4 px.
      height: 48,
      child: Row(
        children: [
          for (final k in kolom)
            Expanded(
              flex: k.lebar.round(),
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
        ]
        // 🔴 Kolom yang BISA diurutkan tetapi belum dipakai memakai panah dua
        // arah abu-abu (rancangan desainer butir 5).
        //
        // Tanpa itu, kolom yang dapat diklik terlihat persis sama dengan yang
        // tidak — dan pengurutan yang tidak pernah ditemukan sama saja dengan
        // pengurutan yang tidak ada. Ini juga yang membedakannya dari Toko dan
        // Packer, yang memang sengaja tidak dapat diurutkan.
        else if (sort != null) ...[
          const SizedBox(width: 2),
          Icon(
            Icons.unfold_more_rounded,
            size: 14,
            color: scheme.outlineVariant,
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
    final t = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;
    final video = item.video;

    // Video kedaluwarsa atau terhapus: barisnya diredupkan, bukan disembunyikan
    // (rancangan desainer butir 7). Ia masih bukti bahwa rekamannya PERNAH ada
    // — dan itu justru yang ditanyakan saat sengketa tiba terlambat.
    final pudar = video.status == VideoStatus.expired ||
        video.status == VideoStatus.deleted;

    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: pudar ? 0.55 : 1,
        child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: _Kolom.paddingH),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : null,
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            for (final k in kolom)
              Expanded(
                flex: k.lebar.round(),
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
                  // Membuka panel yang sama dengan menekan barisnya. Ada
                  // sebagai tombol tersendiri karena baris tabel tidak
                  // terlihat dapat ditekan — tidak ada satu pun tanda visual
                  // yang mengatakannya, dan yang tidak tahu akan mengira
                  // halaman ini hanya daftar bacaan.
                  _Kolom.action => Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: onTap,
                        visualDensity: VisualDensity.compact,
                        tooltip: t.tableOpenDetail,
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      ),
                    ),
                },
              ),
          ],
        ),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        // 🔴 Packing berisi penuh, Retur bergaris tepi. Bentuknya sengaja
        // berbeda, bukan hanya warnanya.
        //
        // Rancangan desainer butir 6: tipe dibedakan TIGA cara sekaligus —
        // bentuk, ikon, dan teks. Warna saja gagal bagi pengguna buta warna,
        // dan biru-ungu adalah pasangan yang paling sering tertukar
        // (`palet_warna_dan_tipografi.md` §7 butir 3).
        color: packing ? colors.packingContainer : Colors.transparent,
        border: packing ? null : Border.all(color: warna, width: 1.2),
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
          // 🔴 `Flexible`, bukan `Text` telanjang. `mainAxisSize.min` membuat
          // chip menuntut lebar aslinya dan menolak menyusut; pada kolom yang
          // sempit ia meluber — tertangkap tes pada lebar 768 dengan selisih
          // 0,29 piksel, cukup untuk menghasilkan garis kuning-hitam.
          Flexible(
            child: Text(
              packing ? t.videoTypePacking : t.videoTypeReturn,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: warna),
            ),
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
              sideBySide: true,
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

/// Deret nomor halaman pada kaki tabel Riwayat (Bab 10.5).
///
/// 🔴 Berdiri sebagai kelas tersendiri supaya **dapat diuji**. Daftar nomor
/// yang meleset satu mengirim pengguna ke halaman yang salah tanpa satu pun
/// galat — bentuk kegagalan yang sama dengan cacat menu sidebar Bab 10.3, dan
/// sama sulitnya ditemukan dengan mata: yang terlihat hanyalah deretan angka
/// yang tampak masuk akal.
class WebHistoryPagination {
  const WebHistoryPagination._();

  /// Berapa nomor yang digambar sebelum diringkas dengan elipsis.
  static const int ambangRingkas = 7;

  /// Nomor halaman yang digambar; `null` berarti elipsis.
  ///
  /// 🔴 Fungsi murni supaya dapat diuji. Daftar nomor yang meleset satu
  /// mengirim pengguna ke halaman yang salah **tanpa satu pun galat** — sama
  /// bentuknya dengan cacat menu sidebar (Bab 10.3), dan sama sulitnya
  /// ditemukan dengan mata.
  ///
  /// Nomor di sini berbasis nol; layar menambahkan satu saat menuliskannya.
  static List<int?> nomorHalaman({required int page, required int pageCount}) {
    if (pageCount <= ambangRingkas) {
      return [for (var i = 0; i < pageCount; i++) i];
    }

    // Halaman pertama dan terakhir selalu ada: keduanya tujuan yang paling
    // sering diminta ("dari awal", "yang paling lama").
    final terpilih = <int>{0, pageCount - 1, page};
    for (final geser in [-1, 1]) {
      terpilih.add(page + geser);
    }
    // Di dekat ujung, deretnya dipanjangkan ke dalam supaya jumlah tombolnya
    // tidak berubah-ubah saat berpindah halaman — tombol yang berpindah
    // tempat justru tertekan keliru.
    if (page <= 2) terpilih.addAll([1, 2]);
    if (page >= pageCount - 3) {
      terpilih.addAll([pageCount - 2, pageCount - 3]);
    }

    final urut = terpilih.where((n) => n >= 0 && n < pageCount).toList()..sort();

    final hasil = <int?>[];
    int? sebelumnya;
    for (final n in urut) {
      if (sebelumnya != null && n - sebelumnya > 1) hasil.add(null);
      hasil.add(n);
      sebelumnya = n;
    }
    return hasil;
  }

}

class _Halaman extends StatelessWidget {
  const _Halaman({
    required this.data,
    required this.onPrev,
    required this.onNext,
    required this.onGoto,
  });

  final WebHistoryData data;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<int> onGoto;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nomor = WebHistoryPagination.nomorHalaman(
      page: data.page,
      pageCount: data.pageCount,
    );

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: _Kolom.paddingH),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              // Angka barisnya ikut ditulis, bukan hanya nomor halaman.
              // "1-25 dari 431 video" menjawab pertanyaan yang benar-benar
              // diajukan orang saat menelusuri bukti: berapa lagi yang tersisa.
              t.tableShowingRange(
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
          for (final n in nomor)
            if (n == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('…',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              )
            else
              _TombolHalaman(
                nomor: n,
                aktif: n == data.page,
                onTap: () => onGoto(n),
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

class _TombolHalaman extends StatelessWidget {
  const _TombolHalaman({
    required this.nomor,
    required this.aktif,
    required this.onTap,
  });

  final int nomor;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: aktif ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minWidth: 32),
          height: 32,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: aktif ? scheme.primary : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            Formatters.number(nomor + 1),
            style: theme.textTheme.labelMedium?.copyWith(
              color: aktif ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
