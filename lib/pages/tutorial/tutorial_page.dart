import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/tutorial.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles_display.dart';
import '../../core/widgets/app_state_views.dart';
import '../../core/widgets/failure_messages.dart';
import 'tutorial_view_model.dart';

/// Halaman Tutorial (Bab 9.9) — daftar bernomor, diketuk membuka YouTube.
///
/// 🔴 Bentuknya **tanpa gambar sampul**, keputusan Product Owner 3 September
/// 2026. Bab 9.9 menyebut thumbnail YouTube, dan itu sengaja tidak diikuti:
/// gambar sampul diambil dari server YouTube, sedangkan halaman ini paling
/// sering dibuka packer **di gudang bersinyal buruk** — tempat setiap gambar
/// yang gagal muat membuat daftarnya terlihat rusak padahal isinya lengkap.
///
/// Utang paling lama di proyek ini, dan penundaannya bukan kelupaan: isinya
/// bergantung pada video yang belum dibuat, dan halaman yang jadi lebih dulu
/// hanya akan menampilkan daftar kosong (keputusan 29 Agustus 2026).
///
/// ⚠️ Satu halaman untuk dua rangka. Di HP ia anak dari Beranda
/// (`/home/tutorial`), di web ia menu sidebar tersendiri (`/tutorial`) — lihat
/// `Routes.homeTutorial`. Yang membedakan isinya hanya kolom `platform` tiap
/// langkah.
class TutorialPage extends ConsumerWidget {
  const TutorialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;

    // `kIsWeb` dibaca DI SINI dan diteruskan sebagai nilai biasa. Di dalam
    // provider ia tidak dapat diuji sama sekali (O.14).
    final async = ref.watch(tutorialListProvider(isWeb: kIsWeb));

    return Scaffold(
      appBar: AppBar(title: Text(t.navTutorial)),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorView(
          failure: e,
          onRetry: () => ref.invalidate(tutorialListProvider(isWeb: kIsWeb)),
        ),
        data: (daftar) {
          // 🔴 Kondisi kosong bukan kegagalan, dan kalimatnya wajib
          // mengatakannya. Sampai channel YouTube-nya siap, INI keadaan yang
          // normal — pengguna yang membaca "terjadi kesalahan" di sini akan
          // mencoba lagi berkali-kali sesuatu yang memang belum ada.
          if (daftar.isEmpty) {
            return AppEmptyState(
              icon: Icons.ondemand_video_outlined,
              title: t.tutorialEmptyTitle,
              message: t.tutorialEmptyBody,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: daftar.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _KartuLangkah(
              tutorial: daftar[i],
              nomorTampil: i + 1,
            ),
          );
        },
      ),
    );
  }
}

/// Satu langkah: nomor, judul, deskripsi, ikon putar.
///
/// ⚠️ Nomor yang ditampilkan adalah **urutan dalam daftar**, bukan
/// `step_order`. Keduanya biasanya sama, tetapi `step_order` tidak unik dan
/// tidak dijamin rapat — Admin yang memberi nomor 10, 20, 30 supaya mudah
/// menyisipkan langkah di tengah tidak seharusnya membuat packer membaca
/// "Langkah 10" sebagai langkah pertama.
class _KartuLangkah extends StatelessWidget {
  const _KartuLangkah({required this.tutorial, required this.nomorTampil});

  final Tutorial tutorial;
  final int nomorTampil;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;
    final t = context.l10n;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _buka(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nomor langkah — penanda urutan, bukan hiasan.
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$nomorTampil',
                  style: AppDisplayStyles.metaMono.copyWith(
                    fontSize: 15,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 🔴 `Expanded`, bukan lebar tetap. Judul tutorial ditulis Admin
              // dan panjangnya tidak dapat diduga; tanpa ini teksnya meluber
              // ke ikon putar dan barisnya bergaris kuning-hitam (M.12).
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tutorial.title,
                      style: theme.textTheme.titleSmall,
                    ),
                    if ((tutorial.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        tutorial.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.play_circle_outline,
                          size: 17,
                          color: colors.danger,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          t.tutorialWatch,
                          style: AppDisplayStyles.kicker.copyWith(
                            color: colors.danger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  /// Membuka videonya di YouTube.
  ///
  /// 🔴 Yang dibuka [Tutorial.youtubeUrl] **apa adanya**, bukan alamat yang
  /// disusun ulang dari `youtubeId`. Menyusun ulang akan membuang parameter
  /// yang sengaja dipasang Admin, misalnya `?t=90` untuk melompat ke menit
  /// tertentu.
  ///
  /// ⚠️ `externalApplication` supaya aplikasi YouTube dipakai bila terpasang
  /// (Bab 9.9). Bila gagal — tautan rusak, atau tidak ada satu pun aplikasi
  /// yang sanggup membukanya — pengguna WAJIB diberi tahu. Ketukan yang tidak
  /// menghasilkan apa pun adalah cara tercepat membuat orang mengira
  /// aplikasinya rusak (Bab 9.10).
  Future<void> _buka(BuildContext context) async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final uri = Uri.tryParse(tutorial.youtubeUrl.trim());
    var berhasil = false;

    if (uri != null) {
      berhasil = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (!berhasil) {
      messenger.showSnackBar(SnackBar(content: Text(t.tutorialOpenFailed)));
    }
  }
}
