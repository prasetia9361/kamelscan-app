import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/enums.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import '../widgets/video_status_chip.dart';
import 'video_detail_view_model.dart';
import 'widgets/video_player_box.dart';

/// Detail satu rekaman (Bab 9.4, beserta utang Bab 8.8).
///
/// Susunannya mengikuti acuan Product Owner 18 Agustus 2026: pemutar di atas,
/// tombol unduh, kartu metadata berpasangan label–nilai, lalu tombol hapus.
class VideoDetailPage extends ConsumerStatefulWidget {
  const VideoDetailPage({
    super.key,
    required this.videoId,
    this.embedded = false,
    this.onClose,
  });

  final String videoId;

  /// Dipasang di dalam panel samping tabel Riwayat web (Bab 10.5), bukan
  /// sebagai halaman tersendiri.
  ///
  /// 🔴 Bila `true`, bilah judulnya dilepas — panelnya sudah punya judul dan
  /// tombol tutup sendiri, dan dua bilah judul bertumpuk terbaca seperti dua
  /// halaman yang saling menimpa.
  final bool embedded;

  /// Dipanggil setelah videonya dihapus saat [embedded].
  ///
  /// 🔴 Wajib ada. Sebagai halaman, penghapusan diakhiri `Navigator.pop()`;
  /// di dalam panel tidak ada apa pun untuk di-*pop*, dan memanggilnya akan
  /// melempar pengguna keluar dari seluruh cabang Riwayat.
  final VoidCallback? onClose;

  @override
  ConsumerState<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends ConsumerState<VideoDetailPage> {
  double? _unduhProgres;

  VideoDetailViewModel get _vm =>
      ref.read(videoDetailViewModelProvider(widget.videoId).notifier);

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final async = ref.watch(videoDetailViewModelProvider(widget.videoId));

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: Text(t.videoDetailTitle)),
      body: switch (async) {
        AsyncValue(:final value?) => _Body(
            data: value,
            unduhProgres: _unduhProgres,
            onTonton: _vm.loadPlaybackUrl,
            onUnduh: _unduh,
            onTautan: _buatTautan,
            onHapus: _konfirmasiHapus,
          ),
        AsyncError(:final error) => AppErrorView(
            failure: error,
            onRetry: () => ref.invalidate(
              videoDetailViewModelProvider(widget.videoId),
            ),
          ),
        _ => const AppListSkeleton(itemCount: 4),
      },
    );
  }

  /// Unduh lalu langsung tawarkan bagikan.
  ///
  /// Berkasnya disimpan di direktori dokumen aplikasi, **bukan** folder Unduhan
  /// bersama — menulis ke sana pada Android modern menuntut izin penyimpanan
  /// yang harus diminta ke pengguna, dan hampir semua pemakaian nyatanya adalah
  /// meneruskan berkas itu ke pusat resolusi marketplace lewat aplikasi pesan.
  /// Lembar Bagikan menempuh kebutuhan itu langsung, tanpa izin tambahan.
  Future<void> _unduh() async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final data = ref.read(videoDetailViewModelProvider(widget.videoId)).value;
    if (data == null) return;

    setState(() => _unduhProgres = 0);

    final url = await _vm.downloadUrl();
    if (url == null) {
      if (!mounted) return;
      setState(() => _unduhProgres = null);
      messenger.showSnackBar(SnackBar(content: Text(t.videoDetailDownloadFailed)));
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      // Nama berkas memakai nomor resi supaya penerimanya langsung tahu ini
      // bukti paket yang mana; karakter yang tidak sah untuk nama berkas
      // dibuang karena resi marketplace kadang memuat tanda kurung.
      final aman = data.item.video.resiCode.replaceAll(RegExp(r'[^\w.-]'), '_');
      final path = '${dir.path}/$aman.mp4';

      await Dio().download(
        url,
        path,
        onReceiveProgress: (diterima, total) {
          if (!mounted || total <= 0) return;
          setState(() => _unduhProgres = diterima / total);
        },
      );

      if (!mounted) return;
      setState(() => _unduhProgres = null);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: t.videoDetailShareText(data.item.video.resiCode),
        ),
      );
    } on Object {
      if (!mounted) return;
      setState(() => _unduhProgres = null);
      messenger.showSnackBar(SnackBar(content: Text(t.videoDetailDownloadFailed)));
    }
  }

  /// Terbitkan tautan publik, salin ke papan klip, dan sebutkan masa
  /// berlakunya (Bab 9.4).
  ///
  /// Masa berlaku disebut di snackbar, bukan disembunyikan: pusat resolusi
  /// marketplace kadang baru membuka tautannya beberapa hari kemudian, dan
  /// Owner perlu tahu sampai kapan tautannya hidup **sebelum** mengirimkannya.
  Future<void> _buatTautan() async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final result = await _vm.createPublicLink();
    if (!mounted) return;

    result.fold(
      onOk: (link) async {
        await Clipboard.setData(ClipboardData(text: link.url));
        if (!mounted) return;

        final sampai = link.expiresAt;
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Text(
              sampai == null
                  ? t.videoDetailLinkCopied
                  : t.videoDetailLinkCopiedUntil(Formatters.date(sampai)),
            ),
            action: SnackBarAction(
              label: t.commonShare,
              onPressed: () => SharePlus.instance.share(
                ShareParams(text: link.url),
              ),
            ),
          ),
        );
      },
      onErr: (failure) => messenger.showSnackBar(
        SnackBar(content: Text(context.failureMessage(failure))),
      ),
    );
  }

  Future<void> _konfirmasiHapus() async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.videoDetailDeleteTitle),
        content: Text(t.videoDetailDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(t.commonDelete),
          ),
        ],
      ),
    );

    if (yakin != true) return;

    final failure = await _vm.delete();
    if (!mounted) return;

    if (failure != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.failureMessage(failure))),
      );
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(t.videoDetailDeleted)));

    // Di dalam panel samping tidak ada halaman untuk ditutup — yang harus
    // ditutup adalah panelnya, dan hanya pemiliknya yang tahu caranya.
    if (widget.embedded) {
      widget.onClose?.call();
      return;
    }
    navigator.pop();
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.data,
    required this.unduhProgres,
    required this.onTonton,
    required this.onUnduh,
    required this.onTautan,
    required this.onHapus,
  });

  final VideoDetailData data;
  final double? unduhProgres;
  final Future<void> Function() onTonton;
  final Future<void> Function() onUnduh;
  final Future<void> Function() onTautan;
  final Future<void> Function() onHapus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final session = ref.watch(sessionProvider).value;
    final item = data.item;
    final video = item.video;

    final adaBerkas = video.status == VideoStatus.uploaded;
    final sisaHari = video.daysUntilExpiry();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        VideoPlayerBox(
          url: data.playbackUrl,
          loading: data.loadingUrl,
          enabled: adaBerkas,
          disabledReason: _alasanTakBisaDiputar(context, video.status),
          onPlay: onTonton,
        ),

        if (data.urlFailure != null) ...[
          const SizedBox(height: 10),
          Text(
            context.failureMessage(data.urlFailure!),
            style: theme.textTheme.bodySmall?.copyWith(color: colors.danger),
          ),
        ],

        const SizedBox(height: 12),
        if (unduhProgres != null)
          Column(
            children: [
              LinearProgressIndicator(value: unduhProgres),
              const SizedBox(height: 6),
              Text(
                t.videoDetailDownloading,
                style: theme.textTheme.bodySmall,
              ),
            ],
          )
        else
          // Dua tombol berdampingan — diminta Product Owner 19 Agustus 2026.
          // Unduh dipendekkan agar tautan publik mendapat tempat di kanannya.
          //
          // Tautan publik hanya untuk Owner (Bab 2.2): membagikan bukti keluar
          // dari tenant adalah keputusan pemilik usaha, bukan packer yang
          // merekamnya. Bagi packer, tombol Unduh kembali memakai lebar penuh
          // supaya tidak ada ruang kosong yang tidak dapat dijelaskan.
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: adaBerkas ? onUnduh : null,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(t.videoDetailDownload),
                  ),
                ),
              ),
              if (session?.isOwner ?? false) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: adaBerkas ? onTautan : null,
                      icon: const Icon(Icons.link_rounded),
                      label: Text(t.videoDetailPublicLink),
                    ),
                  ),
                ),
              ],
            ],
          ),

        const SizedBox(height: 20),

        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VideoStatusChip(status: video.status),
                const SizedBox(height: 14),

                _Baris(
                  label: t.fieldResi,
                  child: SelectableText(
                    video.resiCode,
                    textAlign: TextAlign.right,
                    style: AppTextStyles.resiInline
                        .copyWith(color: theme.colorScheme.onSurface),
                  ),
                ),
                _Baris(
                  label: t.fieldType,
                  value: video.type == VideoType.packing
                      ? t.videoTypePacking
                      : t.videoTypeReturn,
                  valueColor: video.type == VideoType.packing
                      ? colors.packing
                      : colors.returnColor,
                ),
                if ((item.shopName ?? '').isNotEmpty)
                  _Baris(label: t.fieldShop, value: item.shopName!),
                if ((item.marketName ?? '').isNotEmpty)
                  _Baris(label: t.fieldMarketplace, value: item.marketName!),
                _Baris(
                  label: t.fieldDate,
                  value: Formatters.date(video.scanDate),
                ),
                _Baris(
                  label: t.fieldTime,
                  value: Formatters.time(video.scanDate),
                ),
                _Baris(
                  label: t.fieldDuration,
                  value: Formatters.durationFromSeconds(video.durationSeconds),
                ),
                if (video.fileSizeBytes != null)
                  _Baris(
                    label: t.fieldSize,
                    value: Formatters.fileSize(video.fileSizeBytes!),
                  ),
                if ((item.recorderName ?? '').isNotEmpty)
                  _Baris(label: t.fieldRecordedBy, value: item.recorderName!),

                // Bab 1.3 poin 6 — izin lokasi boleh ditolak dan videonya tetap
                // sah. Barisnya tetap ditampilkan supaya pembaca tahu GPS-nya
                // memang tidak ada, bukan lupa ditulis.
                _Baris(
                  label: t.fieldGps,
                  value: video.hasLocation
                      ? t.fieldGpsAvailable
                      : t.locationUnavailable,
                  valueColor:
                      video.hasLocation ? colors.success : theme.colorScheme.outline,
                ),
                if (video.hasLocation)
                  _Baris(
                    label: t.fieldLocation,
                    child: SelectableText(
                      Formatters.coordinates(
                            video.locationLat,
                            video.locationLng,
                          ) ??
                          '',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),

                // 🔴 Bab 9.4 — sisa retensi WAJIB tampil. Pelanggan yang tidak
                // tahu videonya akan terhapus tidak akan pernah menyimpan
                // salinannya, dan baru menyadarinya saat sengketa terjadi.
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(
                      Icons.auto_delete_outlined,
                      size: 18,
                      color: sisaHari <= 3 ? colors.danger : colors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sisaHari < 0
                            ? t.retentionPassed
                            : t.retentionCountdown(sisaHari),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Bab 9.4 — menghapus hanya hak Owner.
        if (session?.isOwner ?? false)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: onHapus,
              icon: Icon(Icons.delete_outline_rounded, color: colors.danger),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.danger,
                side: BorderSide(color: colors.danger.withValues(alpha: 0.6)),
              ),
              label: Text(t.videoDetailDelete),
            ),
          ),
      ],
    );
  }

  /// Kenapa videonya tidak dapat diputar — dibedakan supaya pengguna tahu
  /// apakah harus menunggu, mencoba lagi, atau memang sudah tidak ada.
  String? _alasanTakBisaDiputar(BuildContext context, VideoStatus status) {
    final t = context.l10n;
    return switch (status) {
      VideoStatus.uploaded => null,
      VideoStatus.expired => t.videoDetailExpiredNote,
      VideoStatus.failed => t.videoDetailFailedNote,
      _ => t.videoDetailNotUploadedNote,
    };
  }
}

/// Satu pasangan label–nilai pada kartu metadata.
class _Baris extends StatelessWidget {
  const _Baris({
    required this.label,
    this.value,
    this.child,
    this.valueColor,
  });

  final String label;
  final String? value;
  final Widget? child;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: child ??
                Text(
                  value ?? '',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
