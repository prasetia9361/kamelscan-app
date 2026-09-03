import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../theme/app_text_styles_display.dart';

/// Nomor resi sebagai objek utama, bukan sebaris teks di antara teks lain.
///
/// Susunannya: label 9 sp berspasi lebar, nomor mono besar, garis camel 2 dp
/// di bawahnya. Garis itu satu-satunya tempat aksen merek muncul di halaman
/// ini — cukup untuk terasa milik KamelScan, tidak cukup untuk bersaing dengan
/// angkanya.
///
/// ⚠️ **Bukan untuk halaman hasil rekaman** — halaman itu tidak ada, dan panel
/// bertombol "Rekam paket berikutnya" memang sudah dibuang 15 Agustus 2026
/// (lihat `_FinishedNotice` di `recording_camera_page.dart`: pada 100 paket itu
/// berarti 100 ketukan yang tidak menghasilkan apa pun).
///
/// Tempatnya yang benar hanya **dua**: detail video (`pages/history/detail/`)
/// dan kepala dialog resi ganda — dua tempat yang memang dibuka sesekali, bukan
/// yang dilewati ratusan kali sehari.
class ResiStamp extends StatelessWidget {
  const ResiStamp({
    super.key,
    required this.resi,
    required this.label,
    this.copyLabel,
    this.onCopy,
  });

  final String resi;

  /// Label di atas nomor, mis. "NOMOR RESI". Datang dari l10n — berkas ini
  /// sengaja tidak mengenal `context.l10n` supaya tetap dapat diuji sendiri.
  final String label;

  /// Label tombol salin. Wajib diisi bila [onCopy] diisi.
  final String? copyLabel;

  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 18),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.outlineVariant),
          bottom: BorderSide(color: scheme.secondary, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppDisplayStyles.kicker.copyWith(
              fontSize: 9,
              letterSpacing: 2.2,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Resi bisa panjang (JNE, J&T, dan resi marketplace berbeda-beda
              // panjangnya). Dikecilkan, bukan dipotong — nomor bukti yang
              // terpotong lebih buruk daripada nomor yang kecil.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    resi,
                    style: AppDisplayStyles.resiStamp
                        .copyWith(color: scheme.onSurface),
                  ),
                ),
              ),
              if (onCopy != null)
                TextButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.content_copy_rounded, size: 17),
                  label: Text(copyLabel ?? ''),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(AppSizes.touchMin, AppSizes.touchMin),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
