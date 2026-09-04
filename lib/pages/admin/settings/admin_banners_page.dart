import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_failure.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'admin_settings_view_model.dart';

/// Gambar iklan landing page dan kartu paket (Bab 11.5).
///
/// 🔴 Utang nomor 3 daftar kesiapan produksi, dan yang paling lama tertunda
/// setelah Tutorial. Bab 11.5 menyebut gambar iklan diunggah ke bucket
/// `public-assets`, tetapi bucket itu **tidak pernah dibuat** — diukur
/// 3 September 2026. Ia lahir di migrasi 46.
///
/// Alamat gambarnya sendiri sudah punya tempat sejak migrasi 08, jadi yang
/// selama ini kurang hanya tempat menaruh berkasnya dan layar untuk
/// menaruhnya. Sampai hari ini keduanya hanya dapat dikerjakan lewat Supabase
/// Dashboard — antarmuka teknis berbahasa Inggris yang tidak seharusnya
/// dituntut dari orang yang mengelola isi iklan.
class AdminBannersPage extends ConsumerStatefulWidget {
  const AdminBannersPage({super.key});

  @override
  ConsumerState<AdminBannersPage> createState() => _AdminBannersPageState();
}

class _AdminBannersPageState extends ConsumerState<AdminBannersPage> {
  final _judul = TextEditingController();
  final _subjudul = TextEditingController();
  bool _sedang = false;
  bool _terisi = false;

  @override
  void dispose() {
    _judul.dispose();
    _subjudul.dispose();
    super.dispose();
  }

  /// Memilih gambar lalu menyerahkannya ke [simpan].
  ///
  /// 🔴 Metode State, bukan closure di dalam `build` — `context` milik `build`
  /// dianggap analyzer tidak berhubungan dengan `mounted` milik State.
  ///
  /// ⚠️ `maxWidth: 1600` dan `imageQuality: 82` bukan angka asal: bucket-nya
  /// dibatasi 5 MB (migrasi 46), dan gambar kamera HP masa kini menembusnya
  /// dengan mudah. Menolak di server sesudah menunggu unggahan selesai adalah
  /// cara terburuk memberi tahu orang bahwa gambarnya terlalu besar.
  Future<void> _pilih(
    Future<AppFailure?> Function(Uint8List bytes) simpan,
  ) async {
    if (_sedang) return;
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (picked == null || !mounted) return;

    setState(() => _sedang = true);
    final bytes = await picked.readAsBytes();
    final gagal = await simpan(bytes);
    if (!mounted) return;
    setState(() => _sedang = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          gagal == null
              ? t.adminSettingsSaved
              : context.failureMessage(gagal),
        ),
      ),
    );
  }

  /// Menanyakan lebih dulu, lalu menyerahkan penghapusan ke [hapus].
  ///
  /// 🔴 Dikonfirmasi karena tidak dapat dibatalkan: berkasnya dibuang dari
  /// bucket, dan gambar aslinya hanya ada di HP Admin. Ini juga satu-satunya
  /// tombol di layar ini yang merusak sesuatu.
  Future<void> _hapus(
    String label,
    Future<AppFailure?> Function() hapus,
  ) async {
    if (_sedang) return;
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final yakin = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t.adminBannerDeleteTitle),
        content: Text(t.adminBannerDeleteBody(label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(t.commonDelete),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    setState(() => _sedang = true);
    final gagal = await hapus();
    if (!mounted) return;
    setState(() => _sedang = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          gagal == null
              ? t.adminBannerDeleted
              : context.failureMessage(gagal),
        ),
      ),
    );
  }

  Future<void> _simpanTeks() async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _sedang = true);
    final gagal = await ref
        .read(adminBannersViewModelProvider.notifier)
        .simpanTeksLanding(
          headline: _judul.text.trim(),
          subheadline: _subjudul.text.trim(),
        );
    if (!mounted) return;
    setState(() => _sedang = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          gagal == null ? t.adminSettingsSaved : context.failureMessage(gagal),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final async = ref.watch(adminBannersViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.adminBannersTitle)),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorView(
          failure: e,
          onRetry: () => ref.invalidate(adminBannersViewModelProvider),
        ),
        data: (data) {
          // Formulir diisi sekali saja. Mengisinya ulang tiap build akan
          // menghapus ketikan Admin setiap kali layarnya digambar ulang.
          if (!_terisi) {
            _judul.text = data.landingHeadline;
            _subjudul.text = data.landingSub;
            _terisi = true;
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(t.adminBannerLandingTitle,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                t.adminBannerLandingBody,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),

              _KotakGambar(
                url: data.landingImage,
                label: t.adminBannerLandingImage,
                sedang: _sedang,
                onPilih: () => _pilih(
                  (b) => ref
                      .read(adminBannersViewModelProvider.notifier)
                      .unggahLanding(b),
                ),
                onHapus: () => _hapus(
                  t.adminBannerLandingImage,
                  () => ref
                      .read(adminBannersViewModelProvider.notifier)
                      .hapusLanding(),
                ),
              ),

              const SizedBox(height: 16),
              TextField(
                controller: _judul,
                decoration: InputDecoration(labelText: t.adminBannerHeadline),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subjudul,
                maxLines: 2,
                decoration:
                    InputDecoration(labelText: t.adminBannerSubheadline),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _sedang ? null : _simpanTeks,
                child: Text(t.commonSave),
              ),

              const SizedBox(height: 32),
              Text(t.adminBannerPlanTitle,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                t.adminBannerPlanBody,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),

              // 🔴 Dibangun dari `TierPlan.values`, BUKAN disebut satu per
              // satu. Pola A yang sudah muncul tiga kali di proyek ini, dan
              // setiap kali akibatnya sama: paket Bisnis tidak pernah
              // tergambar (`admin_pricing_page.dart`, `create-payment`, dan
              // tesnya sendiri).
              for (final plan in TierPlan.values) ...[
                _KotakGambar(
                  url: data.imageFor(plan),
                  label: _namaPlan(t, plan),
                  sedang: _sedang,
                  onPilih: () => _pilih(
                    (b) => ref
                        .read(adminBannersViewModelProvider.notifier)
                        .unggahPaket(plan, b),
                  ),
                  onHapus: () => _hapus(
                    _namaPlan(t, plan),
                    () => ref
                        .read(adminBannersViewModelProvider.notifier)
                        .hapusPaket(plan),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _namaPlan(AppL10n t, TierPlan plan) => switch (plan) {
        TierPlan.standar => t.tierStandar,
        TierPlan.pro => t.tierPro,
        TierPlan.bisnis => t.tierBisnis,
      };
}

/// Pratinjau satu gambar beserta tombol mengganti dan menghapusnya.
class _KotakGambar extends StatelessWidget {
  const _KotakGambar({
    required this.url,
    required this.label,
    required this.sedang,
    required this.onPilih,
    required this.onHapus,
  });

  final String url;
  final String label;
  final bool sedang;
  final VoidCallback onPilih;
  final VoidCallback onHapus;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),

            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: url.isEmpty
                    ? Container(
                        color: scheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Text(
                          t.adminBannerEmpty,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        // ⚠️ Gambar ini datang dari internet dan dibuka di
                        // gudang bersinyal buruk. Kegagalan muatnya WAJIB
                        // terlihat sebagai kegagalan, bukan sebagai kotak
                        // kosong yang terbaca seperti "belum ada gambar".
                        errorBuilder: (_, _, _) => Container(
                          color: colors.dangerContainer,
                          alignment: Alignment.center,
                          child: Text(
                            t.adminBannerLoadFailed,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: colors.danger),
                          ),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 10),
            // ⚠️ Wrap, bukan Row. Pada teks yang diperbesar atau bahasa yang
            // katanya lebih panjang, dua tombol sejajar melimpah dan Flutter
            // menggambar garis kuning-hitam alih-alih tombolnya.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: sedang ? null : onPilih,
                  icon: const Icon(Icons.upload_outlined, size: 18),
                  label: Text(
                    url.isEmpty ? t.adminBannerUpload : t.adminBannerReplace,
                  ),
                ),
                // 🔴 Hanya muncul bila ADA yang dapat dihapus. Tombol hapus di
                // samping kotak kosong menjanjikan pekerjaan yang tidak ada,
                // dan menekannya hanya menghasilkan kebingungan.
                if (url.isNotEmpty)
                  TextButton.icon(
                    onPressed: sedang ? null : onHapus,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(t.commonDelete),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.danger,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
