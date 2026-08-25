import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/enums.dart';
import '../../core/providers/session_provider.dart';
import '../../core/widgets/failure_messages.dart';
import '../../l10n/generated/app_localizations.dart';
import '../route_names.dart';

/// Menu sidebar web, sesuai urutan Bab 10.3.
///
/// Sengaja sebuah enum, bukan daftar widget: urutan, alamat, dan pembatasan
/// perannya jadi dapat diuji tanpa membangun satu piksel pun. Pelajaran yang
/// sama dengan `MobileShell.branchesFor` — daftar yang meleset satu baris
/// mengirim pengguna ke halaman lain **tanpa menimbulkan error apa pun**, dan
/// hanya ketahuan dengan mencobanya satu per satu.
enum WebMenu {
  dashboard(Routes.webDashboard),
  shops(Routes.shops, ownerOnly: true),
  history(Routes.history),
  packers(Routes.packers, ownerOnly: true),
  payment(Routes.payment, ownerOnly: true),
  settings(Routes.settings),
  tutorial(Routes.tutorial);

  const WebMenu(this.path, {this.ownerOnly = false});

  /// Alamat tujuan. Tidak ada satu pun yang menjadi awalan yang lain, sehingga
  /// pencocokan menurut awalan di [WebShell.selectedIndexOf] tidak ambigu.
  final String path;

  /// Bab 2.2 — packer tidak punya Toko, Packer, maupun Pembayaran. Ini
  /// kenyamanan, bukan keamanan; penegakannya di `RouteGuards` dan RLS.
  final bool ownerOnly;

  String label(AppL10n t) => switch (this) {
        WebMenu.dashboard => t.navDashboard,
        WebMenu.shops => t.navShops,
        WebMenu.history => t.navHistory,
        WebMenu.packers => t.navPackers,
        WebMenu.payment => t.navPayment,
        WebMenu.settings => t.navSettings,
        WebMenu.tutorial => t.navTutorial,
      };

  IconData get icon => switch (this) {
        WebMenu.dashboard => Icons.insights_outlined,
        WebMenu.shops => Icons.storefront_outlined,
        WebMenu.history => Icons.history_outlined,
        WebMenu.packers => Icons.groups_outlined,
        WebMenu.payment => Icons.credit_card_outlined,
        WebMenu.settings => Icons.settings_outlined,
        WebMenu.tutorial => Icons.school_outlined,
      };

  IconData get selectedIcon => switch (this) {
        WebMenu.dashboard => Icons.insights_rounded,
        WebMenu.shops => Icons.storefront_rounded,
        WebMenu.history => Icons.history_rounded,
        WebMenu.packers => Icons.groups_rounded,
        WebMenu.payment => Icons.credit_card_rounded,
        WebMenu.settings => Icons.settings_rounded,
        WebMenu.tutorial => Icons.school_rounded,
      };
}

/// Rangka web: sidebar kiri + bilah atas + isi halaman (Bab 10.3).
///
/// Tidak ada tombol rekam di sini — web memang tidak merekam (Bab 1.3 poin 5),
/// dan rutenya pun tidak didaftarkan untuk target web.
class WebShell extends ConsumerWidget {
  const WebShell({
    super.key,
    required this.navigationShell,
    required this.location,
  });

  final StatefulNavigationShell navigationShell;

  /// Alamat yang sedang terbuka, diberikan router agar menu yang menyala
  /// dihitung dari alamat — bukan dari nomor cabang.
  ///
  /// 🔴 Alasannya bukan gaya. Tiga menu Bab 10.3 — Packer, Pembayaran, dan
  /// Beranda — berbagi cabang dengan menu lain atau merupakan anak dari
  /// halaman lain. `navigationShell.currentIndex` hanya mengenal cabang, jadi
  /// membuka Packer akan menyalakan menu Akun, dan sebaliknya. Alamat
  /// mengenali keduanya dengan tepat.
  final String location;

  /// Di bawah lebar ini sidebar berubah menjadi laci (Bab 10.3).
  static const double drawerBreakpoint = 1024;

  /// Di bawah lebar ini tabel berubah menjadi kartu (Bab 10.3).
  ///
  /// Belum dipakai siapa pun — tabelnya baru lahir di Bab 10.5. Ditaruh di
  /// sini supaya kedua titik hentinya berdampingan dan tidak ada yang menebak
  /// angkanya sendiri di halaman masing-masing.
  static const double cardBreakpoint = 768;

  /// Menu yang boleh dilihat peran ini, berurutan sesuai Bab 10.3.
  static List<WebMenu> menuFor({required bool isOwner}) => [
        for (final m in WebMenu.values)
          if (isOwner || !m.ownerOnly) m,
      ];

  /// Menu mana yang sedang menyala, atau `null` bila alamatnya bukan salah
  /// satu menu — misalnya halaman Akun, yang dicapai dari bilah atas.
  ///
  /// Awalan dipakai, bukan kecocokan penuh, supaya halaman anak ikut
  /// menyalakan induknya: `/shops/form/123` tetap menyalakan Toko.
  static int? selectedIndexOf({
    required List<WebMenu> menu,
    required String location,
  }) {
    final index = menu.indexWhere((m) => location.startsWith(m.path));
    return index < 0 ? null : index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    final isOwner = role == UserRole.owner;
    final menu = menuFor(isOwner: isOwner);
    final selected = selectedIndexOf(menu: menu, location: location);
    final wide = MediaQuery.sizeOf(context).width >= drawerBreakpoint;

    void openMenu(WebMenu target) {
      // Sengaja `go`, bukan `goBranch`. Dua menu — Packer dan Pembayaran —
      // bukan akar cabangnya sendiri, dan `goBranch` hanya bisa menuju akar.
      // `go` tetap memindahkan cabang dengan benar dan menjaga isi cabang lain.
      context.go(target.path);
    }

    final sidebar = _Sidebar(
      menu: menu,
      selected: selected,
      onSelect: openMenu,
    );

    return Scaffold(
      appBar: _WebTopBar(location: location),
      // Laci hanya ada saat sempit. Saat lebar ia null, dan Scaffold otomatis
      // menghilangkan tombol hamburgernya — tidak perlu diatur sendiri.
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(
                child: _Sidebar(
                  menu: menu,
                  selected: selected,
                  onSelect: (target) {
                    Navigator.of(context).pop();
                    openMenu(target);
                  },
                ),
              ),
            ),
      body: Row(
        children: [
          if (wide) ...[
            SizedBox(width: 240, child: sidebar),
            const VerticalDivider(width: 1),
          ],
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

/// Daftar menu. Dipakai dua kali: menempel di kiri saat layar lebar, dan di
/// dalam laci saat sempit. Satu widget untuk keduanya supaya tidak ada
/// kemungkinan isinya berbeda.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.menu,
    required this.selected,
    required this.onSelect,
  });

  final List<WebMenu> menu;
  final int? selected;
  final ValueChanged<WebMenu> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Icon(
                Icons.qr_code_scanner_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              // 🔴 `Expanded` wajib. Nama aplikasi bisa panjang di bahasa lain,
              // dan tanpa batas ini `Row` melebar melewati lebar sidebar.
              Expanded(
                child: Text(
                  t.appName,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final (i, m) in menu.indexed)
                _SidebarTile(
                  menu: m,
                  active: i == selected,
                  onTap: () => onSelect(m),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.menu,
    required this.active,
    required this.onTap,
  });

  final WebMenu menu;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        selected: active,
        selectedTileColor: theme.colorScheme.primaryContainer,
        selectedColor: theme.colorScheme.onPrimaryContainer,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(active ? menu.selectedIcon : menu.icon),
        title: Text(
          menu.label(t),
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Bilah atas Bab 10.3: pencarian resi di kiri, status token dan profil di
/// kanan.
class _WebTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const _WebTopBar({required this.location});

  final String location;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      // 🔴 Judulnya kolom pencarian, dan ia WAJIB dibatasi `ConstrainedBox`.
      // Kolom teks tanpa batas melebar sejauh yang diizinkan induknya, lalu
      // menggencet `actions` di sebelahnya sampai nol — bentuk lain dari
      // jebakan lebar tak terhingga yang sudah dua kali memakan waktu di
      // proyek ini (M.12 dan M.17).
      titleSpacing: 16,
      title: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: const _ResiSearchField(),
        ),
      ),
      actions: const [
        _SessionChip(),
        SizedBox(width: 8),
        _ProfileMenu(),
        SizedBox(width: 12),
      ],
    );
  }
}

/// Bab 10.3 — *"Pencarian resi menonjol di top bar karena ini adalah alur
/// kerja utama saat menangani komplain."*
///
/// Hasilnya dikirim lewat alamat, bukan lewat provider bersama: petugas yang
/// menangani komplain hampir selalu berdua dengan rekannya, dan alamat yang
/// dapat disalin menghemat satu putaran pengetikan ulang.
class _ResiSearchField extends StatefulWidget {
  const _ResiSearchField();

  @override
  State<_ResiSearchField> createState() => _ResiSearchFieldState();
}

class _ResiSearchFieldState extends State<_ResiSearchField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final q = value.trim();
    if (q.isEmpty) return;
    context.go(Routes.historyOf(query: q));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onSubmitted: _submit,
      decoration: InputDecoration(
        isDense: true,
        hintText: t.historySearchHint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// Chip status langganan / uji coba di bilah atas (Bab 7.5).
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

/// Bab 10.3 — *"[foto] Budi ▼"* di ujung kanan bilah atas.
///
/// ⚠️ Sengaja **tidak** memuat Keluar. Bab 9.6 butir 6 menempatkan tombol itu
/// di dasar halaman Akun, dan tombol itulah satu-satunya yang memperingatkan
/// bahwa masih ada video belum terunggah (Bab 8.7). Jalan keluar kedua tanpa
/// peringatan yang sama akan diam-diam melewatinya.
class _ProfileMenu extends ConsumerWidget {
  const _ProfileMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    if (session == null) return const SizedBox.shrink();

    final t = context.l10n;
    final theme = Theme.of(context);
    final user = session.user;

    return PopupMenuButton<String>(
      tooltip: t.navAccount,
      position: PopupMenuPosition.under,
      onSelected: context.go,
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(user.fullName),
            subtitle: Text(user.email, overflow: TextOverflow.ellipsis),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: Routes.account,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(t.navAccount),
          ),
        ),
        PopupMenuItem(
          value: Routes.settings,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.settings_outlined),
            title: Text(t.navSettings),
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            foregroundImage: user.avatarUrl == null
                ? null
                : NetworkImage(user.avatarUrl!),
            child: Text(user.initials, style: theme.textTheme.labelMedium),
          ),
          const SizedBox(width: 8),
          // 🔴 Lebar dibatasi. Nama panjang di dalam `Row` bilah atas akan
          // mendorong isi lain keluar layar tanpa satu pun pesan galat.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(user.fullName, overflow: TextOverflow.ellipsis),
          ),
          const Icon(Icons.arrow_drop_down_rounded),
        ],
      ),
    );
  }
}
