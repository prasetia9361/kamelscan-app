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
  });

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

    final avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: background,
      // `CachedNetworkImageProvider`, bukan `NetworkImage`: foto profil muncul
      // di hampir setiap layar, dan mengunduhnya berulang membakar kuota data
      // packer tanpa menambah apa pun.
      foregroundImage:
          url.isEmpty ? null : CachedNetworkImageProvider(url),
      child: huruf,
    );

    if (onTap == null) return avatar;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: avatar,
    );
  }
}
