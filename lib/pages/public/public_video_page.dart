import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_constants.dart';
import '../../core/models/enums.dart';
import '../../core/models/public_video.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_state_views.dart';
import '../../core/widgets/failure_messages.dart';
import '../history/detail/widgets/video_player_box.dart';

/// Halaman bukti publik `/v/{token}` (Bab 10.6).
///
/// 🔴 Dibuka **tanpa login**, biasanya oleh pusat resolusi marketplace. Karena
/// itu ia sengaja tidak memakai kerangka aplikasi: tidak ada menu bawah, tidak
/// ada tombol yang menuntun ke bagian ber-sesi, dan tidak ada satu pun tautan
/// yang membocorkan siapa pelanggannya.
class PublicVideoPage extends ConsumerStatefulWidget {
  const PublicVideoPage({super.key, required this.token});

  final String token;

  @override
  ConsumerState<PublicVideoPage> createState() => _PublicVideoPageState();
}

class _PublicVideoPageState extends ConsumerState<PublicVideoPage> {
  late final Future<PublicVideo> _future = _muat();

  Future<PublicVideo> _muat() async =>
      (await ref.read(videoRepositoryProvider).fetchPublicVideo(widget.token))
          .unwrap();

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(t.publicVideoTitle)),
      body: FutureBuilder<PublicVideo>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppListSkeleton(itemCount: 3);
          }
          if (snapshot.hasError) {
            // Tautan mati adalah keadaan yang **wajar** di sini, bukan
            // kerusakan: masa berlakunya mengikuti masa simpan video. Karena
            // itu ia dijelaskan dengan kalimat sendiri, bukan pesan error umum.
            return AppEmptyState(
              icon: Icons.link_off_rounded,
              title: t.publicVideoUnavailableTitle,
              message: t.publicVideoUnavailableBody,
            );
          }
          return _Isi(video: snapshot.data!);
        },
      ),
    );
  }
}

class _Isi extends StatefulWidget {
  const _Isi({required this.video});

  final PublicVideo video;

  @override
  State<_Isi> createState() => _IsiState();
}

class _IsiState extends State<_Isi> {
  bool _putar = false;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final v = widget.video;
    final sisaHari = v.daysUntilLinkExpiry();

    return Center(
      child: ConstrainedBox(
        // Halaman ini paling sering dibuka di layar lebar (petugas marketplace
        // memakai komputer), jadi lebarnya dibatasi agar barisnya tetap enak
        // dibaca alih-alih melebar sepanjang layar.
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            VideoPlayerBox(
              url: _putar ? v.url : null,
              loading: false,
              enabled: true,
              onPlay: () async => setState(() => _putar = true),
            ),
            const SizedBox(height: 16),

            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.publicVideoHeading,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),

                    _Baris(
                      label: t.fieldResi,
                      child: SelectableText(
                        v.resiCode,
                        textAlign: TextAlign.right,
                        style: AppTextStyles.resiInline
                            .copyWith(color: theme.colorScheme.onSurface),
                      ),
                    ),
                    _Baris(
                      label: t.fieldType,
                      value: v.type == VideoType.packing
                          ? t.videoTypePacking
                          : t.videoTypeReturn,
                    ),
                    if (v.shopLabel.isNotEmpty)
                      _Baris(label: t.fieldShop, value: v.shopLabel),
                    _Baris(
                      label: t.fieldDate,
                      value: Formatters.date(v.scanDate),
                    ),
                    _Baris(
                      label: t.fieldTime,
                      value: Formatters.time(v.scanDate),
                    ),
                    _Baris(
                      label: t.fieldDuration,
                      value: Formatters.durationFromSeconds(v.durationSeconds),
                    ),
                    if (v.hasLocation)
                      _Baris(
                        label: t.fieldLocation,
                        child: SelectableText(
                          Formatters.coordinates(
                                v.locationLat,
                                v.locationLng,
                              ) ??
                              '',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),

                    // L.2 — penanda yang sama juga terbakar di gambar videonya.
                    // Menyembunyikannya di halaman ini akan membuat pembacanya
                    // menemukan keterangan itu di video tetapi tidak di
                    // metadatanya, dan curiga ada yang ditutupi.
                    if (!v.timeVerified) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: colors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.publicVideoTimeUnverified,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 🔴 Bab 9.4 mewajibkan sisa masa berlaku tautan tampil di sini:
            // pusat resolusi marketplace kadang baru membuka tautannya
            // beberapa hari kemudian, dan perlu tahu berapa lama lagi buktinya
            // dapat diakses sebelum meminta salinan.
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: sisaHari <= 3 ? colors.danger : colors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sisaHari < 0
                        ? t.publicVideoLinkExpired
                        : t.publicVideoLinkValid(
                            Formatters.date(v.linkExpiresAt),
                          ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Center(
              child: Text(
                AppConstants.appName,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({required this.label, this.value, this.child});

  final String label;
  final String? value;
  final Widget? child;

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
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
          ),
        ],
      ),
    );
  }
}
