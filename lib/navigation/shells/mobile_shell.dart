import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/enums.dart';
import '../../core/providers/session_provider.dart';
import '../../core/widgets/failure_messages.dart';
import '../route_names.dart';

/// Rangka mobile: AppBar + BottomNav + child (Bab 3.2).
///
/// Menu yang tidak relevan disembunyikan menurut role — ini kenyamanan, bukan
/// keamanan (Bab 2.3). Penegakan sesungguhnya ada di RLS dan di `RouteGuards`.
class MobileShell extends ConsumerWidget {
  const MobileShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final role = ref.watch(currentRoleProvider);
    final session = ref.watch(sessionProvider).value;
    final isOwner = role == UserRole.owner;

    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home_rounded),
        label: t.navHome,
      ),
      NavigationDestination(
        icon: const Icon(Icons.history_outlined),
        selectedIcon: const Icon(Icons.history_rounded),
        label: t.navHistory,
      ),
      if (isOwner)
        NavigationDestination(
          icon: const Icon(Icons.storefront_outlined),
          selectedIcon: const Icon(Icons.storefront_rounded),
          label: t.navShops,
        ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline_rounded),
        selectedIcon: const Icon(Icons.person_rounded),
        label: t.navAccount,
      ),
    ];

    // Indeks branch GoRouter tetap 0..3; saat menu Toko disembunyikan, indeks
    // Akun bergeser di UI tetapi tidak di router.
    final branchOfTab = isOwner ? [0, 1, 2, 3] : [0, 1, 3];
    final currentTab = branchOfTab.indexOf(navigationShell.currentIndex);

    final lock = session?.recordingLock;

    return Scaffold(
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
              onPressed: () => lock == null
                  ? context.push(Routes.recordSetup)
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
