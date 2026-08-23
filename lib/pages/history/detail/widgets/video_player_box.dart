import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/widgets/failure_messages.dart';

/// Kotak pemutar video pada halaman detail (Bab 9.4).
///
/// 🔴 Videonya **tidak** dimuat saat halaman dibuka. Selama [url] masih null,
/// yang tampil hanya bidang gelap dengan tombol putar.
///
/// Alasannya bukan penghematan yang manis-manis saja: packer membuka halaman
/// ini terutama untuk membaca nomor resi dan waktunya saat menjawab komplain,
/// dan di gudang yang hanya punya sinyal seluler, menarik berkas 1 MB tiap kali
/// halaman dibuka akan membakar kuota data mereka tanpa pernah ditonton.
class VideoPlayerBox extends StatefulWidget {
  const VideoPlayerBox({
    super.key,
    required this.url,
    required this.loading,
    required this.enabled,
    required this.onPlay,
    this.disabledReason,
  });

  /// URL bertanda tangan berumur 15 menit. `null` selama belum diminta.
  final String? url;
  final bool loading;

  /// `false` bila berkasnya memang tidak ada — belum terunggah, gagal, atau
  /// sudah dihapus sesuai retensi.
  final bool enabled;
  final String? disabledReason;
  final Future<void> Function() onPlay;

  @override
  State<VideoPlayerBox> createState() => _VideoPlayerBoxState();
}

class _VideoPlayerBoxState extends State<VideoPlayerBox> {
  VideoPlayerController? _controller;
  ChewieController? _chewie;
  String? _urlTerpasang;

  @override
  void didUpdateWidget(VideoPlayerBox old) {
    super.didUpdateWidget(old);
    final url = widget.url;
    if (url != null && url != _urlTerpasang) _pasang(url);
  }

  Future<void> _pasang(String url) async {
    // URL lama dibuang lebih dulu. Presigned URL berumur 15 menit, jadi
    // membiarkan pemutar lama hidup berarti menahan sambungan ke berkas yang
    // sebentar lagi ditolak R2.
    await _buang();
    _urlTerpasang = url;

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _controller = controller;
      _chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        // Rasio diambil dari berkasnya sendiri. Video direkam portrait di
        // gudang, dan memaksa 16:9 akan menambahkan pita hitam besar di
        // kiri-kanan pada layar HP.
        aspectRatio: controller.value.aspectRatio,
      );
    });
  }

  Future<void> _buang() async {
    final chewie = _chewie;
    final controller = _controller;
    _chewie = null;
    _controller = null;
    chewie?.dispose();
    await controller?.dispose();
  }

  @override
  void dispose() {
    _buang();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final chewie = _chewie;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: chewie != null
            ? (_controller?.value.aspectRatio ?? 16 / 9)
            : 16 / 9,
        child: Container(
          color: Colors.black,
          child: chewie != null
              ? Chewie(controller: chewie)
              : Center(
                  child: widget.loading
                      ? const CircularProgressIndicator()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.filled(
                              iconSize: 36,
                              onPressed: widget.enabled ? widget.onPlay : null,
                              icon: const Icon(Icons.play_arrow_rounded),
                              tooltip: t.videoDetailWatch,
                            ),
                            if (widget.disabledReason != null) ...[
                              const SizedBox(height: 10),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  widget.disabledReason!,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: Colors.white70),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
        ),
      ),
    );
  }
}
