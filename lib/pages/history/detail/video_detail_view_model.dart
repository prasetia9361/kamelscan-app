import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/history_item.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/repositories/video_repository.dart';
import '../../../core/utils/app_failure.dart';
import '../../../core/utils/result.dart';

part 'video_detail_view_model.g.dart';

/// Isi halaman detail video (Bab 9.4 + utang Bab 8.8).
class VideoDetailData {
  const VideoDetailData({
    required this.item,
    this.playbackUrl,
    this.loadingUrl = false,
    this.urlFailure,
  });

  final HistoryItem item;

  /// URL bertanda tangan berumur 15 menit dari Edge Function `get-video-url`.
  /// `null` selama belum diminta, atau bila permintaannya gagal.
  final String? playbackUrl;

  final bool loadingUrl;

  /// Kegagalan mengambil URL disimpan **terpisah** dari kegagalan memuat
  /// metadata. Video yang tidak dapat diputar tetap harus menampilkan nomor
  /// resi, waktu, dan koordinatnya — itulah bagian yang dipakai saat sengketa,
  /// dan ia masih sah walau berkasnya tidak terjangkau.
  final AppFailure? urlFailure;

  VideoDetailData copyWith({
    HistoryItem? item,
    String? playbackUrl,
    bool? loadingUrl,
    AppFailure? urlFailure,
    bool clearFailure = false,
  }) =>
      VideoDetailData(
        item: item ?? this.item,
        playbackUrl: playbackUrl ?? this.playbackUrl,
        loadingUrl: loadingUrl ?? this.loadingUrl,
        urlFailure: clearFailure ? null : (urlFailure ?? this.urlFailure),
      );
}

@riverpod
class VideoDetailViewModel extends _$VideoDetailViewModel {
  @override
  Future<VideoDetailData> build(String videoId) async {
    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;

    final item =
        (await ref.read(videoRepositoryProvider).fetchHistoryItem(videoId))
            .unwrap();

    return VideoDetailData(item: item);
  }

  /// Minta URL pemutaran (Bab 8.8).
  ///
  /// 🔴 Tidak dipanggil otomatis saat halaman dibuka. Tiap panggilan menerbitkan
  /// presigned URL dan menarik berkas video dari R2 — di gudang yang hanya punya
  /// sinyal seluler, memutar video 1 MB tanpa diminta akan membakar kuota data
  /// packer setiap kali ia membuka detail hanya untuk membaca nomor resinya.
  Future<void> loadPlaybackUrl({bool forDownload = false}) async {
    final current = state.value;
    if (current == null || current.loadingUrl) return;

    state = AsyncData(current.copyWith(loadingUrl: true, clearFailure: true));

    final result = await ref
        .read(videoRepositoryProvider)
        .getPlaybackUrl(videoId, forDownload: forDownload);

    result.fold(
      onOk: (url) {
        debugPrint('KAMELSCAN_TONTON url diterima · unduh=$forDownload');
        state = AsyncData(
          current.copyWith(playbackUrl: url, loadingUrl: false),
        );
      },
      // Sesuai aturan L.9: jalur gagalnya ikut dicetak, bukan hanya yang
      // berhasil. Fungsi ini menolak dengan beberapa alasan yang sangat
      // berbeda (admin, langganan mati, berkas belum terunggah), dan tanpa
      // baris ini semuanya tampak sama dari layar.
      onErr: (failure) {
        debugPrint('KAMELSCAN_TONTON url GAGAL · $failure');
        state = AsyncData(
          current.copyWith(loadingUrl: false, urlFailure: failure),
        );
      },
    );
  }

  /// URL khusus unduh — berkasnya diberi nama bernomor resi oleh R2.
  ///
  /// Dikembalikan, bukan disimpan ke state: URL unduh tidak boleh menggantikan
  /// URL pemutaran yang sedang dipakai pemutar di layar.
  Future<String?> downloadUrl() async {
    final result = await ref
        .read(videoRepositoryProvider)
        .getPlaybackUrl(videoId, forDownload: true);

    return result.fold(
      onOk: (url) => url,
      onErr: (failure) {
        debugPrint('KAMELSCAN_TONTON url unduh GAGAL · $failure');
        return null;
      },
    );
  }

  /// Terbitkan (atau pakai ulang) tautan publik (Bab 8.8 — hanya Owner).
  Future<Result<PublicLink>> createPublicLink() async {
    final result =
        await ref.read(videoRepositoryProvider).createPublicLink(videoId);

    result.fold(
      onOk: (link) => debugPrint(
        'KAMELSCAN_TAUTAN dibuat · dipakai_ulang=${link.reused}',
      ),
      onErr: (failure) => debugPrint('KAMELSCAN_TAUTAN GAGAL · $failure'),
    );
    return result;
  }

  /// Hapus video (Bab 9.4 — hanya Owner).
  ///
  /// Soft delete: barisnya tetap ada dengan status `deleted`, dan itu yang
  /// membebaskan nomor resinya untuk direkam ulang (Bab 7.7).
  Future<AppFailure?> delete() async {
    final result =
        await ref.read(videoRepositoryProvider).deleteVideo(videoId);
    return result.failureOrNull;
  }
}
