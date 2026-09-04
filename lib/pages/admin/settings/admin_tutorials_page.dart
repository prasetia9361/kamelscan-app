import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/tutorial.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'admin_settings_view_model.dart';

/// Kelola Tutorial (Bab 9.9) — Admin memasukkan tautan YouTube.
///
/// 🔴 Halaman ini menutup utang paling lama di proyek: tabel `tutorials` ada
/// sejak migrasi 10, izinnya sejak migrasi 14, dan selama itu tidak ada satu
/// pun cara mengisinya selain Supabase Dashboard — antarmuka teknis berbahasa
/// Inggris berupa tabel database.
///
/// ⚠️ Tidak ada migrasi yang dibutuhkan halaman ini. Yang selama ini kurang
/// hanyalah layarnya.
class AdminTutorialsPage extends ConsumerStatefulWidget {
  const AdminTutorialsPage({super.key});

  @override
  ConsumerState<AdminTutorialsPage> createState() => _AdminTutorialsPageState();
}

class _AdminTutorialsPageState extends ConsumerState<AdminTutorialsPage> {
  /// Membuka formulir lalu menyimpannya.
  ///
  /// 🔴 Metode State, bukan closure di dalam `build` — mengikuti alasan yang
  /// sama seperti `admin_promos_page.dart`: `context` milik `build` dianggap
  /// analyzer tidak berhubungan dengan `mounted` milik State, dan ia benar.
  Future<void> _sunting({Tutorial? awal}) async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final hasil = await showDialog<Tutorial>(
      context: context,
      builder: (d) => _DialogTutorial(awal: awal),
    );
    if (hasil == null || !mounted) return;

    final gagal =
        await ref.read(adminTutorialsViewModelProvider.notifier).upsert(hasil);
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          gagal == null ? t.adminSettingsSaved : context.failureMessage(gagal),
        ),
      ),
    );
  }

  Future<void> _hapus(Tutorial tutorial) async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final yakin = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t.adminTutorialDeleteTitle),
        // ⚠️ Menawarkan menonaktifkan lebih dulu, bukan langsung menghapus.
        // Langkah yang videonya sedang direkam ulang hampir selalu ingin
        // kembali dengan nomor dan judul yang sama.
        content: Text(t.adminTutorialDeleteBody(tutorial.title)),
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

    final gagal = await ref
        .read(adminTutorialsViewModelProvider.notifier)
        .delete(tutorial.id);
    if (!mounted) return;

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
    final async = ref.watch(adminTutorialsViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.adminTutorialsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _sunting(),
        icon: const Icon(Icons.add),
        label: Text(t.adminTutorialAdd),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorView(
          failure: e,
          onRetry: () => ref.invalidate(adminTutorialsViewModelProvider),
        ),
        data: (daftar) {
          if (daftar.isEmpty) {
            return AppEmptyState(
              icon: Icons.ondemand_video_outlined,
              title: t.adminTutorialEmptyTitle,
              message: t.adminTutorialEmptyBody,
              actionLabel: t.adminTutorialAdd,
              onAction: () => _sunting(),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: daftar.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _BarisTutorial(
              tutorial: daftar[i],
              onSunting: () => _sunting(awal: daftar[i]),
              onHapus: () => _hapus(daftar[i]),
              onAktif: (v) => ref
                  .read(adminTutorialsViewModelProvider.notifier)
                  .setActive(daftar[i], v),
            ),
          );
        },
      ),
    );
  }
}

class _BarisTutorial extends StatelessWidget {
  const _BarisTutorial({
    required this.tutorial,
    required this.onSunting,
    required this.onHapus,
    required this.onAktif,
  });

  final Tutorial tutorial;
  final VoidCallback onSunting;
  final VoidCallback onHapus;
  final ValueChanged<bool> onAktif;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;
    final t = context.l10n;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    '${tutorial.stepOrder}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tutorial.title,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Switch(value: tutorial.isActive, onChanged: onAktif),
              ],
            ),
            const SizedBox(height: 6),

            // 🔴 Tautannya ditampilkan utuh, bukan disembunyikan di balik
            // tombol. Kekeliruan paling mungkin di halaman ini adalah salah
            // tempel alamat, dan itu hanya terlihat kalau alamatnya terbaca.
            Text(
              tutorial.youtubeUrl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tutorial.isYoutubeUrlValid
                    ? scheme.onSurfaceVariant
                    : colors.danger,
              ),
            ),

            // ⚠️ Peringatan tautan tidak dikenali sengaja TIDAK memblokir.
            // YouTube dapat menambah bentuk alamat baru kapan saja, dan aturan
            // yang menolak lebih keras daripada kenyataannya akan mengunci
            // Admin dari tautan yang sebenarnya sah.
            if (!tutorial.isYoutubeUrlValid) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.warning_amber_outlined,
                      size: 15, color: colors.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.adminTutorialUrlWarning,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colors.warning),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  label: Text(_labelPlatform(t, tutorial.platform)),
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                TextButton(onPressed: onSunting, child: Text(t.commonEdit)),
                TextButton(
                  onPressed: onHapus,
                  child: Text(
                    t.commonDelete,
                    style: TextStyle(color: colors.danger),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ⚠️ Jatuhannya `all`, bukan menampilkan nilai mentahnya. `platform` teks
  /// bebas di database (Bab 5.2), jadi nilai di luar ketiganya mungkin ada —
  /// dan menuliskannya apa adanya berarti Admin membaca istilah teknis yang
  /// tidak pernah ia ketik.
  static String _labelPlatform(AppL10n t, String platform) =>
      switch (platform) {
        'web' => t.adminTutorialPlatformWeb,
        'mobile' => t.adminTutorialPlatformMobile,
        _ => t.adminTutorialPlatformAll,
      };
}

/// Formulir satu langkah tutorial.
class _DialogTutorial extends StatefulWidget {
  const _DialogTutorial({this.awal});

  final Tutorial? awal;

  @override
  State<_DialogTutorial> createState() => _DialogTutorialState();
}

class _DialogTutorialState extends State<_DialogTutorial> {
  late final TextEditingController _judul =
      TextEditingController(text: widget.awal?.title ?? '');
  late final TextEditingController _deskripsi =
      TextEditingController(text: widget.awal?.description ?? '');
  late final TextEditingController _url =
      TextEditingController(text: widget.awal?.youtubeUrl ?? '');
  late final TextEditingController _urutan = TextEditingController(
    text: '${widget.awal?.stepOrder ?? 1}',
  );

  late String _platform = widget.awal?.platform ?? 'all';
  late bool _aktif = widget.awal?.isActive ?? true;

  @override
  void dispose() {
    _judul.dispose();
    _deskripsi.dispose();
    _url.dispose();
    _urutan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return AlertDialog(
      title: Text(widget.awal == null
          ? t.adminTutorialAdd
          : t.adminTutorialEditTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _urutan,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: t.adminTutorialOrder),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _judul,
              decoration: InputDecoration(labelText: t.adminTutorialTitleField),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _deskripsi,
              maxLines: 2,
              decoration: InputDecoration(labelText: t.adminTutorialDesc),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              decoration: InputDecoration(
                labelText: t.adminTutorialUrl,
                hintText: 'https://youtu.be/...',
              ),
            ),
            const SizedBox(height: 12),

            // 🔴 `isExpanded: true` wajib, dan nilai terpilihnya wajib ada di
            // daftar pilihan — bila tidak, ia MELEMPAR dan meruntuhkan seluruh
            // halaman (jebakan 16). Karena `platform` teks bebas di database,
            // nilai di luar ketiganya dijatuhkan ke `all` saat dialog dibuka.
            DropdownButtonFormField<String>(
              initialValue: const {'all', 'web', 'mobile'}.contains(_platform)
                  ? _platform
                  : 'all',
              isExpanded: true,
              decoration: InputDecoration(labelText: t.adminTutorialPlatform),
              items: [
                DropdownMenuItem(
                    value: 'all', child: Text(t.adminTutorialPlatformAll)),
                DropdownMenuItem(
                    value: 'mobile',
                    child: Text(t.adminTutorialPlatformMobile)),
                DropdownMenuItem(
                    value: 'web', child: Text(t.adminTutorialPlatformWeb)),
              ],
              onChanged: (v) => setState(() => _platform = v ?? 'all'),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _aktif,
              onChanged: (v) => setState(() => _aktif = v),
              title: Text(t.adminTutorialActive),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.commonCancel),
        ),
        FilledButton(
          onPressed: _bolehSimpan ? _simpan : null,
          child: Text(t.commonSave),
        ),
      ],
    );
  }

  /// Judul dan tautan wajib terisi. Sisanya boleh kosong.
  bool get _bolehSimpan =>
      _judul.text.trim().isNotEmpty && _url.text.trim().isNotEmpty;

  void _simpan() {
    final deskripsi = _deskripsi.text.trim();

    Navigator.pop(
      context,
      Tutorial(
        // ⚠️ Kosong berarti langkah baru; kuncinya dibuat server. Lihat
        // `upsertTutorial`.
        id: widget.awal?.id ?? '',
        stepOrder: int.tryParse(_urutan.text.trim()) ?? 1,
        title: _judul.text.trim(),
        description: deskripsi.isEmpty ? null : deskripsi,
        youtubeUrl: _url.text.trim(),
        platform: _platform,
        isActive: _aktif,
      ),
    );
  }
}
