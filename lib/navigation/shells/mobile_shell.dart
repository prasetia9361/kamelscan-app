import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/enums.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/announcement_gate.dart';
import '../../core/widgets/double_back_exit.dart';
import '../../core/widgets/failure_messages.dart';
import '../route_names.dart';
import 'kamel_nav_bar.dart';
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
    //
    // Ikonnya dipilih agar tiap tab bersiluet berbeda — alasan lengkapnya ada
    // di dartdoc `KamelNavBar`. `video_library` menggantikan `history` karena
    // isi tab itu daftar video, bukan riwayat aktivitas.
    final destinations = <KamelNavItem>[
      KamelNavItem(
        icon: Icons.cottage_outlined,
        activeIcon: Icons.cottage_rounded,
        label: t.navHome,
      ),
      if (isOwner)
        KamelNavItem(
          icon: Icons.storefront_outlined,
          activeIcon: Icons.storefront_rounded,
          label: t.navShops,
        ),
      KamelNavItem(
        icon: Icons.video_library_outlined,
        activeIcon: Icons.video_library_rounded,
        label: t.navHistory,
      ),
      KamelNavItem(
        icon: Icons.tune_outlined,
        activeIcon: Icons.tune_rounded,
        label: t.navSettings,
      ),
      KamelNavItem(
        icon: Icons.account_circle_outlined,
        activeIcon: Icons.account_circle_rounded,
        label: t.navAccount,
      ),
    ];

    final branchOfTab = MobileShell.branchesFor(isOwner: isOwner);
    final currentTab = branchOfTab.indexOf(navigationShell.currentIndex);

    final lock = session?.recordingLock;
    final showFab = ref.watch(showRecordFabProvider);

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

    final rangka = Scaffold(
      // Bab 9.1 — kerangka tiga bagian: bilah atas, isi, menu bawah. Bilahnya
      // dipasang di sini, bukan di tiap halaman, supaya seluruh tab memakai
      // kepala yang sama persis.
      appBar: MobileTopBar(
        // Branch Akun selalu bernomor 3 di router, walaupun posisinya di menu
        // bergeser saat Toko disembunyikan dari packer.
        onProfileTap: () => navigationShell.goBranch(3),
      ),
      body: navigationShell,
      // `KamelNavBar` sudah memakai `SafeArea(top: false)` di dalamnya supaya
      // latarnya turun sampai tepi bawah — jangan dibungkus `SafeArea` lagi
      // dari sini, dan jangan sisakan bidang warna lain di bawahnya.
      bottomNavigationBar: KamelNavBar(
        items: destinations,
        currentIndex: currentTab < 0 ? 0 : currentTab,
        onSelect: (index) => navigationShell.goBranch(
          branchOfTab[index],
          // 🔴 SELALU `true`, bukan hanya saat tabnya sedang terbuka.
          //
          // Dilaporkan Product Owner 5 September 2026: buka Pembayaran dari
          // Beranda, pindah ke Riwayat, lalu kembali ke Beranda — yang
          // tergambar masih Pembayaran. Sebabnya halaman yang di-`push`
          // menumpuk DI DALAM cabang yang sedang terbuka, dan tumpukan itu
          // disimpan GoRouter per cabang; menekan tombol menu tanpa
          // `initialLocation` hanya menampilkan kembali tumpukan itu apa
          // adanya.
          //
          // Menekan tombol menu bawah berarti "bawa saya ke menu ini", bukan
          // "kembalikan saya ke tempat terakhir saya di menu ini" — dan itu
          // berlaku untuk SEMUA menu, bukan hanya yang sedang bermasalah.
          initialLocation: true,
        ),
      ),
      // Bab 9.7 — sakelar "Tombol Rekam mengambang" (Pengaturan → Perekaman).
      // Saat dimatikan, perekaman dimulai dari kartu di Beranda, dan jarak
      // bawah daftar ikut mengecil di `home_page`, `history_page`, dan
      // `account_page` — ruang 88 dp itu memang disisakan khusus untuk tombol
      // ini.
      floatingActionButton: (role == UserRole.admin || !showFab)
          ? null
          : FloatingActionButton.extended(
              // Bawaan `FloatingActionButton` memakai `primaryContainer`, dan
              // di mode gelap itu biru tua yang nyaris hilang di atas latar
              // gelap. Tombol ini justru yang paling sering ditekan sepanjang
              // hari, jadi ia memakai `primary` penuh — satu-satunya bidang
              // warna primer utuh di Beranda.
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
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

    // Tombol Kembali perangkat: keluar aplikasi butuh dua ketukan
    // (keluhan Product Owner 5 September 2026). Dipasang di rangka, bukan di
    // tiap halaman — inilah rute paling bawah, satu-satunya tempat yang
    // ketukan Kembali-nya benar-benar menutup aplikasi.
    // Iklan & pengumuman (migrasi 50) dipasang di rangka, bukan di tiap
    // halaman: inilah satu-satunya tempat yang pasti terpasang begitu
    // seseorang selesai masuk, dan hanya sekali.
    return DoubleBackToExit(
      child: AnnouncementGate(child: rangka),
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
            // `move_to_inbox` menggantikan `assignment_return`: yang lama
            // berupa papan klip yang siluetnya nyaris sama dengan kardus
            // `inventory_2` di atasnya pada ukuran ikon daftar.
            leading:
                Icon(Icons.move_to_inbox_outlined, color: colors.returnColor),
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
