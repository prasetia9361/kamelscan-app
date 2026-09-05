import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/announcement.dart';
import '../providers/announcement_provider.dart';
import '../providers/repository_providers.dart';
import '../providers/session_provider.dart';
import '../theme/app_colors.dart';
import 'double_back_exit.dart';
import 'failure_messages.dart';

/// Memunculkan iklan & pengumuman sesudah pengguna masuk (migrasi 50).
///
/// Diminta Product Owner 5 September 2026, untuk HP dan web sekaligus.
/// Dipasang **di rangka** — `MobileShell` dan `WebShell` — bukan di tiap
/// halaman: rangka adalah satu-satunya tempat yang pasti terpasang begitu
/// seseorang selesai masuk, dan hanya sekali.
///
/// 🔴 Dua jenis, dan perbedaannya bukan warna:
///
///   - **Penting** (`important`) mengunci. Tidak ada tanda silang, dan
///     satu-satunya yang dapat ditekan adalah tombol aksinya — biasanya menuju
///     Play Store. Ini yang dipakai saat versi baru wajib dipasang.
///   - **Biasa** (`normal`) dapat ditutup dengan tanda silang, dan yang sudah
///     ditutup tidak muncul lagi bagi orang itu — tercatat di server, bukan di
///     perangkat, supaya orang yang sama tidak melihatnya lagi di layar kedua.
///
/// ⚠️ Admin tidak pernah melihat apa pun dari sini. Panel admin berdiri di luar
/// kedua rangka, dan [Announcement.untuk] menolak peran admin.
class AnnouncementGate extends ConsumerStatefulWidget {
  const AnnouncementGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AnnouncementGate> createState() => _AnnouncementGateState();
}

class _AnnouncementGateState extends ConsumerState<AnnouncementGate> {
  /// Yang sudah ditutup selama aplikasi ini hidup.
  ///
  /// 🔴 Dicatat di sini, bukan hanya di server, supaya pengumuman berikutnya
  /// dapat langsung muncul tanpa menunggu daftar dibaca ulang. Tanpa ini
  /// pengguna yang menutup pengumuman pertama menatap layar kosong sepanjang
  /// perjalanan bolak-balik ke server sebelum yang kedua muncul — dan di gudang
  /// bersinyal buruk, perjalanan itu bisa berdetik-detik.
  final _ditutup = <String>{};

  /// Sebuah pengumuman sedang tampil. Menahan dialog kedua terbuka di atas
  /// dialog pertama saat daftarnya berubah di tengah jalan.
  bool _sedangTampil = false;

  @override
  Widget build(BuildContext context) {
    // 🔴 Diurutkan di sini juga, walaupun repository sudah mengurutkannya.
    //
    // Bukan kehati-hatian berlebihan: urutan itulah yang menjamin pengumuman
    // yang mengunci muncul sebelum pengumuman biasa. Kalau yang biasa tampil
    // lebih dulu, pengguna menutupnya, lalu baru bertemu layar "wajib update"
    // — ia sudah menutup sesuatu yang tidak pernah sempat dibacanya, dan
    // penutupannya terlanjur dicatat. Jaminan sepenting itu tidak boleh
    // bergantung pada siapa yang kebetulan mengisi daftarnya.
    final daftar = [
      ...?ref.watch(activeAnnouncementsProvider).value,
    ]..sort(Announcement.urutkan);

    // Yang paling depan dan belum ditutup.
    Announcement? berikutnya;
    for (final a in daftar) {
      if (!_ditutup.contains(a.id)) {
        berikutnya = a;
        break;
      }
    }

    if (berikutnya != null && !_sedangTampil) {
      final a = berikutnya;
      _sedangTampil = true;
      // Ditunda ke sesudah frame: `showDialog` menyentuh Navigator, dan
      // menyentuhnya di tengah build melempar.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tampilkan(a);
      });
    }

    return widget.child;
  }

  Future<void> _tampilkan(Announcement a) async {
    await showDialog<void>(
      context: context,
      // 🔴 Yang mengunci tidak boleh ditutup dengan mengetuk latar. Itu jalan
      // keluar yang tidak terlihat sama sekali, dan justru yang paling mudah
      // dilakukan tanpa sengaja.
      barrierDismissible: !a.mengunci,
      builder: (_) => _KartuPengumuman(announcement: a),
    );

    if (!mounted) return;

    // Hanya tercapai untuk pengumuman biasa — yang mengunci tidak pernah
    // menutup dialognya, jadi `showDialog` di atas tidak pernah selesai.
    setState(() {
      _ditutup.add(a.id);
      _sedangTampil = false;
    });

    final session = ref.read(sessionProvider).value;
    if (session == null) return;

    // Dikirim tanpa ditunggu dan tanpa dilaporkan kalau gagal. Pengumuman yang
    // gagal dicatat hanya muncul lagi pada login berikutnya; menahan layar
    // dengan pesan merah untuk sesuatu yang baru saja ditutup pengguna jauh
    // lebih buruk daripada itu.
    final hasil = await ref.read(announcementRepositoryProvider).tutup(
          announcementId: a.id,
          userId: session.user.id,
        );
    if (hasil.isErr) {
      debugPrint('KAMELSCAN_IKLAN penutupan ${a.id} gagal dicatat · '
          '${hasil.failureOrNull}');
    }
  }
}

/// Isi dialognya.
class _KartuPengumuman extends StatelessWidget {
  const _KartuPengumuman({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final isi = _Isi(announcement: a);

    if (!a.mengunci) return isi;

    // 🔴 Yang mengunci dibungkus `DoubleBackToExit`, bukan `PopScope` polos.
    //
    // `PopScope(canPop: false)` saja memang menahan dialognya — tetapi juga
    // merampas satu-satunya cara menutup aplikasi lewat tombol Kembali, dan
    // orang yang belum sempat memperbarui akan menekannya berkali-kali tanpa
    // pernah terjadi apa-apa. Dengan widget ini tombol Kembali tetap tidak
    // menutup dialognya, tetapi dua ketukan tetap menutup aplikasi — persis
    // seperti di Beranda.
    return DoubleBackToExit(child: isi);
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.announcement});

  final Announcement announcement;

  Future<void> _bukaAksi(BuildContext context) async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final uri = Uri.tryParse(announcement.actionUrl?.trim() ?? '');
    if (uri == null) return;

    final dibuka = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (dibuka) return;

    // ⚠️ Kegagalannya WAJIB terlihat. Pada pengumuman yang mengunci, tombol ini
    // satu-satunya yang dapat ditekan — tombol yang diam saat ditekan membuat
    // orang menyimpulkan aplikasinya rusak, bukan tautannya.
    messenger.showSnackBar(
      SnackBar(content: Text(t.announcementActionFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final t = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        // Lebarnya dibatasi supaya di dasbor web ia tidak melebar menjadi
        // spanduk selebar layar — dialog yang terlalu lebar berhenti terbaca
        // sebagai pesan dan mulai terbaca sebagai halaman.
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (a.punyaGambar)
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        a.imageUrl!,
                        fit: BoxFit.cover,
                        // ⚠️ Gambar ini datang dari internet dan dibuka di
                        // gudang bersinyal buruk. Gagal muatnya tidak boleh
                        // menjatuhkan seluruh pengumuman — teksnyalah yang
                        // membawa isinya, dan pada pengumuman yang mengunci
                        // teks itu satu-satunya penjelasan yang ada.
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                    if (!a.mengunci)
                      const Positioned(
                        top: 4,
                        right: 4,
                        child: _TombolTutup(diAtasGambar: true),
                      ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            a.title,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        // Tanpa gambar, silangnya menempel di samping judul.
                        if (!a.mengunci && !a.punyaGambar)
                          const _TombolTutup(diAtasGambar: false),
                      ],
                    ),

                    if (a.mengunci) ...[
                      const SizedBox(height: 8),
                      // Penanda ini bukan hiasan: ia menjelaskan kenapa tidak
                      // ada tanda silang, sebelum orang mencarinya.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.dangerContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          t.announcementRequiredBadge,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: colors.danger),
                        ),
                      ),
                    ],

                    if (a.body.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        a.body,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],

                    if (a.punyaAksi) ...[
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () => _bukaAksi(context),
                        child: Text(
                          (a.actionLabel?.trim().isNotEmpty ?? false)
                              ? a.actionLabel!.trim()
                              : t.announcementOpenAction,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tanda silang. Hanya ada pada pengumuman biasa.
class _TombolTutup extends StatelessWidget {
  const _TombolTutup({required this.diAtasGambar});

  /// Di atas gambar ia perlu latar sendiri: gambar terang membuat ikon terang
  /// lenyap, dan gambar gelap membuat ikon gelap lenyap.
  final bool diAtasGambar;

  @override
  Widget build(BuildContext context) {
    final tombol = IconButton(
      tooltip: context.l10n.commonClose,
      icon: const Icon(Icons.close_rounded),
      onPressed: () => Navigator.of(context).pop(),
    );

    if (!diAtasGambar) return tombol;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
      child: IconTheme(
        data: const IconThemeData(color: Colors.white),
        child: tombol,
      ),
    );
  }
}
