import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/enums.dart';
import '../../core/providers/session_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/failure_messages.dart';
import '../route_names.dart';
import 'mobile_app_bar.dart';

/// Rangka mobile: AppBar + BottomNav + child (Bab 3.2).
///
/// Menu yang tidak relevan disembunyikan menurut role — ini kenyamanan, bukan
/// keamanan (Bab 2.3). Penegakan sesungguhnya ada di RLS dan di `RouteGuards`.
class MobileShell extends ConsumerWidget {
  const MobileShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Nomor cabang GoRouter untuk tiap tombol menu bawah, berurutan.
  ///
  /// 🔴 **Nomor cabang TIDAK sama dengan urutan tombolnya.** Cabangnya tetap:
  ///
  /// | Cabang | Isi |
  /// |---|---|
  /// | 0 | Beranda |
  /// | 1 | Riwayat |
  /// | 2 | Toko |
  /// | 3 | Akun & Pembayaran |
  /// | 4 | Pengaturan |
  ///
  /// Sedangkan urutan tombolnya mengikuti Bab 9.1 — Home · Toko · Riwayat ·
  /// Setting · Akun — dan menu Toko **disembunyikan** untuk packer, bukan
  /// sekadar dinonaktifkan.
  ///
  /// Dipisahkan sebagai fungsi murni supaya dapat diuji tanpa perangkat.
  /// Kalau daftar ini meleset satu angka saja, packer yang menekan Riwayat
  /// akan mendarat di halaman lain — kesalahan yang tidak menimbulkan error
  /// apa pun dan hanya ketahuan dengan mencobanya.
  static List<int> branchesFor({required bool isOwner}) =>
      isOwner ? const [0, 2, 1, 4, 3] : const [0, 1, 4, 3];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final role = ref.watch(currentRoleProvider);
    final session = ref.watch(sessionProvider).value;
    final isOwner = role == UserRole.owner;

    // Urutan mengikuti Bab 9.1: Home · Toko · Riwayat · Setting · Akun.
    // Beranda paling kiri karena paling sering dibuka.
    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home_rounded),
        label: t.navHome,
      ),
      if (isOwner)
        NavigationDestination(
          icon: const Icon(Icons.storefront_outlined),
          selectedIcon: const Icon(Icons.storefront_rounded),
          label: t.navShops,
        ),
      NavigationDestination(
        icon: const Icon(Icons.history_outlined),
        selectedIcon: const Icon(Icons.history_rounded),
        label: t.navHistory,
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings_rounded),
        label: t.navSettings,
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline_rounded),
        selectedIcon: const Icon(Icons.person_rounded),
        label: t.navAccount,
      ),
    ];

    final branchOfTab = MobileShell.branchesFor(isOwner: isOwner);
    final currentTab = branchOfTab.indexOf(navigationShell.currentIndex);

    final lock = session?.recordingLock;

    // 🔴 Jejak diagnosis — Beranda kosong pada packer, 20 Agustus 2026.
    //
    // Product Owner melaporkan: sesudah packer masuk, badan Beranda kosong
    // sama sekali; menekan menu lain lalu kembali membuat isinya muncul.
    // Kosongnya bukan skeleton dan bukan layar error — keduanya kelihatan —
    // sehingga dugaan terkuat adalah `navigationShell` sedang menampilkan
    // cabang yang belum pernah dikunjungi, dan cabang semacam itu digambar
    // GoRouter sebagai ruang kosong.
    //
    // Satu baris ini yang membedakannya: bila `cabang` tidak ada di
    // `branchOfTab`, dugaan itu benar dan perbaikannya di lapisan navigasi.
    // Bila `cabang=0` sementara layarnya kosong, sebabnya di dalam HomePage
    // dan lapisan navigasi tidak bersalah — dua perbaikan yang sama sekali
    // berbeda, dan mustahil dibedakan dengan mata.
    debugPrint('KAMELSCAN_SHELL cabang=${navigationShell.currentIndex} '
        'tab=$currentTab isOwner=$isOwner role=${role?.wire}');

    return Scaffold(
      // Bab 9.1 — kerangka tiga bagian: bilah atas, isi, menu bawah. Bilahnya
      // dipasang di sini, bukan di tiap halaman, supaya seluruh tab memakai
      // kepala yang sama persis.
      appBar: MobileTopBar(
        // Branch Akun selalu bernomor 3 di router, walaupun posisinya di menu
        // bergeser saat Toko disembunyikan dari packer.
        onProfileTap: () => navigationShell.goBranch(3),
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab < 0 ? 0 : currentTab,
        destinations: destinations,
        onDestinationSelected: (index) => navigationShell.goBranch(
          branchOfTab[index],
          initialLocation: branchOfTab[index] == navigationShell.currentIndex,
        ),
      ),
      floatingActionButton: role == UserRole.admin
          ? null
          : FloatingActionButton.extended(
              // Bab 7.3 — saat token habis, tombol tetap terlihat tetapi
              // mengarah ke halaman Pembayaran, bukan hilang tanpa penjelasan.
              //
              // 🔴 Saat token ada, tombol ini **menanyakan jenis paket lebih
              // dulu** dan tidak pernah membuka perekaman tanpa jenis
              // (`arahan.json`: `else → perekaman = none`). Sebelumnya ia
              // langsung masuk, dan karena layar setup kini tidak lagi punya
              // pemilih jenis, jalur itu akan diam-diam merekam segalanya
              // sebagai packing — termasuk paket return.
              onPressed: () => lock == null
                  ? _askPackageType(context)
                  : context.push(Routes.payment),
              icon: Icon(
                lock == null
                    ? Icons.videocam_rounded
                    : Icons.lock_outline_rounded,
              ),
              label: Text(
                lock == null
                    ? t.navRecord
                    : context.messageForKey(lock.messageKey),
              ),
            ),
    );
  }
}

/// Lembar pilihan jenis paket untuk tombol Rekam mengambang.
///
/// Tombol itu tidak berangkat dari salah satu menu Beranda, jadi jenisnya belum
/// ditentukan. `arahan.json` menetapkan bahwa tanpa jenis tidak ada perekaman —
/// karena itu ia ditanyakan di sini, bukan diam-diam dianggap packing.
Future<void> _askPackageType(BuildContext context) async {
  final t = context.l10n;
  final colors = Theme.of(context).extension<AppColors>()!;

  final chosen = await showModalBottomSheet<VideoType>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              t.recordChooseType,
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: Icon(Icons.inventory_2_outlined, color: colors.packing),
            title: Text(t.homeMenuRecordPacking),
            onTap: () => Navigator.pop(sheetContext, VideoType.packing),
          ),
          ListTile(
            leading:
                Icon(Icons.assignment_return_outlined, color: colors.returnColor),
            title: Text(t.homeMenuRecordReturn),
            onTap: () => Navigator.pop(sheetContext, VideoType.returned),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (chosen == null || !context.mounted) return;
  await context.push(Routes.recordSetupOf(typeWire: chosen.wire));
}
