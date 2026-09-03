import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Foto profil bulat (Bab 9.1 & 9.6).
///
/// Bila `avatar_url` kosong, yang tampil inisial nama di atas warna yang
/// dihasilkan dari hash `user_id` — dua orang berbeda hampir selalu mendapat
/// warna berbeda, sehingga daftar packer tetap dapat dibedakan sekilas.
///
/// 🔴 Inisialnya tetap digambar **di belakang** fotonya. Di gudang bersinyal
/// buruk gambar sering gagal dimuat, dan yang tersisa harus tetap mengenali
/// orangnya — bukan lingkaran kosong.
///
/// Dipakai bersama oleh bilah atas dan halaman Akun; menyalinnya ke dua tempat
/// berarti warna dan bentuknya perlahan menyimpang.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.initials,
    required this.seed,
    required this.avatarUrl,
    this.size = 44,
    this.onTap,
    this.online,
  });

  /// Titik status sambungan di sudut kanan bawah. `null` = tidak digambar.
  ///
  /// Hijau = tersambung, jingga = tanpa jaringan. **Jingga, bukan merah**:
  /// tanpa jaringan perekaman tetap jalan dan videonya masuk antrean lokal
  /// (Bab 8.7), jadi itu peringatan, bukan kegagalan. Merah akan membuat
  /// packer berhenti merekam padahal tidak perlu.
  final bool? online;

  final String initials;

  /// Biasanya `user_id`. Menentukan warna latar saat tidak ada foto.
  final String seed;

  final String? avatarUrl;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = AppStaticColors.avatarFor(seed);
    final url = (avatarUrl ?? '').trim();

    final huruf = Text(
      initials,
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.36,
        fontWeight: FontWeight.w700,
      ),
    );

    Widget avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: background,
      // `CachedNetworkImageProvider`, bukan `NetworkImage`: foto profil muncul
      // di hampir setiap layar, dan mengunduhnya berulang membakar kuota data
      // packer tanpa menambah apa pun.
      foregroundImage:
          url.isEmpty ? null : CachedNetworkImageProvider(url),
      child: huruf,
    );

    if (online != null) {
      // Ekstensi dibaca di sini, bukan di atas: avatar dipakai di layar yang
      // temanya belum tentu memasang `AppColors` (dialog, pratinjau), dan
      // `!` di jalur yang tidak membutuhkannya adalah galat yang menunggu.
      final colors = Theme.of(context).extension<AppColors>()!;
      final titik = size * 0.3;
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: titik,
              height: titik,
              decoration: BoxDecoration(
                color: online! ? colors.success : colors.warning,
                shape: BoxShape.circle,
                // Garis tepi setebal warna latar halaman, supaya titiknya
                // terbaca di atas foto apa pun — termasuk foto yang kebetulan
                // sewarna dengannya.
                border: Border.all(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap == null) return avatar;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: avatar,
    );
  }
}
