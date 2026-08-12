import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/enums.dart';
import '../../core/providers/session_provider.dart';
import '../../core/widgets/failure_messages.dart';

/// Rangka web: Sidebar kiri + TopBar + child (Bab 10.1).
///
/// Tidak ada tombol rekam di sini — web memang tidak merekam (Bab 1.3 poin 5),
/// dan rutenya pun tidak didaftarkan untuk target web.
class WebShell extends ConsumerWidget {
  const WebShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Di bawah lebar ini sidebar dilipat menjadi rail ikon saja.
  static const double _railBreakpoint = 1100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final role = ref.watch(currentRoleProvider);
    final isOwner = role == UserRole.owner;
    final extended = MediaQuery.sizeOf(context).width >= _railBreakpoint;

    final destinations = <NavigationRailDestination>[
      NavigationRailDestination(
        icon: const Icon(Icons.insights_outlined),
        selectedIcon: const Icon(Icons.insights_rounded),
        label: Text(t.navDashboard),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.history_outlined),
        selectedIcon: const Icon(Icons.history_rounded),
        label: Text(t.navHistory),
      ),
      if (isOwner)
        NavigationRailDestination(
          icon: const Icon(Icons.storefront_outlined),
          selectedIcon: const Icon(Icons.storefront_rounded),
          label: Text(t.navShops),
        ),
      NavigationRailDestination(
        icon: const Icon(Icons.person_outline_rounded),
        selectedIcon: const Icon(Icons.person_rounded),
        label: Text(t.navAccount),
      ),
    ];

    final branchOfTab = isOwner ? [0, 1, 2, 3] : [0, 1, 3];
    final currentTab = branchOfTab.indexOf(navigationShell.currentIndex);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.appName),
        actions: const [_SessionChip(), SizedBox(width: 16)],
      ),
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            selectedIndex: currentTab < 0 ? 0 : currentTab,
            destinations: destinations,
            labelType: extended ? null : NavigationRailLabelType.all,
            onDestinationSelected: (index) => navigationShell.goBranch(
              branchOfTab[index],
              initialLocation:
                  branchOfTab[index] == navigationShell.currentIndex,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

/// Chip status langganan / uji coba di TopBar (Bab 7.5).
class _SessionChip extends ConsumerWidget {
  const _SessionChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    if (session == null) return const SizedBox.shrink();

    final t = context.l10n;
    final balance = session.wallet?.balance ?? 0;

    return Chip(
      avatar: const Icon(Icons.token_outlined, size: 18),
      label: Text(
        session.isTrial ? t.trialChip(balance) : t.tokenRemaining(balance),
      ),
    );
  }
}
