import 'package:flutter/material.dart';

/// Menu bawah dengan penanda garis 2 dp — pengganti `NavigationBar`
/// (`PANDUAN_TAMPILAN.md` Langkah 6).
///
/// 🔴 Kenapa pil Material 3 dibuang:
///
/// Pil oval di belakang ikon aktif adalah penanda visual paling cepat dikenali
/// dari "aplikasi yang memakai Material 3 apa adanya". Ia juga memakan 32 dp
/// tinggi untuk menyampaikan satu bit informasi: tab mana yang aktif. Garis
/// 2 dp di tepi atas menyampaikan hal yang sama, ikut mengikat menu ke tepi
/// layar, dan menyisakan ruang untuk label yang terbaca.
///
/// Ikon aktif memakai varian `_rounded` (isi penuh) dan yang tidak aktif
/// `_outlined` — jadi pembedanya bentuk **dan** warna, bukan warna saja
/// (§0 palet: warna tidak pernah menjadi satu-satunya pembeda makna).
///
/// Ikonnya dipilih agar tiap tab bersiluet berbeda, bukan lima bentuk
/// bulat/kotak yang mirip: `cottage`, `storefront`, `video_library`, `tune`,
/// `account_circle`.
///
/// - `video_library` sengaja menggantikan `history`: isi tab itu daftar video,
///   bukan riwayat aktivitas.
/// - `tune` menggantikan gerigi `settings`. ⚠️ Desainer meminta `instant_mix`,
///   tetapi ikon itu **hanya ada di Material Symbols**, bukan di Material Icons
///   yang diapalkan Flutter — sama seperti `package_2`. `tune` adalah glif
///   slider dari keluarga bentuk yang sama, dan tersedia. Keputusan Product
///   Owner 31 Agustus 2026.
///
/// `SafeArea(top: false)` di bawah membuat menu **turun sampai tepi bawah** —
/// latar surface-nya mengisi area home indicator, jadi tidak ada bidang warna
/// lain di bawah menu. Jangan bungkus lagi dengan `SafeArea` dari luar, dan
/// jangan sisakan bidang warna lain di bawahnya.
///
/// Pemakaian di `MobileShell`: ganti `bottomNavigationBar: NavigationBar(…)`
/// menjadi `KamelNavBar(items: …, currentIndex: …, onSelect: …)`. Pemetaan
/// cabang GoRouter (`branchesFor`) **tidak berubah sama sekali** — hanya
/// `List<NavigationDestination>` menjadi `List<KamelNavItem>`.
class KamelNavItem {
  const KamelNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class KamelNavBar extends StatelessWidget {
  const KamelNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<KamelNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _Tab(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});

  final KamelNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 2,
                  width: selected ? 26 : 0,
                  color: scheme.primary,
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(selected ? item.activeIcon : item.icon,
                      size: 25, color: tint),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
