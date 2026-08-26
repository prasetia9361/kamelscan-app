import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/history_item.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/repositories/video_repository.dart';
import '../../../core/utils/app_failure.dart';

part 'web_history_view_model.g.dart';

/// Isi tabel Riwayat versi web (Bab 10.5).
///
/// Berbeda dari [HistoryData] milik HP dalam satu hal yang menentukan: ia
/// menyimpan **satu halaman**, bukan tumpukan halaman. Tabel yang punya nomor
/// halaman tidak boleh menumpuk — melompat ke halaman 7 lalu kembali ke
/// halaman 2 harus menampilkan baris halaman 2, bukan gabungan keduanya.
class WebHistoryData {
  const WebHistoryData({
    required this.items,
    required this.total,
    required this.page,
    required this.filter,
    required this.sort,
    required this.ascending,
    this.pageSize = AppConstants.webHistoryPageSize,
    this.selectedId,
  });

  final List<HistoryItem> items;

  /// Jumlah baris yang cocok dengan filternya, seluruhnya.
  final int total;
  final int page;
  final int pageSize;
  final VideoFilter filter;
  final HistorySort sort;
  final bool ascending;

  /// Baris yang panel sampingnya sedang terbuka. null = panel tertutup.
  final String? selectedId;

  bool get isEmpty => items.isEmpty;

  /// Selalu minimal 1: tabel kosong tetap "halaman 1 dari 1", bukan
  /// "halaman 1 dari 0".
  int get pageCount => total <= 0 ? 1 : ((total - 1) ~/ pageSize) + 1;

  bool get hasPrevious => page > 0;
  bool get hasNext => page + 1 < pageCount;

  /// Nomor baris pertama dan terakhir yang sedang ditampilkan — untuk
  /// keterangan *"1–25 dari 431"*.
  int get firstRow => total == 0 ? 0 : page * pageSize + 1;
  int get lastRow {
    final akhir = (page + 1) * pageSize;
    return akhir > total ? total : akhir;
  }

  WebHistoryData copyWith({
    List<HistoryItem>? items,
    int? total,
    int? page,
    VideoFilter? filter,
    HistorySort? sort,
    bool? ascending,
    String? selectedId,
    bool clearSelection = false,
  }) =>
      WebHistoryData(
        items: items ?? this.items,
        total: total ?? this.total,
        page: page ?? this.page,
        pageSize: pageSize,
        filter: filter ?? this.filter,
        sort: sort ?? this.sort,
        ascending: ascending ?? this.ascending,
        selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
      );
}

/// Tabel Riwayat web: urut, saring, halaman bernomor, panel samping
/// (Bab 10.5).
@riverpod
class WebHistoryViewModel extends _$WebHistoryViewModel {
  Timer? _searchDebounce;

  @override
  Future<WebHistoryData> build(String typeWire) async {
    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;

    ref.onDispose(() => _searchDebounce?.cancel());

    return _load(
      filter: VideoFilter(type: _typeFromWire(typeWire)),
      page: 0,
      sort: HistorySort.date,
      ascending: false,
    );
  }

  static VideoType? _typeFromWire(String wire) => switch (wire) {
        'packing' => VideoType.packing,
        'return' => VideoType.returned,
        _ => null,
      };

  Future<WebHistoryData> _load({
    required VideoFilter filter,
    required int page,
    required HistorySort sort,
    required bool ascending,
    String? selectedId,
  }) async {
    debugPrint('KAMELSCAN_TABEL muat · halaman $page urut=${sort.name} '
        'naik=$ascending');

    final hasil = await ref.read(videoRepositoryProvider).fetchHistoryPage(
          filter: filter,
          page: page,
          sort: sort,
          ascending: ascending,
        );

    debugPrint('KAMELSCAN_TABEL '
        '${hasil.isOk ? 'OK · ${hasil.valueOrNull?.items.length} baris dari ${hasil.valueOrNull?.total}' : 'GAGAL · ${hasil.failureOrNull}'}');

    final halaman = hasil.unwrap();
    return WebHistoryData(
      items: halaman.items,
      total: halaman.total,
      page: page,
      filter: filter,
      sort: sort,
      ascending: ascending,
      selectedId: selectedId,
    );
  }

  /// Memuat ulang dengan keadaan yang sudah ada, mengganti apa yang disebut.
  ///
  /// 🔴 Kegagalannya sengaja **membuang** tabel yang sedang tampil, berbeda
  /// dari `loadMore` di HP. Di sana baris yang sudah terbaca masih benar; di
  /// sini pengguna baru saja menekan "urutkan menurut resi", dan tabel lama
  /// yang tetap berdiri akan terbaca seolah permintaannya sudah dikerjakan.
  Future<void> _reload({
    VideoFilter? filter,
    int? page,
    HistorySort? sort,
    bool? ascending,
    bool keepSelection = true,
  }) async {
    final sekarang = state.value;
    if (sekarang == null) return;

    state = await AsyncValue.guard(
      () => _load(
        filter: filter ?? sekarang.filter,
        page: page ?? sekarang.page,
        sort: sort ?? sekarang.sort,
        ascending: ascending ?? sekarang.ascending,
        selectedId: keepSelection ? sekarang.selectedId : null,
      ),
    );
  }

  Future<void> refresh() => _reload();

  /// Menekan judul kolom: kolom yang sama membalik arah, kolom lain mulai dari
  /// arah yang paling berguna untuknya.
  Future<void> sortBy(HistorySort kolom) async {
    final sekarang = state.value;
    if (sekarang == null) return;

    final sama = sekarang.sort == kolom;
    // Tanggal dimulai dari yang terbaru — itu yang dicari orang saat membuka
    // Riwayat. Kolom teks dimulai dari A ke Z.
    final naik = sama ? !sekarang.ascending : kolom != HistorySort.date;

    // 🔴 Kembali ke halaman 1. Mengurutkan ulang sambil bertahan di halaman 7
    // menampilkan baris yang sama sekali berbeda tanpa penjelasan — pengguna
    // menekan "urutkan menurut resi" dan mendarat di tengah-tengah daftar.
    await _reload(sort: kolom, ascending: naik, page: 0);
  }

  Future<void> goToPage(int halaman) async {
    final sekarang = state.value;
    if (sekarang == null) return;
    if (halaman < 0 || halaman >= sekarang.pageCount) return;
    if (halaman == sekarang.page) return;
    await _reload(page: halaman);
  }

  Future<void> nextPage() async {
    final sekarang = state.value;
    if (sekarang != null && sekarang.hasNext) await goToPage(sekarang.page + 1);
  }

  Future<void> previousPage() async {
    final sekarang = state.value;
    if (sekarang != null && sekarang.hasPrevious) {
      await goToPage(sekarang.page - 1);
    }
  }

  /// Pencarian nomor resi, dengan jeda supaya tiap huruf tidak jadi satu
  /// permintaan.
  void search(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(AppConstants.searchDebounce, () {
      final bersih = query.trim();
      _ubahFilter(gantiResi: true, resiQuery: bersih.isEmpty ? null : bersih);
    });
  }

  void selectType(VideoType? tipe) =>
      _ubahFilter(gantiType: true, type: tipe);

  void selectStatus(VideoStatus? status) =>
      _ubahFilter(gantiStatus: true, status: status);

  void clearFilters() => _applyFilter(const VideoFilter());

  /// Satu-satunya tempat [VideoFilter] baru dirakit di berkas ini.
  ///
  /// 🔴 [VideoFilter] sengaja tidak punya `copyWith`: tiga field-nya bermakna
  /// **"semua"** saat null (`type`, `status`, `shopId`), dan `copyWith` yang
  /// lazim tidak dapat membedakan "biarkan apa adanya" dari "kosongkan" —
  /// filter yang dihapus pengguna akan diam-diam bertahan.
  ///
  /// Karena itu ketujuh field ditulis di sini saja. Bila kelak ada field baru,
  /// yang lupa menyalinnya cukup satu tempat, bukan tiga — dan field yang
  /// terlupa **tidak menimbulkan galat**, ia hanya membuat penyaringan diam
  /// saja mengabaikan salah satu pilihan pengguna.
  void _ubahFilter({
    String? resiQuery,
    VideoType? type,
    VideoStatus? status,
    bool gantiResi = false,
    bool gantiType = false,
    bool gantiStatus = false,
  }) {
    final f = state.value?.filter;
    if (f == null) return;
    _applyFilter(VideoFilter(
      resiQuery: gantiResi ? resiQuery : f.resiQuery,
      shopId: f.shopId,
      type: gantiType ? type : f.type,
      status: gantiStatus ? status : f.status,
      userId: f.userId,
      from: f.from,
      to: f.to,
    ));
  }

  /// Filter apa pun yang berubah selalu mengembalikan ke halaman 1.
  ///
  /// Tanpa ini, menyaring dari 431 baris menjadi 12 sambil bertahan di halaman
  /// 7 menghasilkan tabel kosong — dan yang melihatnya akan menyimpulkan
  /// pencariannya tidak menemukan apa-apa.
  void _applyFilter(VideoFilter filter) {
    unawaited(_reload(filter: filter, page: 0, keepSelection: false));
  }

  /// Membuka panel samping untuk satu baris. [id] null menutupnya.
  void select(String? id) {
    final sekarang = state.value;
    if (sekarang == null) return;
    state = AsyncData(
      id == null
          ? sekarang.copyWith(clearSelection: true)
          : sekarang.copyWith(selectedId: id),
    );
  }
}
