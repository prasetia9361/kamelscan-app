import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/failure_messages.dart';
import '../../core/widgets/page_scaffold_placeholder.dart';
import 'widgets/logout_button.dart';

/// AccountPage — **baru sebagian**.
///
/// Spesifikasi: Bab 9.6. Enam butir daftar menunya (Edit Profil, Ganti
/// Password, Kelola Akun Packer, Info Langganan, Bantuan & Kontak, Keluar)
/// baru butir terakhir yang dikerjakan; sisanya masih penanda.
///
/// Bab 9.6 butir 6 menempatkan tombol Keluar **di paling bawah**, jadi ia
/// dipasang menempel di dasar layar sejak sekarang — begitu daftar menunya
/// digarap, daftar itu mengisi ruang di atasnya dan tombolnya tidak perlu
/// dipindahkan.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: PageScaffoldPlaceholder(
              title: context.l10n.navAccount,
              specChapter: 'Bab 9.6',
              icon: Icons.person_outline_rounded,
            ),
          ),
          // Jarak bawah 88 dp, bukan 24 dp: tombol Rekam yang mengambang di
          // sudut kanan bawah kerangka mobile menumpang di atas isi halaman,
          // dan pada jarak 24 dp ia menutupi ujung kanan tombol Keluar.
          // Terlihat di Redmi Note 9, 17 Agustus 2026. Tinggi tombol
          // mengambang 56 dp ditambah tepinya 16 dp.
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 88),
            child: LogoutButton(),
          ),
        ],
      ),
    );
  }
}
