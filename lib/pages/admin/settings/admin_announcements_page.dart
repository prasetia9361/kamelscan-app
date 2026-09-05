import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/announcement.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import 'admin_settings_view_model.dart';

/// Kelola Iklan & Pengumuman (migrasi 50).
///
/// Diminta Product Owner 5 September 2026. Satu-satunya cara mengumumkan
/// sesuatu kepada seluruh pengguna — termasuk **mewajibkan mereka memperbarui
/// aplikasi** — tanpa merilis aplikasi baru.
///
/// 🔴 Halaman paling berbahaya di panel admin, dan sadar begitu. Pengumuman
/// berjenis *penting* menahan aplikasi sampai pengguna menekan tombol aksinya;
/// satu tautan yang salah di sana mengunci seluruh pelanggan sekaligus. Karena
/// itu formulirnya **menolak menyimpan** pengumuman penting tanpa tautan yang
/// terbaca sebagai alamat, dan tiap baris daftarnya punya sakelar nonaktif
/// yang dapat ditekan tanpa membuka formulirnya — tombol darurat, bukan
/// kenyamanan.
class AdminAnnouncementsPage extends ConsumerStatefulWidget {
  const AdminAnnouncementsPage({super.key});

  @override
  ConsumerState<AdminAnnouncementsPage> createState() =>
      _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState
    extends ConsumerState<AdminAnnouncementsPage> {
  /// Membuka formulir lalu menyimpan hasilnya.
  ///
  /// 🔴 Metode State, bukan closure di dalam `build` — mengikuti alasan yang
  /// sama seperti `admin_tutorials_page.dart`: `context` milik `build`
  /// dianggap analyzer tidak berhubungan dengan `mounted` milik State.
  Future<void> _sunting({Announcement? awal}) async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final hasil = await showDialog<_HasilForm>(
      context: context,
      builder: (d) => _DialogPengumuman(awal: awal),
    );
    if (hasil == null || !mounted) return;

    final gagal = await ref
        .read(adminAnnouncementsViewModelProvider.notifier)
        .simpan(hasil.announcement, gambar: hasil.gambar);
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          gagal == null ? t.adminSettingsSaved : context.failureMessage(gagal),
        ),
      ),
    );
  }

  Future<void> _hapus(Announcement a) async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final yakin = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t.adminAnnouncementDeleteTitle),
        // ⚠️ Menawarkan menonaktifkan lebih dulu, bukan langsung menghapus.
        // Pengumuman event tahunan hampir selalu ingin kembali dengan isi yang
        // sama, dan menghapusnya membuang gambarnya juga.
        content: Text(t.adminAnnouncementDeleteBody(a.title)),
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

    final gagal =
        await ref.read(adminAnnouncementsViewModelProvider.notifier).hapus(a);
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
    final async = ref.watch(adminAnnouncementsViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.adminAnnouncementsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _sunting(),
        icon: const Icon(Icons.add),
        label: Text(t.adminAnnouncementAdd),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorView(
          failure: e,
          onRetry: () => ref.invalidate(adminAnnouncementsViewModelProvider),
        ),
        data: (daftar) {
          if (daftar.isEmpty) {
            return AppEmptyState(
              icon: Icons.campaign_outlined,
              title: t.adminAnnouncementEmptyTitle,
              message: t.adminAnnouncementEmptyBody,
              actionLabel: t.adminAnnouncementAdd,
              onAction: () => _sunting(),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: daftar.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _BarisPengumuman(
              announcement: daftar[i],
              onSunting: () => _sunting(awal: daftar[i]),
              onHapus: () => _hapus(daftar[i]),
              onAktif: (v) => ref
                  .read(adminAnnouncementsViewModelProvider.notifier)
                  .setActive(daftar[i], v),
            ),
          );
        },
      ),
    );
  }
}

/// Satu baris daftar.
class _BarisPengumuman extends StatelessWidget {
  const _BarisPengumuman({
    required this.announcement,
    required this.onSunting,
    required this.onHapus,
    required this.onAktif,
  });

  final Announcement announcement;
  final VoidCallback onSunting;
  final VoidCallback onHapus;
  final ValueChanged<bool> onAktif;

  @override
  Widget build(BuildContext context) {
    final a = announcement;
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(a.title, style: theme.textTheme.titleSmall),
                ),
                Switch(value: a.isActive, onChanged: onAktif),
              ],
            ),
            const SizedBox(height: 6),

            // ⚠️ Wrap, bukan Row. Pada teks yang diperbesar atau bahasa yang
            // katanya lebih panjang, tiga label sejajar melimpah.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // 🔴 Jenisnya ditandai paling menyolok, dan yang mengunci
                // memakai warna bahaya. Inilah satu-satunya keterangan di
                // daftar ini yang membedakan "pengumuman" dari "seluruh
                // pelanggan tidak bisa memakai aplikasinya".
                _Label(
                  teks: a.mengunci
                      ? t.adminAnnouncementKindImportant
                      : t.adminAnnouncementKindNormal,
                  latar: a.mengunci
                      ? colors.dangerContainer
                      : scheme.surfaceContainerHighest,
                  warna: a.mengunci ? colors.danger : scheme.onSurfaceVariant,
                ),
                _Label(
                  teks: switch (a.audience) {
                    AnnouncementAudience.all =>
                      t.adminAnnouncementAudienceAll,
                    AnnouncementAudience.owner =>
                      t.adminAnnouncementAudienceOwner,
                    AnnouncementAudience.packer =>
                      t.adminAnnouncementAudiencePacker,
                  },
                  latar: scheme.surfaceContainerHighest,
                  warna: scheme.onSurfaceVariant,
                ),
                if (!a.isActive)
                  _Label(
                    teks: t.adminAnnouncementInactive,
                    latar: scheme.surfaceContainerHighest,
                    warna: scheme.onSurfaceVariant,
                  ),
              ],
            ),

            if (a.body.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                a.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],

            // 🔴 Tautannya ditampilkan utuh, bukan disembunyikan di balik
            // tombol. Kekeliruan paling mungkin di halaman ini adalah salah
            // tempel alamat, dan pada pengumuman yang mengunci itu berarti
            // pengguna terkurung — hanya terlihat kalau alamatnya terbaca.
            if ((a.actionUrl ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                a.actionUrl!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: a.punyaAksi ? scheme.primary : colors.danger,
                ),
              ),
            ],

            // Pengumuman yang mengunci tanpa tautan sah adalah jalan buntu.
            // Formulir menolaknya, tetapi baris lama — atau baris yang
            // disunting langsung lewat Supabase Dashboard — bisa saja begitu.
            if (a.mengunci && !a.punyaAksi) ...[
              const SizedBox(height: 8),
              Text(
                t.adminAnnouncementActionRequired,
                style: theme.textTheme.bodySmall?.copyWith(color: colors.danger),
              ),
            ],

            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onSunting,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(t.commonEdit),
                ),
                TextButton.icon(
                  onPressed: onHapus,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(t.commonDelete),
                  style: TextButton.styleFrom(foregroundColor: colors.danger),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.teks, required this.latar, required this.warna});

  final String teks;
  final Color latar;
  final Color warna;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: latar,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          teks,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: warna),
        ),
      );
}

/// Isi formulir saat ditutup: pengumumannya, dan gambar baru bila dipilih.
///
/// Gambarnya dipisahkan dari [Announcement] dengan sengaja: model itu
/// menyimpan **alamat** gambar, sedangkan yang keluar dari formulir adalah
/// **berkasnya**, yang belum punya alamat sampai diunggah — dan tidak dapat
/// diunggah sampai barisnya punya id.
class _HasilForm {
  const _HasilForm({required this.announcement, this.gambar});

  final Announcement announcement;
  final Uint8List? gambar;
}

/// Formulir tambah/ubah.
class _DialogPengumuman extends StatefulWidget {
  const _DialogPengumuman({this.awal});

  final Announcement? awal;

  @override
  State<_DialogPengumuman> createState() => _DialogPengumumanState();
}

class _DialogPengumumanState extends State<_DialogPengumuman> {
  late final TextEditingController _judul;
  late final TextEditingController _isi;
  late final TextEditingController _tautan;
  late final TextEditingController _labelTombol;

  late AnnouncementKind _jenis;
  late AnnouncementAudience _sasaran;
  late bool _aktif;

  Uint8List? _gambarBaru;
  String? _galat;

  @override
  void initState() {
    super.initState();
    final a = widget.awal;
    _judul = TextEditingController(text: a?.title ?? '');
    _isi = TextEditingController(text: a?.body ?? '');
    _tautan = TextEditingController(text: a?.actionUrl ?? '');
    _labelTombol = TextEditingController(text: a?.actionLabel ?? '');
    _jenis = a?.kind ?? AnnouncementKind.normal;
    _sasaran = a?.audience ?? AnnouncementAudience.all;
    _aktif = a?.isActive ?? true;
  }

  @override
  void dispose() {
    _judul.dispose();
    _isi.dispose();
    _tautan.dispose();
    _labelTombol.dispose();
    super.dispose();
  }

  Future<void> _pilihGambar() async {
    // ⚠️ `maxWidth: 1600` dan `imageQuality: 82` bukan angka asal: bucket-nya
    // dibatasi 5 MB (migrasi 46), dan gambar kamera HP masa kini menembusnya
    // dengan mudah. Menolak di server sesudah menunggu unggahan selesai adalah
    // cara terburuk memberi tahu orang bahwa gambarnya terlalu besar.
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _gambarBaru = bytes);
  }

  void _simpan() {
    final t = context.l10n;

    final judul = _judul.text.trim();
    if (judul.isEmpty) {
      setState(() => _galat = t.adminAnnouncementTitleRequired);
      return;
    }

    final calon = Announcement(
      id: widget.awal?.id ?? '',
      title: judul,
      body: _isi.text.trim(),
      imageUrl: widget.awal?.imageUrl,
      kind: _jenis,
      audience: _sasaran,
      actionUrl: _tautan.text.trim(),
      actionLabel: _labelTombol.text.trim(),
      isActive: _aktif,
    );

    // 🔴 Satu-satunya penolakan yang benar-benar penting di formulir ini.
    // Pengumuman yang mengunci tanpa tautan sah adalah jalan buntu: tidak ada
    // silang, tidak ada tombol, dan pengguna terkurung sampai memasang ulang
    // aplikasinya. Kekeliruan itu tidak menimbulkan galat apa pun — ia hanya
    // mengunci semua orang sekaligus, dan kita baru tahu dari telepon.
    if (calon.mengunci && !calon.punyaAksi) {
      setState(() => _galat = t.adminAnnouncementActionRequired);
      return;
    }

    Navigator.pop(context, _HasilForm(announcement: calon, gambar: _gambarBaru));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final lama = widget.awal;

    return AlertDialog(
      title: Text(
        lama == null
            ? t.adminAnnouncementAdd
            : t.adminAnnouncementEditTitle,
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _KotakGambar(
                bytesBaru: _gambarBaru,
                urlLama: lama?.imageUrl ?? '',
                onPilih: _pilihGambar,
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _judul,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: t.adminAnnouncementFieldTitle,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _isi,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: t.adminAnnouncementFieldBody,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                t.adminAnnouncementFieldKind,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              SegmentedButton<AnnouncementKind>(
                segments: [
                  ButtonSegment(
                    value: AnnouncementKind.normal,
                    label: Text(t.adminAnnouncementKindNormal),
                  ),
                  ButtonSegment(
                    value: AnnouncementKind.important,
                    label: Text(t.adminAnnouncementKindImportant),
                  ),
                ],
                selected: {_jenis},
                onSelectionChanged: (v) => setState(() => _jenis = v.first),
              ),
              const SizedBox(height: 6),
              // Kalimat ini yang membedakan dua tombol di atas. Tanpa itu
              // "Penting" terbaca seperti sekadar warna yang lebih menyolok.
              Text(
                t.adminAnnouncementKindHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<AnnouncementAudience>(
                initialValue: _sasaran,
                decoration: InputDecoration(
                  labelText: t.adminAnnouncementFieldAudience,
                ),
                items: [
                  DropdownMenuItem(
                    value: AnnouncementAudience.all,
                    child: Text(t.adminAnnouncementAudienceAll),
                  ),
                  DropdownMenuItem(
                    value: AnnouncementAudience.owner,
                    child: Text(t.adminAnnouncementAudienceOwner),
                  ),
                  DropdownMenuItem(
                    value: AnnouncementAudience.packer,
                    child: Text(t.adminAnnouncementAudiencePacker),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _sasaran = v ?? AnnouncementAudience.all),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _tautan,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: t.adminAnnouncementFieldActionUrl,
                  hintText: 'https://play.google.com/store/apps/details?id=…',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _labelTombol,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: t.adminAnnouncementFieldActionLabel,
                ),
              ),
              const SizedBox(height: 8),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.adminAnnouncementFieldActive),
                value: _aktif,
                onChanged: (v) => setState(() => _aktif = v),
              ),

              if (_galat != null) ...[
                const SizedBox(height: 8),
                Text(
                  _galat!,
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: colors.danger),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.commonCancel),
        ),
        FilledButton(onPressed: _simpan, child: Text(t.commonSave)),
      ],
    );
  }
}

/// Pratinjau gambar di dalam formulir.
class _KotakGambar extends StatelessWidget {
  const _KotakGambar({
    required this.bytesBaru,
    required this.urlLama,
    required this.onPilih,
  });

  /// Gambar yang baru dipilih dan belum diunggah. Menang atas [urlLama].
  final Uint8List? bytesBaru;
  final String urlLama;
  final VoidCallback onPilih;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;
    final ada = bytesBaru != null || urlLama.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: switch (bytesBaru) {
              final b? => Image.memory(b, fit: BoxFit.cover),
              _ when urlLama.isNotEmpty => Image.network(
                  urlLama,
                  fit: BoxFit.cover,
                  // ⚠️ Gagal muatnya WAJIB terlihat sebagai kegagalan, bukan
                  // sebagai kotak kosong yang terbaca seperti "belum ada
                  // gambar" — Admin akan mengunggah ulang sesuatu yang
                  // sebenarnya sudah ada.
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
              _ => Container(
                  color: scheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Text(
                    t.adminBannerEmpty,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
            },
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onPilih,
          icon: const Icon(Icons.image_outlined, size: 18),
          label: Text(
            ada ? t.adminBannerReplace : t.adminBannerUpload,
          ),
        ),
      ],
    );
  }
}
