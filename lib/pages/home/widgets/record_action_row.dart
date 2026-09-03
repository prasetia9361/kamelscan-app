import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles_display.dart';

/// Kartu aksi perekaman — pengganti `_MenuGrid` + `_MenuTile`
/// (`PANDUAN_TAMPILAN.md` Langkah 5).
///
/// 🔴 Kenapa kisi 2×2 lama dibongkar:
///
/// Kisi 2×2 menyatakan empat hal berbobot sama. Kenyataannya dua di antaranya
/// (Packing, Return) dipakai ratusan kali sehari dan dua lainnya (Pembayaran,
/// Tutorial) mungkin dua kali sebulan. Sekarang: dua kartu perekaman
/// berdampingan, lalu Pembayaran & Tutorial turun jadi baris kartu tipis
/// berchevron di bawahnya.
///
/// **Kedua kartu berisi penuh warna jenisnya** — packing `primary`, return
/// `returnContainer` — jadi keduanya terbaca setara. Sebelumnya Return berupa
/// kartu putih bergaris tepi, dan pasangan itu terbaca seperti satu tombol
/// utama plus satu tombol sekunder.
///
/// ⚠️ Warna teks di atas ungu memakai pasangan `returnContainer` /
/// `onReturnContainer` yang sudah ada di `AppColors` — jangan bikin token baru.
///
/// **Tidak ada baris subjudul.** Keputusan Product Owner 31 Agustus 2026:
/// prototipe punya subjudul ("Bukti sebelum dikirim"), tetapi label pendek
/// ditambah ikon dan warna sudah menyatakan jenisnya, jadi barisnya dihapus
/// alih-alih menambah dua string baru. Satu-satunya yang masih memakai ruang
/// itu adalah label terkunci Bab 7.3 — ia menggantikan baris "Mulai".
///
/// Status terkunci tetap seperti Bab 7.3: abu-abu, **masih dapat ditekan**,
/// dengan label kecil "Token habis". Tombol mati tanpa penjelasan adalah cara
/// tercepat membuat pengguna mengira aplikasinya rusak (Bab 9.10).
class RecordActionCard extends StatelessWidget {
  const RecordActionCard({
    super.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.startLabel,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.locked = false,
    this.lockedLabel,
  });

  final String label;

  /// Keterangan satu baris, mis. "Bukti sebelum dikirim".
  ///
  /// Saat [locked] ia digantikan [lockedLabel] berwarna error — persis baris
  /// inilah yang membawa penjelasan Bab 7.3, jadi ia tidak boleh dihapus.
  final String subtitle;

  final IconData icon;

  /// Ajakan di dasar kartu, mis. "Mulai". Sebelum ini kartu jenis tidak punya
  /// tanda sama sekali bahwa ia dapat ditekan.
  final String startLabel;

  /// Latar kartu saat tidak terkunci: `primary` untuk packing,
  /// `AppColors.returnContainer` untuk return.
  final Color background;

  /// Teks & ikon di atas [background]: `onPrimary` / `onReturnContainer`.
  ///
  /// Ikon hantu dan petak ikon diturunkan dari warna ini dengan alpha, bukan
  /// dari putih literal — supaya keduanya tetap benar di mode gelap, tempat
  /// `onPrimary` justru berwarna gelap.
  final Color foreground;

  final VoidCallback onTap;
  final bool locked;
  final String? lockedLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final bg = locked ? scheme.surfaceContainerHigh : background;
    final fg = locked ? scheme.onSurfaceVariant : foreground;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              // Ikon hantu: penanda jenis tanpa menambah satu kata pun. Ia
              // melampaui tepi kartu dan dipotong `clipBehavior` di atas.
              Positioned(
                right: -28,
                bottom: -32,
                child: IgnorePointer(
                  child: Icon(
                    icon,
                    size: 82,
                    color: fg.withValues(alpha: locked ? 0.06 : 0.13),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: fg.withValues(alpha: locked ? 0.08 : 0.20),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, size: 23, color: fg),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 15.5,
                      height: 20 / 15.5,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    locked ? (lockedLabel ?? '') : subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      height: 15 / 11,
                      color: locked
                          ? scheme.error
                          : fg.withValues(alpha: 0.78),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Ajakan disembunyikan saat terkunci: kartunya tetap dapat
                  // ditekan (Bab 7.3), tetapi yang dibukanya Pembayaran, bukan
                  // perekaman — "Mulai" akan berbohong tentang tujuannya.
                  if (!locked)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          startLabel.toUpperCase(),
                          style: AppDisplayStyles.kicker.copyWith(
                            fontSize: 9.5,
                            letterSpacing: 1.5,
                            color: fg,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: fg),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris tipis berchevron untuk Pembayaran & Tutorial.
///
/// Sebelumnya keduanya jadi petak sebesar kartu perekaman di kisi 2×2, dan itu
/// menyatakan bobot yang sama padahal keduanya dibuka mungkin dua kali sebulan.
/// Bentuk pil garis tepi juga sempat diusulkan, tetapi pil terbaca seperti
/// tombol saringan, bukan pintu ke halaman — chevron menyatakannya.
class RecordSecondaryTile extends StatelessWidget {
  const RecordSecondaryTile({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.subtitle,
  });

  final String label;

  /// Keterangan satu baris, mis. "Paket & token". Boleh null.
  ///
  /// ⚠️ Prototipe memakainya; di sini dibiarkan kosong sampai Product Owner
  /// menyetujui dua string barunya, sejalan dengan keputusan 31 Agustus 2026
  /// yang membuang subjudul pada kartu perekaman. Mengisinya kembali cukup satu
  /// baris di `home_page.dart`.
  final String? subtitle;

  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: accent),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: scheme.onSurface),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
