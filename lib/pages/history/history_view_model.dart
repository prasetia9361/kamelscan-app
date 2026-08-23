import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/config/app_constants.dart';
import '../../core/models/enums.dart';
import '../../core/models/history_item.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/upload_queue_provider.dart';
import '../../core/repositories/video_repository.dart';
import '../../core/utils/app_failure.dart';

part 'history_view_model.g.dart';

/// Isi layar Riwayat (Bab 9.4).
class HistoryData {
  const HistoryData({
    required this.items,
    required this.filter,
    this.loadingMore = false,
    this.reachedEnd = false,
  });

  final List<HistoryItem> items;
  final VideoFilter filter;

  /// Halaman berikutnya sedang diambil — dipakai untuk indikator di dasar
  /// daftar, bukan untuk menutupi daftar yang sudah tampil.
  final bool loadingMore;

  /// Server sudah kehabisan baris. Tanpa penanda ini, gulir sampai dasar akan
  /// terus memanggil server dan selalu menerima daftar kosong.
  final bool reachedEnd;

  bool get isEmpty => items.isEmpty;

  HistoryData copyWith({
    List<HistoryItem>? items,
    VideoFilter? filter,
    bool? loadingMore,
    bool? reachedEnd,
  }) =>
      HistoryData(
        items: items ?? this.items,
        filter: filter ?? this.filter,
        loadingMore: loadingMore ?? this.loadingMore,
        reachedEnd: reachedEnd ?? this.reachedEnd,
      );
}

/// Daftar Riwayat: pencarian, penyaringan, dan paginasi (Bab 9.4).
///
/// 🔴 **Tidak pernah memuat seluruh riwayat sekaligus.** Satu tenant aktif bisa
/// memiliki puluhan ribu baris; mengambil semuanya akan menghabiskan memori
/// perangkat dan kuota data packer sekaligus.
///
/// [typeWire] menyimpan filter tipe yang dibawa dari kartu Beranda, sehingga
/// menekan kartu "Video Return" membuka Riwayat yang sudah tersaring. Ia
/// menjadi parameter provider — bukan state di dalamnya — agar dua tautan
/// berbeda tidak berebut satu daftar yang sama.
@riverpod
class HistoryViewModel extends _$HistoryViewModel {
  int _page = 0;
  Timer? _searchDebounce;

  @override
  Future<HistoryData> build(String typeWire) async {
    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;


    // Video yang baru selesai terkirim harus muncul tanpa pengguna menarik
    // daftarnya — alasan yang sama dengan jaring pengaman di Beranda.
    ref.listen(pendingUploadCountProvider, (previous, next) {
      final before = previous?.value;
      final after = next.value;
      if (before == null || after == null || after >= before) return;
      debugPrint('KAMELSCAN_RIWAYAT antrian $before → $after · menyegarkan');
      unawaited(refresh());
    });

    ref.onDispose(() => _searchDebounce?.cancel());


    final filter = VideoFilter(type: _typeFromWire(typeWire));
    return _loadFirstPage(filter);
  }

  /// `semua` bukan nilai `VideoType`; ia berarti tanpa penyaringan tipe.
  static VideoType? _typeFromWire(String wire) => switch (wire) {
        'packing' => VideoType.packing,
        'return' => VideoType.returned,
        _ => null,
      };

  Future<HistoryData> _loadFirstPage(VideoFilter filter) async {
    _page = 0;
    final items = (await ref
            .read(videoRepositoryProvider)
            .fetchHistory(filter: filter, page: 0))
        .unwrap();

    return HistoryData(
      items: items,
      filter: filter,
      reachedEnd: items.length < AppConstants.historyPageSize,
    );
  }

  /// Muat ulang dari halaman pertama — dipakai tarik-ke-bawah dan setiap kali
  /// filternya berubah.
  Future<void> refresh() async {
    final filter = state.value?.filter ?? const VideoFilter();
    state = await AsyncValue.guard(() => _loadFirstPage(filter));
  }

  /// Halaman berikutnya (Bab 9.4 — 20 item, gulir tak berujung).
  ///
  /// Kegagalan di sini sengaja **tidak** membuang daftar yang sudah tampil:
  /// pengguna yang sedang membaca baris ke-18 tidak boleh kehilangan semuanya
  /// hanya karena sinyal putus saat mengambil baris ke-21.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore || current.reachedEnd) return;

    state = AsyncData(current.copyWith(loadingMore: true));

    final result = await ref.read(videoRepositoryProvider).fetchHistory(
          filter: current.filter,
          page: _page + 1,
        );

    result.fold(
      onOk: (items) {
        _page += 1;
        state = AsyncData(
          current.copyWith(
            items: [...current.items, ...items],
            loadingMore: false,
            reachedEnd: items.length < AppConstants.historyPageSize,
          ),
        );
      },
      onErr: (failure) {
        debugPrint('KAMELSCAN_RIWAYAT halaman berikutnya GAGAL · $failure');
        state = AsyncData(current.copyWith(loadingMore: false));
      },
    );
  }

  /// Bab 9.4 — pencarian resi dengan jeda ketik dan minimal 3 karakter.
  ///
  /// Jeda dan batas minimal itu bukan penghematan yang manis-manis saja:
  /// mencari satu huruf pada tabel berisi puluhan ribu resi memaksa server
  /// memindai hampir seluruhnya, dan hasilnya toh tidak berguna bagi
  /// penggunanya.
  void search(String query) {
    _searchDebounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.isNotEmpty && trimmed.length < 3) return;

    _searchDebounce = Timer(AppConstants.searchDebounce, () {
      final current = state.value;
      if (current == null) return;
      _applyFilter(
        VideoFilter(
          resiQuery: trimmed.isEmpty ? null : trimmed,
          type: current.filter.type,
          shopId: current.filter.shopId,
          userId: current.filter.userId,
          status: current.filter.status,
          from: current.filter.from,
          to: current.filter.to,
        ),
      );
    });
  }

  /// Chip `Semua · Packing · Return`.
  void selectType(VideoType? type) {
    final current = state.value;
    if (current == null || current.filter.type == type) return;
    _applyFilter(
      VideoFilter(
        resiQuery: current.filter.resiQuery,
        type: type,
        shopId: current.filter.shopId,
        userId: current.filter.userId,
        status: current.filter.status,
        from: current.filter.from,
        to: current.filter.to,
      ),
    );
  }

  /// Filter lanjutan dari lembar bawah (toko, packer, status, rentang tanggal).
  void applyAdvanced(VideoFilter filter) => _applyFilter(filter);

  Future<void> _applyFilter(VideoFilter filter) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadFirstPage(filter));
  }
}
