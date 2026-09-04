import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/admin_tenant_row.dart';
import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_failure.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'admin_users_view_model.dart';

/// Kelola Pengguna (Bab 11.2) — tabel seluruh pelanggan beserta aksinya.
///
/// 🔴 Halaman kedua yang menampilkan data **lintas seluruh pelanggan**, dan
/// satu-satunya yang dapat **mengubahnya**. Penjagaannya berada di server:
/// `admin_list_tenants()` menolak siapa pun yang bukan admin dengan galat,
/// bukan dengan daftar kosong — daftar kosong akan terbaca sebagai "platform
/// ini belum punya pelanggan".
///
/// 🔴 Berdiri di luar rangka aplikasi, seperti seluruh rute admin. Jalan
/// keluarnya adalah tombol kembali bawaan `AppBar` menuju menu Admin — sama
/// seperti Dasbor Platform dan Verifikasi Pembayaran. Panel admin sempat tidak
/// punya jalan masuk maupun keluar sama sekali (P.2); jangan menghapus
/// `AppBar` ini demi tata letak.
class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  /// Lebar panel samping.
  ///
  /// Lebih sempit daripada panel Riwayat (440) karena tidak memuat pemutar
  /// video — isinya hanya keterangan dan tombol.
  static const double panelWidth = 380;

  /// Di bawah lebar ini tabelnya berubah menjadi kartu, dan menekan kartu
  /// membuka lembar bawah alih-alih panel samping.
  ///
  /// 🔴 1024, bukan 768 seperti Riwayat. Tabel ini punya sepuluh kolom dan
  /// panelnya 380 px: pada 768 px yang tersisa untuk tabelnya hanya 388 px,
  /// dan yang tampak di layar bukan tabel lagi melainkan tiga kolom terpotong
  /// di samping panel.
  static const double wideBreakpoint = 1024;

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final TextEditingController _cari = TextEditingController();

  AdminUsersViewModel get _vm => ref.read(adminUsersViewModelProvider.notifier);

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  /// Layar sempit: detailnya dibuka sebagai lembar bawah.
  ///
  /// Isinya widget yang sama persis dengan panel samping. Menyalinnya menjadi
  /// susunan kedua berarti dua tempat yang harus diperbaiki setiap kali salah
  /// satunya keliru, dan yang kedua selalu ketinggalan.
  Future<void> _bukaLembar(AdminTenantRow baris) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, controller) => _Detail(
          baris: baris,
          scrollController: controller,
          onSelesai: () => Navigator.pop(sheetContext),
        ),
      ),
    );
  }

  /// Pemberian token serentak ke seluruh pelanggan aktif.
  ///
  /// 🔴 Satu-satunya tombol di aplikasi ini yang mengubah **banyak pelanggan
  /// sekaligus**, dan tidak ada pembatalan. Karena itu jumlah sasarannya
  /// ditulis di dialog sebelum ditekan, dan hasilnya dilaporkan sebagai DUA
  /// angka — berapa yang jadi sasaran dan berapa yang benar-benar berubah.
  /// Selisih di antara keduanya berarti ada dompet yang hilang, dan itu justru
  /// yang perlu diselidiki; satu angka akan menutupinya.
  Future<void> _beriTokenSerentak(int jumlahAktif) async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final isian = await showDialog<({int delta, String reason})>(
      context: context,
      builder: (d) => _DialogTokenSerentak(jumlahAktif: jumlahAktif),
    );
    if (isian == null || !mounted) return;

    final hasil = await _vm.grantTokensToAll(
      delta: isian.delta,
      reason: isian.reason,
    );
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          hasil.failure != null
              ? context.failureMessage(hasil.failure!)
              : t.adminUsersGrantAllDone(
                  Formatters.number(isian.delta),
                  Formatters.number(hasil.granted),
                  Formatters.number(hasil.target),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final async = ref.watch(adminUsersViewModelProvider);

    // Dihitung dari seluruh baris, BUKAN dari yang lolos saringan. Tombolnya
    // memang mengenai semua pelanggan aktif, dan menuliskan angka hasil
    // saringan di sini akan menjanjikan sesuatu yang tidak dilakukannya.
    final aktif = (async.value?.all ?? const <AdminTenantRow>[])
        .where((r) => r.status == TenantStatus.active)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.adminUsersTitle),
        actions: [
          IconButton(
            onPressed: aktif == 0 ? null : () => _beriTokenSerentak(aktif),
            tooltip: t.adminUsersGrantAllTitle,
            icon: const Icon(Icons.card_giftcard_outlined),
          ),
          IconButton(
            onPressed: _vm.refresh,
            tooltip: t.commonRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, batas) {
          final lebar = batas.maxWidth >= AdminUsersPage.wideBreakpoint;

          return async.when(
            loading: () => const AppListSkeleton(itemCount: 8, itemHeight: 56),
            error: (error, _) =>
                AppErrorView(failure: error, onRetry: _vm.refresh),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FilterBar(
                  controller: _cari,
                  data: data,
                  onSearch: _vm.search,
                  onStatus: _vm.selectStatus,
                  onTier: _vm.selectTier,
                  onClear: () {
                    _cari.clear();
                    _vm.clearFilters();
                  },
                ),
                Expanded(
                  child: _Isi(
                    data: data,
                    wide: lebar,
                    onSort: _vm.sortBy,
                    onSelect: (baris) =>
                        lebar ? _vm.select(baris.id) : _bukaLembar(baris),
                    onClosePanel: () => _vm.select(null),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Saringan
// ---------------------------------------------------------------------------

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.controller,
    required this.data,
    required this.onSearch,
    required this.onStatus,
    required this.onTier,
    required this.onClear,
  });

  final TextEditingController controller;
  final AdminUsersData data;
  final ValueChanged<String> onSearch;
  final ValueChanged<TenantStatus?> onStatus;
  final ValueChanged<TierPlan?> onTier;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                hintText: t.adminUsersSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
              ),
            ),
          ),
          _Pilihan<TenantStatus?>(
            label: t.tableColStatus,
            value: data.status,
            options: [
              (null, t.historyFilterAll),
              for (final s in TenantStatus.values) (s, labelStatus(t, s)),
            ],
            onChanged: onStatus,
          ),
          _Pilihan<TierPlan?>(
            label: t.tableColTier,
            value: data.tier,
            options: [
              (null, t.historyFilterAll),
              (TierPlan.standar, t.tierStandar),
              (TierPlan.pro, t.tierPro),
            ],
            onChanged: onTier,
          ),
          if (data.hasFilter)
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: Text(t.tableClearFilters),
            ),

          // Jumlah baris yang sedang tampil, bukan jumlah seluruhnya.
          //
          // Tanpa angka ini, saringan yang tidak sengaja tertinggal aktif
          // membuat halaman terlihat seperti platform yang kehilangan
          // pelanggan — dan tombol "Hapus saringan" di sebelahnya tidak cukup
          // untuk menjelaskannya.
          Text(
            t.adminUsersCount(Formatters.number(data.items.length)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu menu turun saringan.
///
/// 🔴 Dibungkus [SizedBox] berlebar tetap dengan sengaja, dan
/// `isExpanded: true` bukan pilihan gaya: tanpa keduanya `DropdownButton`
/// melebar mengikuti pilihan terpanjangnya, sehingga menu di sebelahnya
/// bergeser tepat saat hendak ditekan.
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
      width: 170,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          for (final (v, teks) in options)
            DropdownMenuItem<T>(
              value: v,
              child: Text(teks, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) => onChanged(v as T),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tabel
// ---------------------------------------------------------------------------

class _Isi extends StatelessWidget {
  const _Isi({
    required this.data,
    required this.wide,
    required this.onSort,
    required this.onSelect,
    required this.onClosePanel,
  });

  final AdminUsersData data;
  final bool wide;
  final ValueChanged<AdminTenantSort> onSort;
  final ValueChanged<AdminTenantRow> onSelect;
  final VoidCallback onClosePanel;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final baris = data.items;

    if (baris.isEmpty) {
      return AppEmptyState(
        title: data.hasFilter
            ? t.adminUsersNoMatchTitle
            : t.adminUsersEmptyTitle,
        message: data.hasFilter
            ? t.adminUsersNoMatchBody
            : t.adminUsersEmptyBody,
        icon: Icons.group_outlined,
      );
    }

    final terpilih = data.selected;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: wide
              ? _Tabel(data: data, onSort: onSort, onSelect: onSelect)
              : _Kartu(items: baris, onSelect: onSelect),
        ),
        if (wide && terpilih != null)
          SizedBox(
            width: AdminUsersPage.panelWidth,
            child: _PanelSamping(baris: terpilih, onClose: onClosePanel),
          ),
      ],
    );
  }
}

/// Kolom tabel beserta lebar nisbinya.
///
/// 🔴 Email **tidak dapat diurutkan**, dan itu bukan kelalaian: mengurutkan
/// pelanggan menurut abjad emailnya tidak menjawab pertanyaan apa pun yang
/// pernah dibawa seseorang ke halaman ini. Judulnya karena itu tidak dibuat
/// dapat ditekan — judul yang dapat ditekan tetapi tidak melakukan apa pun
/// lebih membingungkan daripada judul biasa.
enum _Kolom {
  business(lebar: 200, sort: AdminTenantSort.business),
  email(lebar: 210),
  phone(lebar: 140),
  tier(lebar: 96, sort: AdminTenantSort.tier),
  status(lebar: 128, sort: AdminTenantSort.status),
  joined(lebar: 116, sort: AdminTenantSort.created),
  period(lebar: 126, sort: AdminTenantSort.period),
  shops(lebar: 72, sort: AdminTenantSort.shops),
  packers(lebar: 80, sort: AdminTenantSort.packers),
  videos(lebar: 80, sort: AdminTenantSort.videos),
  tokens(lebar: 84, sort: AdminTenantSort.tokens);

  const _Kolom({required this.lebar, this.sort});

  /// Dipakai sebagai **perbandingan**, bukan ukuran mati: pada layar lebih
  /// lebar kolomnya tumbuh menurut perbandingan yang sama, sehingga tabelnya
  /// mengisi ruang tanpa menyisakan jalur kosong di kanan.
  final double lebar;

  final AdminTenantSort? sort;

  String label(AppL10n t) => switch (this) {
    _Kolom.business => t.tableColBusiness,
    _Kolom.email => t.tableColEmail,
    _Kolom.phone => t.tableColPhone,
    _Kolom.tier => t.tableColTier,
    _Kolom.status => t.tableColStatus,
    _Kolom.joined => t.tableColJoined,
    _Kolom.period => t.tableColPeriodEnd,
    _Kolom.shops => t.tableColShops,
    _Kolom.packers => t.tableColPackers,
    _Kolom.videos => t.tableColVideos,
    _Kolom.tokens => t.tableColTokens,
  };

  /// Jarak kiri-kanan isi tabel.
  static const double paddingH = 16;

  /// 🔴 Urutan kolom yang dibuang saat ruang menyempit.
  ///
  /// Nama usaha, Paket, Status, dan Akhir Periode **tidak pernah** dibuang:
  /// keempatnya yang dibutuhkan saat memutuskan sesuatu tentang seorang
  /// pelanggan, dan memutuskan adalah satu-satunya alasan halaman ini dibuka.
  /// Yang dibuang tetap terlihat di panel samping.
  static const List<_Kolom> urutanBuang = [
    _Kolom.shops,
    _Kolom.packers,

    // 🔴 Nomor HP dibuang SEBELUM email, bukan sesudahnya.
    //
    // Keduanya kontak, jadi salah satu memang harus pergi lebih dulu di layar
    // sempit. Yang dipertahankan email karena ia satu-satunya yang tidak
    // pernah kosong: `users.phone` tidak wajib diisi dan pendaftar lewat
    // Google tidak pernah ditanya nomornya, sehingga kolom nomor HP pada
    // sebagian pelanggan hanya berisi tanda hubung — kolom yang memakan lebar
    // tanpa memberi apa pun justru di layar yang paling kekurangan lebar.
    _Kolom.phone,
    _Kolom.email,
    _Kolom.tokens,
    _Kolom.joined,
    _Kolom.videos,
  ];

  /// Kolom dibuang, bukan dipersempit.
  ///
  /// Sepuluh kolom yang dipaksa muat pada 900 px menyisakan ± 87 px per
  /// kolom, dan nama usaha — satu-satunya isi yang harus terbaca utuh —
  /// berakhir sebagai `Toko Ma…`.
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

  final AdminUsersData data;
  final ValueChanged<AdminTenantSort> onSort;
  final ValueChanged<AdminTenantRow> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, batas) {
        final kolom = _Kolom.visibleFor(batas.maxWidth);
        final baris = data.items;

        return Column(
          children: [
            _BarisJudul(kolom: kolom, data: data, onSort: onSort),
            Expanded(
              child: ListView.builder(
                itemCount: baris.length,
                itemBuilder: (context, i) => _BarisData(
                  kolom: kolom,
                  baris: baris[i],
                  selected: baris[i].id == data.selectedId,
                  onTap: () => onSelect(baris[i]),
                ),
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
  final AdminUsersData data;
  final ValueChanged<AdminTenantSort> onSort;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: _Kolom.paddingH),
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
  final AdminTenantSort? sort;
  final bool active;
  final bool ascending;
  final ValueChanged<AdminTenantSort> onSort;

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
            ascending
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 14,
            color: scheme.primary,
          ),
        ]
        // 🔴 Kolom yang BISA diurutkan tetapi belum dipakai memakai panah dua
        // arah abu-abu — mengikuti tabel Riwayat. Tanpa itu, kolom yang dapat
        // diklik terlihat persis sama dengan yang tidak, dan pengurutan yang
        // tidak pernah ditemukan sama saja dengan pengurutan yang tidak ada.
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
    required this.baris,
    required this.selected,
    required this.onTap,
  });

  final List<_Kolom> kolom;
  final AdminTenantRow baris;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;

    // Pelanggan yang ditangguhkan atau periodenya sudah berakhir diredupkan,
    // bukan disembunyikan. Ia justru yang paling sering dicari — untuk
    // diaktifkan kembali.
    final pudar = !baris.canRecord;

    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: pudar ? 0.6 : 1,
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
                    // 🔴 Lencana "Akun Admin" ditempelkan di sini, bukan di
                    // kolom tersendiri. Kolom baru akan ikut dibuang saat
                    // ruang menyempit — dan justru pada layar sempit itulah
                    // baris ini paling mudah tertekan tanpa sengaja.
                    _Kolom.business => Row(
                      children: [
                        Flexible(
                          child: Text(
                            baris.businessName?.trim().isNotEmpty ?? false
                                ? baris.businessName!
                                : t.adminUsersNoBusinessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  baris.businessName?.trim().isNotEmpty ?? false
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                              fontStyle:
                                  baris.businessName?.trim().isNotEmpty ?? false
                                  ? null
                                  : FontStyle.italic,
                            ),
                          ),
                        ),
                        if (baris.ownerIsAdmin) ...[
                          const SizedBox(width: 6),
                          AdminOwnChip(colors: colors),
                        ],
                      ],
                    ),
                    _Kolom.email => Text(
                      baris.ownerEmail ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),

                    // ⚠️ Tanda hubung, bukan sel kosong. Sel kosong terbaca
                    // seperti tabel yang gagal memuat; tanda hubung menyatakan
                    // nomornya memang tidak ada — dan pada halaman yang
                    // dipakai menghubungi pelanggan, perbedaan itu menentukan
                    // apakah Admin mencari nomornya di tempat lain.
                    _Kolom.phone => Text(
                      (baris.ownerPhone ?? '').trim().isEmpty
                          ? '—'
                          : baris.ownerPhone!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    _Kolom.tier => Align(
                      alignment: Alignment.centerLeft,
                      child: TierChip(plan: baris.tierPlan, colors: colors),
                    ),
                    _Kolom.status => Align(
                      alignment: Alignment.centerLeft,
                      child: TenantStatusChip(
                        status: baris.status,
                        colors: colors,
                      ),
                    ),
                    _Kolom.joined => Text(
                      baris.createdAt == null
                          ? '—'
                          : Formatters.date(baris.createdAt!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    _Kolom.period => Text(
                      baris.periodEnd == null
                          ? '—'
                          : Formatters.date(baris.periodEnd!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    _Kolom.shops => _Angka(baris.shopCount),
                    _Kolom.packers => _Angka(baris.packerCount),
                    _Kolom.videos => _Angka(baris.videoCount),
                    _Kolom.tokens => _Angka(baris.tokenBalance),
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Angka pemakaian di dalam sel tabel.
///
/// Memakai angka bertabulasi supaya kolomnya berbaris lurus ke bawah — pada
/// huruf biasa `1` jauh lebih sempit daripada `8`, dan kolom angka yang tidak
/// lurus jauh lebih sulit dibandingkan sekilas.
class _Angka extends StatelessWidget {
  const _Angka(this.value);

  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      Formatters.number(value),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.statNumber.copyWith(
        color: theme.colorScheme.onSurface,
        fontSize: 14,
        height: 20 / 14,
      ),
    );
  }
}

/// Bentuk kartu untuk layar sempit — tabel yang sama, dilipat.
class _Kartu extends StatelessWidget {
  const _Kartu({required this.items, required this.onSelect});

  final List<AdminTenantRow> items;
  final ValueChanged<AdminTenantRow> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final baris = items[i];

        return Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: () => onSelect(baris),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          baris.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (baris.ownerIsAdmin) ...[
                        AdminOwnChip(colors: colors),
                        const SizedBox(width: 6),
                      ],
                      TierChip(plan: baris.tierPlan, colors: colors),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TenantStatusChip(status: baris.status, colors: colors),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          baris.ownerEmail ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Lencana
// ---------------------------------------------------------------------------

/// Lencana paket Standar / Pro.
class TierChip extends StatelessWidget {
  const TierChip({super.key, required this.plan, required this.colors});

  final TierPlan plan;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final pro = plan == TierPlan.pro;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        // Pro berisi penuh, Standar bergaris tepi — bentuknya berbeda, bukan
        // hanya warnanya (`palet_warna_dan_tipografi.md` §7).
        color: pro ? colors.packingContainer : Colors.transparent,
        border: pro
            ? null
            : Border.all(color: theme.colorScheme.outline, width: 1.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        pro ? t.tierPro : t.tierStandar,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          color: pro ? colors.packing : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Lencana status pelanggan.
///
/// 🔴 Ikon **dan** warna, bukan warna saja. Ditangguhkan dan Berakhir adalah
/// dua keadaan yang akibatnya sama-sama berat bagi pelanggan tetapi
/// penanganannya berlawanan — yang satu dicabut Admin, yang satu dibayar
/// pelanggan. Membedakannya hanya lewat merah dan abu-abu adalah cara
/// tercepat menangani yang salah.
class TenantStatusChip extends StatelessWidget {
  const TenantStatusChip({
    super.key,
    required this.status,
    required this.colors,
  });

  final TenantStatus status;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);

    final (warna, ikon) = switch (status) {
      TenantStatus.trial => (colors.warning, Icons.hourglass_bottom_outlined),
      TenantStatus.active => (colors.success, Icons.check_circle_outline),
      TenantStatus.suspended => (colors.danger, Icons.block_outlined),
      TenantStatus.expired => (
        theme.colorScheme.outline,
        Icons.event_busy_outlined,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: warna, width: 1.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 13, color: warna),
          const SizedBox(width: 4),
          // 🔴 `Flexible`, bukan `Text` telanjang. `mainAxisSize.min` membuat
          // chip menuntut lebar aslinya dan menolak menyusut; pada kolom
          // sempit ia meluber dan menghasilkan garis kuning-hitam.
          Flexible(
            child: Text(
              labelStatus(t, status),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(color: warna),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lencana "Akun Admin" — menandai tenant milik akun admin sendiri.
///
/// 🔴 Ikon **dan** teks, bukan sekadar warna berbeda. Baris ini satu-satunya
/// di seluruh tabel yang tombol aksinya mati, dan pembacanya harus tahu
/// alasannya sebelum ia mencoba menekan.
class AdminOwnChip extends StatelessWidget {
  const AdminOwnChip({super.key, required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.packingContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 13, color: colors.packing),
          const SizedBox(width: 4),
          // `Flexible` wajib: `mainAxisSize.min` membuat chip menolak
          // menyusut, dan pada kolom sempit ia meluber.
          Flexible(
            child: Text(
              t.adminUsersOwnAccount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.packing,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String labelStatus(AppL10n t, TenantStatus s) => switch (s) {
  TenantStatus.trial => t.tenantStatusTrial,
  TenantStatus.active => t.tenantStatusActive,
  TenantStatus.suspended => t.tenantStatusSuspended,
  TenantStatus.expired => t.tenantStatusExpired,
};

// ---------------------------------------------------------------------------
// Panel samping & detail
// ---------------------------------------------------------------------------

class _PanelSamping extends StatelessWidget {
  const _PanelSamping({required this.baris, required this.onClose});

  final AdminTenantRow baris;
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
                    t.adminUsersDetailTitle,
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
            child: _Detail(
              // 🔴 `key` wajib memakai id pelanggannya. Tanpa itu, memilih
              // baris lain memakai ulang State yang sama dan panelnya tetap
              // membawa keadaan "sedang mengerjakan" milik baris sebelumnya.
              key: ValueKey(baris.id),
              baris: baris,
            ),
          ),
        ],
      ),
    );
  }
}

/// Isi panel: keterangan, angka pemakaian, dan ketiga tombol aksi.
///
/// Dipakai oleh panel samping **dan** lembar bawah di layar sempit. Satu
/// susunan, dua tempat.
class _Detail extends ConsumerStatefulWidget {
  const _Detail({
    super.key,
    required this.baris,
    this.scrollController,
    this.onSelesai,
  });

  final AdminTenantRow baris;

  /// Diisi hanya saat dipakai di dalam lembar bawah.
  final ScrollController? scrollController;

  /// Dipanggil sesudah satu aksi berhasil — menutup lembar bawah. Panel
  /// samping tidak perlu ditutup: barisnya diperbarui di tempat.
  final VoidCallback? onSelesai;

  @override
  ConsumerState<_Detail> createState() => _DetailState();
}

class _DetailState extends ConsumerState<_Detail> {
  bool _sedang = false;

  AdminUsersViewModel get _vm => ref.read(adminUsersViewModelProvider.notifier);

  AdminTenantRow get _baris => widget.baris;

  /// Aksi dimatikan karena baris ini adalah tenant milik akun admin sendiri.
  ///
  /// 🔴 Menangguhkan diri sendiri, atau mengurangi token sendiri sampai nol,
  /// tidak punya kegunaan apa pun dan akibatnya baru terasa saat admin
  /// mencoba memakai akunnya sebagai pengguna biasa. Penjagaan ini ada di
  /// layar saja — server tetap mengizinkannya, karena admin memang berhak
  /// mengubah tenant mana pun.
  bool get _terkunci => _baris.ownerIsAdmin;

  bool get _matikan => _sedang || _terkunci;

  Future<void> _jalankan(
    Future<AppFailure?> Function() aksi,
    String pesanBerhasil,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _sedang = true);
    final gagal = await aksi();
    if (!mounted) return;
    setState(() => _sedang = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          gagal == null ? pesanBerhasil : context.failureMessage(gagal),
        ),
      ),
    );
    if (gagal == null) widget.onSelesai?.call();
  }

  Future<void> _ubahPaket(TierPlan tujuan) async {
    final t = context.l10n;

    // 🔴 Konfirmasi menyebut NAMA USAHA dan paket tujuannya, bukan sekadar
    // "Anda yakin?". Yang ditekan Admin adalah baris ke-sekian dalam daftar,
    // dan satu-satunya penjagaan terhadap mengubah baris yang salah adalah
    // melihat namanya tertulis ulang sebelum menekan.
    final yakin = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t.adminUsersChangeTierTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.adminUsersChangeTierBody(
                _baris.label,
                tujuan == TierPlan.pro ? t.tierPro : t.tierStandar,
              ),
            ),
            const SizedBox(height: 10),
            // Jebakan nomor 8 di prompt serah terima: peran dan tier dibawa di
            // dalam JWT. Tanpa kalimat ini, Admin akan mengira perubahannya
            // gagal saat pelanggan menelepon dan berkata tidak ada yang
            // berubah.
            _Catatan(teks: t.adminUsersJwtWarning),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(t.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(t.adminUsersChangeTier),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    await _jalankan(
      () => _vm.changeTier(_baris, tujuan),
      t.adminUsersTierChanged,
    );
  }

  Future<void> _ubahStatus(TenantStatus tujuan) async {
    final t = context.l10n;
    final tangguhkan = tujuan == TenantStatus.suspended;

    final yakin = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(
          tangguhkan ? t.adminUsersSuspendTitle : t.adminUsersActivateTitle,
        ),
        content: Text(
          tangguhkan
              ? t.adminUsersSuspendBody(_baris.label)
              : t.adminUsersActivateBody(_baris.label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(t.commonCancel),
          ),
          if (tangguhkan)
            TextButton(
              onPressed: () => Navigator.pop(d, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(d).colorScheme.error,
              ),
              child: Text(t.adminUsersSuspend),
            )
          else
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text(t.adminUsersActivate),
            ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    await _jalankan(
      () => _vm.setStatus(_baris, tujuan),
      tangguhkan ? t.adminUsersSuspendedDone : t.adminUsersActivatedDone,
    );
  }

  Future<void> _perpanjang() async {
    final t = context.l10n;

    final akhirBaru = await showDialog<DateTime>(
      context: context,
      builder: (d) => _DialogPerpanjang(baris: _baris),
    );
    if (akhirBaru == null || !mounted) return;

    await _jalankan(
      () => _vm.extendPeriod(
        _baris,
        periodEnd: akhirBaru,
        reactivate: Perpanjangan.aktifkan(_baris.status),
      ),
      t.adminUsersExtended,
    );
  }

  Future<void> _ubahToken() async {
    final t = context.l10n;

    final hasil = await showDialog<({int delta, String reason})>(
      context: context,
      builder: (d) => _DialogToken(baris: _baris),
    );
    if (hasil == null || !mounted) return;

    await _jalankan(
      () => _vm.adjustTokens(_baris, delta: hasil.delta, reason: hasil.reason),
      t.adminUsersTokenDone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;
    final baris = _baris;
    final sisa = baris.daysUntilExpiry();

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(baris.label, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          baris.ownerEmail ?? t.adminUsersNoEmail,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),

        // 🔴 `Wrap`, bukan `Row`. Ketiga chip ini berlebar tetap
        // (`mainAxisSize.min` menolak menyusut), dan bertiga mereka meluber
        // 53 piksel pada panel 380 px — tertangkap tes, bukan mata. `Row`
        // sempat dipakai karena chip ketiga baru muncul pada satu baris dari
        // tujuh, jadi luberannya tidak terlihat saat halaman dilihat sekilas.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TenantStatusChip(status: baris.status, colors: colors),
            TierChip(plan: baris.tierPlan, colors: colors),
            if (baris.ownerIsAdmin) AdminOwnChip(colors: colors),
          ],
        ),

        // 🔴 Barisnya sendiri. Dijelaskan, bukan sekadar tombolnya dimatikan.
        //
        // Tombol mati tanpa alasan terbaca sebagai kerusakan, dan yang
        // menemuinya akan mencoba lagi lewat SQL Editor — persis jalan yang
        // paling berbahaya.
        if (baris.ownerIsAdmin) ...[
          const SizedBox(height: 12),
          _Catatan(teks: t.adminUsersOwnAccountBody),
        ],

        const SizedBox(height: 20),

        _Keterangan(
          label: t.tableColJoined,
          value: baris.createdAt == null
              ? '—'
              : Formatters.date(baris.createdAt!),
        ),
        _Keterangan(
          label: t.tableColPeriodEnd,
          value: baris.periodEnd == null
              ? '—'
              : Formatters.date(baris.periodEnd!),
          // 🔴 Sisa hari ditulis di sini, bukan dibiarkan dihitung sendiri
          // dari tanggalnya. Inilah angka yang menentukan tindakan — dan
          // menghitung selisih tanggal di kepala adalah pekerjaan yang
          // gampang salah tepat ketika sedang terburu-buru.
          note: baris.periodEnd == null
              ? t.adminUsersTrialNoPeriod
              : switch (sisa) {
                  null => null,
                  0 => t.adminUsersEndsToday,
                  final int n when n < 0 => t.adminUsersEndedDaysAgo(
                    Formatters.number(-n),
                  ),
                  final int n => t.adminUsersDaysLeft(Formatters.number(n)),
                },
          noteColor: (sisa != null && sisa <= 7) ? colors.warning : null,
        ),

        const SizedBox(height: 20),
        _JudulBagian(t.adminUsersUsageTitle),
        _Keterangan(
          label: t.tableColShops,
          value: Formatters.number(baris.shopCount),
        ),
        _Keterangan(
          label: t.tableColPackers,
          value: Formatters.number(baris.packerCount),
        ),
        _Keterangan(
          label: t.tableColVideos,
          value: Formatters.number(baris.videoCount),
          // ⚠️ Keterangan ini WAJIB, dan alasannya sama dengan di dasbor
          // platform: angka ini menghitung yang pernah direkam, bukan yang
          // masih tersimpan. Selisih yang tidak dijelaskan terbaca sebagai
          // kerusakan (O.16).
          note: t.adminUsersVideosNote,
        ),
        _Keterangan(
          label: t.tableColTokens,
          value: Formatters.number(baris.tokenBalance),
        ),

        const SizedBox(height: 24),
        _JudulBagian(t.adminUsersActionsTitle),
        const SizedBox(height: 4),

        // Tombol disusun ke bawah, satu per baris.
        //
        // 🔴 Bukan berdampingan di dalam `Row`. Tombol bertema proyek ini
        // menuntut lebar TAK TERHINGGA (`filledButtonTheme.minimumSize:
        // Size.fromHeight`), dan pada panel selebar 380 px dua tombol
        // berdampingan sudah dua kali menggencet tetangganya sampai nol
        // (M.12, M.17). Ke bawah tidak punya masalah itu sama sekali.
        FilledButton.tonalIcon(
          onPressed: _matikan
              ? null
              : () => _ubahPaket(
                  baris.tierPlan == TierPlan.pro
                      ? TierPlan.standar
                      : TierPlan.pro,
                ),
          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
          label: Text(
            t.adminUsersMakePlan(
              baris.tierPlan == TierPlan.pro ? t.tierStandar : t.tierPro,
            ),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: _matikan ? null : _perpanjang,
          icon: const Icon(Icons.event_available_outlined, size: 18),
          label: Text(t.adminUsersExtend),
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: _matikan ? null : _ubahToken,
          icon: const Icon(Icons.toll_outlined, size: 18),
          label: Text(t.adminUsersTokenAction),
        ),
        const SizedBox(height: 10),
        if (baris.status == TenantStatus.suspended)
          FilledButton.icon(
            onPressed: _matikan ? null : () => _ubahStatus(TenantStatus.active),
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: Text(t.adminUsersActivate),
          )
        else
          OutlinedButton.icon(
            onPressed: _matikan
                ? null
                : () => _ubahStatus(TenantStatus.suspended),
            style: OutlinedButton.styleFrom(foregroundColor: colors.danger),
            icon: const Icon(Icons.block_outlined, size: 18),
            label: Text(t.adminUsersSuspend),
          ),

        if (_sedang) ...[
          const SizedBox(height: 16),
          const Center(
            child: SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ],
      ],
    );
  }
}

/// Dialog perpanjangan: empat lama siap pakai, atau tanggal pilihan sendiri.
class _DialogPerpanjang extends StatefulWidget {
  const _DialogPerpanjang({required this.baris});

  final AdminTenantRow baris;

  @override
  State<_DialogPerpanjang> createState() => _DialogPerpanjangState();
}

class _DialogPerpanjangState extends State<_DialogPerpanjang> {
  /// null = belum ada yang dipilih.
  DateTime? _akhirBaru;

  late final DateTime _kini = DateTime.now();
  late final DateTime _dasar = Perpanjangan.dasar(widget.baris, _kini);

  Future<void> _pilihTanggal() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: _akhirBaru ?? Perpanjangan.tambahBulan(_dasar, 1),
      // Tidak boleh memilih tanggal yang sudah lewat: "memperpanjang" ke
      // kemarin adalah cara mengakhiri langganan, dan itu pekerjaan tombol
      // Tangguhkan — bukan tombol ini.
      firstDate: _kini,
      lastDate: DateTime(_kini.year + 5),
    );
    if (hasil == null || !mounted) return;
    setState(() => _akhirBaru = hasil);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final baris = widget.baris;
    final pilihan = _akhirBaru;

    // Dari mana perhitungannya dimulai — dikatakan, bukan dibiarkan ditebak.
    final asal = baris.periodEnd == null
        ? t.adminUsersExtendFromTrial
        : (_dasar == _kini
              ? t.adminUsersExtendFromToday
              : t.adminUsersExtendContinues(Formatters.date(_dasar)));

    return AlertDialog(
      title: Text(t.adminUsersExtendTitle(baris.label)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(asal, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            t.adminUsersExtendVsPayment,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final bulan in Perpanjangan.pilihanBulan)
                ChoiceChip(
                  label: Text(t.adminUsersExtendMonths(bulan)),
                  selected: pilihan == Perpanjangan.tambahBulan(_dasar, bulan),
                  onSelected: (_) => setState(
                    () => _akhirBaru = Perpanjangan.tambahBulan(_dasar, bulan),
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.event_outlined, size: 16),
                label: Text(t.adminUsersExtendPickDate),
                onPressed: _pilihTanggal,
              ),
            ],
          ),

          if (pilihan != null) ...[
            const SizedBox(height: 16),
            Text(
              t.adminUsersExtendNewEnd(Formatters.date(pilihan)),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _Catatan(
              teks: Perpanjangan.aktifkan(baris.status)
                  ? t.adminUsersExtendReactivate
                  : (baris.status == TenantStatus.suspended
                        ? t.adminUsersExtendKeepSuspended
                        : t.adminUsersJwtWarning),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.commonCancel),
        ),
        FilledButton(
          // Tetap mati sampai ada tanggal yang dipilih. Tombol yang dapat
          // ditekan tanpa pilihan hanya punya satu arti yang mungkin — dan
          // menebaknya adalah persis yang tidak boleh dilakukan halaman ini.
          onPressed: pilihan == null
              ? null
              : () => Navigator.pop(context, pilihan),
          child: Text(t.adminUsersExtendConfirm),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Token
// ---------------------------------------------------------------------------

/// Dialog tambah/kurangi token satu pelanggan (Bab 11.2).
///
/// 🔴 Tiga hal yang wajib terbaca sebelum tombolnya ditekan, dan ketiganya ada
/// di layar ini: saldo sesudahnya, kapan bonusnya hangus, dan alasan yang
/// sedang ditulis. Penyesuaian token adalah satu-satunya aksi admin yang
/// akibatnya berupa angka — dan angka yang salah baru ketahuan saat pelanggan
/// mengeluh kehabisan token di tengah packing.
class _DialogToken extends StatefulWidget {
  const _DialogToken({required this.baris});

  final AdminTenantRow baris;

  /// Jumlah siap pakai. 81 ada di sini karena pemberian bertema seperti
  /// "HUT RI ke-81" adalah alasan fitur ini dibangun.
  static const List<int> pilihanCepat = [10, 50, 81, 100];

  @override
  State<_DialogToken> createState() => _DialogTokenState();
}

class _DialogTokenState extends State<_DialogToken> {
  final TextEditingController _jumlah = TextEditingController();
  final TextEditingController _alasan = TextEditingController();

  /// true = menambah, false = mengurangi.
  bool _tambah = true;

  @override
  void dispose() {
    _jumlah.dispose();
    _alasan.dispose();
    super.dispose();
  }

  int get _angka => int.tryParse(_jumlah.text.trim()) ?? 0;
  int get _delta => _tambah ? _angka : -_angka;

  /// Saldo sesudahnya, dijepit di nol persis seperti server melakukannya.
  int get _saldoBaru {
    final hasil = widget.baris.tokenBalance + _delta;
    return hasil < 0 ? 0 : hasil;
  }

  bool get _bolehSimpan => _angka > 0 && _alasan.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final baris = widget.baris;
    final hangus = baris.tokenExpiresAt;

    return AlertDialog(
      title: Text(t.adminUsersTokenTitle(baris.label)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.adminUsersTokenCurrent(Formatters.number(baris.tokenBalance)),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),

            // Tambah / kurangi. Dua chip, bukan tanda minus yang diketik di
            // kolom angka — tanda minus yang tidak sengaja terhapus mengubah
            // pengurangan menjadi penambahan tanpa satu pun peringatan.
            Row(
              children: [
                ChoiceChip(
                  label: Text(t.adminUsersTokenAdd),
                  selected: _tambah,
                  onSelected: (_) => setState(() => _tambah = true),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(t.adminUsersTokenSubtract),
                  selected: !_tambah,
                  onSelected: (_) => setState(() => _tambah = false),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _jumlah,
              autofocus: true,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: t.adminUsersTokenAmount,
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final n in _DialogToken.pilihanCepat)
                  ActionChip(
                    label: Text(Formatters.number(n)),
                    onPressed: () => setState(() => _jumlah.text = '$n'),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // 🔴 Alasan wajib (Bab 11.2), dan penjagaan sesungguhnya ada di
            // server. Kolom ini hanya membuat penolakannya terjadi sebelum
            // tombolnya ditekan, bukan sesudah.
            TextField(
              controller: _alasan,
              onChanged: (_) => setState(() {}),
              maxLength: 120,
              decoration: InputDecoration(
                labelText: t.adminUsersTokenReason,
                helperText: t.adminUsersTokenReasonHelp,
                // 🔴 `helperMaxLines` wajib. Bawaannya SATU baris, dan
                // kalimatnya dipotong menjadi "Wajib diisi. Tercatat per…" —
                // terlihat di layar Product Owner 29 Agustus 2026. Yang
                // hilang justru bagian yang menjelaskan kenapa alasannya
                // wajib, sehingga kolomnya terbaca sebagai kerewelan.
                helperMaxLines: 3,
                isDense: true,
              ),
            ),

            if (_angka > 0) ...[
              const SizedBox(height: 6),
              Text(
                t.adminUsersTokenPreview(
                  Formatters.number(baris.tokenBalance),
                  Formatters.number(_saldoBaru),
                ),
                style: theme.textTheme.titleSmall,
              ),
              if (!_tambah && baris.tokenBalance + _delta < 0) ...[
                const SizedBox(height: 6),
                // Server menjepit saldo di nol (`chk_balance_non_negative`),
                // dan buku besar mencatat selisih yang BENAR-BENAR terjadi.
                // Mengatakannya di sini mencegah Admin mengira pengurangannya
                // gagal separuh.
                _Catatan(teks: t.adminUsersTokenClamped),
              ],
              const SizedBox(height: 8),

              // ⚠️ Kapan bonusnya hangus. Tiga kalimat berbeda untuk tiga
              // keadaan berbeda — menggabungkannya membuat salah satunya
              // selalu bohong.
              //
              // 🔴 Sejak migrasi 40 pemicunya adalah **langganan berakhir**,
              // bukan reset bulanan; cron resetnya sudah dicabut. Kata
              // "reset" tidak boleh kembali ke ketiga kalimat ini.
              _Catatan(
                teks: switch ((hangus, baris.status)) {
                  (final DateTime d, _) => t.adminUsersTokenExpires(
                    Formatters.date(d),
                  ),
                  (null, TenantStatus.trial) => t.adminUsersTokenNeverExpires,
                  (null, _) => t.adminUsersTokenExpiresAfterActive,
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.commonCancel),
        ),
        FilledButton(
          onPressed: _bolehSimpan
              ? () => Navigator.pop(context, (
                  delta: _delta,
                  reason: _alasan.text.trim(),
                ))
              : null,
          child: Text(t.commonSave),
        ),
      ],
    );
  }
}

/// Dialog pemberian token serentak ke seluruh pelanggan aktif.
///
/// 🔴 Hanya menambah, dan hanya yang berstatus aktif — keputusan Product Owner
/// 29 Agustus 2026. Jumlah sasarannya ditulis di dialog **sebelum** ditekan,
/// karena ini satu-satunya tombol di aplikasi ini yang mengubah banyak
/// pelanggan sekaligus dan tidak punya pembatalan.
class _DialogTokenSerentak extends StatefulWidget {
  const _DialogTokenSerentak({required this.jumlahAktif});

  /// Berapa pelanggan berstatus aktif yang terlihat di tabel saat ini.
  final int jumlahAktif;

  @override
  State<_DialogTokenSerentak> createState() => _DialogTokenSerentakState();
}

class _DialogTokenSerentakState extends State<_DialogTokenSerentak> {
  final TextEditingController _jumlah = TextEditingController();
  final TextEditingController _alasan = TextEditingController();

  @override
  void dispose() {
    _jumlah.dispose();
    _alasan.dispose();
    super.dispose();
  }

  int get _angka => int.tryParse(_jumlah.text.trim()) ?? 0;
  bool get _bolehSimpan => _angka > 0 && _alasan.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(t.adminUsersGrantAllTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.adminUsersGrantAllBody(Formatters.number(widget.jumlahAktif)),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            // Dikatakan apa adanya siapa yang TIDAK kebagian, supaya tidak
            // ditemukan sendiri sesudahnya.
            _Catatan(teks: t.adminUsersGrantAllExcluded),
            const SizedBox(height: 14),

            TextField(
              controller: _jumlah,
              autofocus: true,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: t.adminUsersTokenAmount,
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final n in _DialogToken.pilihanCepat)
                  ActionChip(
                    label: Text(Formatters.number(n)),
                    onPressed: () => setState(() => _jumlah.text = '$n'),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _alasan,
              onChanged: (_) => setState(() {}),
              maxLength: 120,
              decoration: InputDecoration(
                labelText: t.adminUsersTokenReason,
                helperText: t.adminUsersGrantAllReasonHelp,
                helperMaxLines: 3,
                isDense: true,
              ),
            ),
            const SizedBox(height: 6),
            _Catatan(teks: t.adminUsersGrantAllExpires),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.commonCancel),
        ),
        FilledButton(
          onPressed: _bolehSimpan
              ? () => Navigator.pop(context, (
                  delta: _angka,
                  reason: _alasan.text.trim(),
                ))
              : null,
          child: Text(t.adminUsersGrantAllConfirm),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Potongan kecil
// ---------------------------------------------------------------------------

class _JudulBagian extends StatelessWidget {
  const _JudulBagian(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        teks,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _Keterangan extends StatelessWidget {
  const _Keterangan({
    required this.label,
    required this.value,
    this.note,
    this.noteColor,
  });

  final String label;
  final String value;
  final String? note;
  final Color? noteColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final keterangan = note;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 🔴 `Flexible`, bukan lebar tetap. Nama bulan dalam bahasa
              // Indonesia panjang ("September"), dan tanggal penuh pada panel
              // 380 px sudah mepet.
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          if (keterangan != null) ...[
            const SizedBox(height: 2),
            Text(
              keterangan,
              style: theme.textTheme.bodySmall?.copyWith(
                color: noteColor ?? scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kotak catatan berikon di dalam dialog.
///
/// Dipakai untuk kalimat yang **wajib terbaca sebelum menekan** — bukan
/// hiasan. Ikonnya ada supaya matanya berhenti di situ.
class _Catatan extends StatelessWidget {
  const _Catatan({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            teks,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
