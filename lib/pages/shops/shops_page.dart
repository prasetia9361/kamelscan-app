import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/shop_summary.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_state_views.dart';
import '../../core/widgets/failure_messages.dart';
import '../../navigation/route_names.dart';
import '../history/widgets/marketplace_badge.dart';
import 'shops_view_model.dart';

/// Halaman Toko (Bab 9.5 — Owner saja).
///
/// Halaman ini menghalangi pekerjaan lain bila kosong: perekaman tidak dapat
/// dimulai tanpa toko, dan pelanggan baru akan buntu di layar setup.
class ShopsPage extends ConsumerWidget {
  const ShopsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final async = ref.watch(shopsViewModelProvider);
    final vm = ref.read(shopsViewModelProvider.notifier);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            // 🔴 Judul dan tombol sengaja BERTUMPUK, bukan berdampingan.
            //
            // Tema aplikasi memberi seluruh FilledButton
            // `minimumSize: Size.fromHeight(...)`, dan `Size.fromHeight`
            // berarti lebar minimum **tak terhingga** — disengaja, supaya
            // tombol utama seperti Simpan dan Mulai selalu selebar layar.
            // Menaruh tombol seperti itu di dalam `Row` membuatnya menuntut
            // seluruh lebar: judul di sebelahnya tergambar menurun satu huruf
            // per baris, dan daftarnya terdorong keluar layar.
            //
            // Terjadi sungguhan di Redmi Note 9, 19 Agustus 2026. Membatasi
            // `minimumSize` memang menyembuhkan gejalanya, tetapi hanya
            // menyisakan ± 119 dp untuk judul pada layar 393 dp — masih terlalu
            // sempit untuk judul beserta keterangannya. Bertumpuk lebih jujur
            // pada ruang yang benar-benar ada, dan tombolnya jadi selebar
            // layar: sasaran sentuh paling mudah bagi tangan bersarung tangan
            // (Bab 9.10).
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.shopsTitle, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  t.shopsSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                // Bab 9.5 menyebut tombol **mengambang**. Sudut kanan bawah
                // sudah ditempati tombol Rekam milik kerangka layar (Bab 9.1),
                // dan menumpuk dua tombol mengambang di titik yang sama membuat
                // keduanya sulit ditekan tepat.
                FilledButton.tonalIcon(
                  onPressed: () => context.push(Routes.shopForm),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(t.shopsAdd),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: vm.refresh,
              child: switch (async) {
                AsyncValue(:final value?) => _ShopList(items: value),
                AsyncError(:final error) => ListView(
                    children: [
                      const SizedBox(height: 80),
                      AppErrorView(failure: error, onRetry: vm.refresh),
                    ],
                  ),
                _ => const AppListSkeleton(),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopList extends StatelessWidget {
  const _ShopList({required this.items});

  final List<ShopSummary> items;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    if (items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          AppEmptyState(
            icon: Icons.storefront_outlined,
            title: t.emptyShopsTitle,
            message: t.emptyShopsMessage,
            actionLabel: t.shopsAdd,
            onAction: () => context.push(Routes.shopForm),
          ),
        ],
      );
    }

    return ListView.separated(
      // Jarak bawah 88 dp — tombol Rekam mengambang milik kerangka menumpang
      // di atas isi halaman dan akan menutupi baris terakhir.
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _ShopTile(item: items[index]),
    );
  }
}

class _ShopTile extends ConsumerWidget {
  const _ShopTile({required this.item});

  final ShopSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final shop = item.shop;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(Routes.shopEditOf(shop.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Opacity(
                opacity: shop.isActive ? 1 : 0.45,
                child: MarketplaceBadge(marketName: shop.marketName),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: shop.isActive
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shop.marketName,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Status aktif dibawa tulisan, bukan hanya warna
                        // (§0 palet).
                        _StatusChip(active: shop.isActive),
                        const SizedBox(width: 8),
                        Text(
                          t.shopsVideoCount(item.videoCount),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Bab 9.5 menyebut geser-ke-kiri untuk Edit/Hapus. Diganti menu
              // tiga titik: gestur geser tidak meninggalkan petunjuk apa pun di
              // layar, dan di gudang — yang sering dioperasikan dengan sarung
              // tangan — sasaran sentuh 48 dp yang terlihat jauh lebih dapat
              // diandalkan daripada gerakan yang harus ditebak dulu (Bab 9.10).
              _ShopMenu(item: item),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final color = active ? colors.success : theme.colorScheme.outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        active ? t.shopsActive : t.shopsInactive,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

enum _ShopAction { edit, toggleActive, delete }

class _ShopMenu extends ConsumerWidget {
  const _ShopMenu({required this.item});

  final ShopSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;
    final shop = item.shop;

    return PopupMenuButton<_ShopAction>(
      tooltip: t.shopsMenuTooltip,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _ShopAction.edit,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_outlined),
            title: Text(t.commonEdit),
          ),
        ),
        PopupMenuItem(
          value: _ShopAction.toggleActive,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              shop.isActive
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
            ),
            title: Text(shop.isActive ? t.shopsDeactivate : t.shopsActivate),
          ),
        ),
        PopupMenuItem(
          value: _ShopAction.delete,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline_rounded, color: colors.danger),
            title: Text(
              t.commonDelete,
              style: TextStyle(color: colors.danger),
            ),
          ),
        ),
      ],
      onSelected: (action) => _jalankan(context, ref, action),
    );
  }

  Future<void> _jalankan(
    BuildContext context,
    WidgetRef ref,
    _ShopAction action,
  ) async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final vm = ref.read(shopsViewModelProvider.notifier);
    final shop = item.shop;

    switch (action) {
      case _ShopAction.edit:
        unawaited(context.push(Routes.shopEditOf(shop.id)));

      case _ShopAction.toggleActive:
        final failure = await vm.setActive(shop.id, active: !shop.isActive);
        if (!context.mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              failure != null
                  ? context.failureMessage(failure)
                  : (shop.isActive
                      ? t.shopsDeactivated(shop.shopName)
                      : t.shopsActivated(shop.shopName)),
            ),
          ),
        );

      case _ShopAction.delete:
        // Toko yang masih punya video tidak perlu dialog konfirmasi hapus —
        // ia memang tidak dapat dihapus. Menampilkan "yakin ingin menghapus?"
        // lalu menolaknya sesudah ditekan adalah cara tercepat membuat orang
        // mengira aplikasinya rusak.
        if (!item.canDelete) {
          await _tawarkanNonaktif(context, ref);
          return;
        }

        final yakin = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(t.shopsDeleteTitle),
            content: Text(t.shopsDeleteBody(shop.shopName)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(t.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                child: Text(t.commonDelete),
              ),
            ],
          ),
        );
        if (yakin != true || !context.mounted) return;

        final hasil = await vm.delete(item);
        if (!context.mounted) return;

        switch (hasil) {
          case ShopDeleted():
            messenger.showSnackBar(
              SnackBar(content: Text(t.shopsDeleted(shop.shopName))),
            );
          case ShopHasVideos():
            await _tawarkanNonaktif(context, ref);
          case ShopDeleteFailed(:final failure):
            messenger.showSnackBar(
              SnackBar(content: Text(context.failureMessage(failure))),
            );
        }
    }
  }

  /// Bab 9.5 — *"Toko ini memiliki 240 video. Nonaktifkan toko alih-alih
  /// menghapusnya."* beserta tombol yang langsung melakukannya.
  Future<void> _tawarkanNonaktif(BuildContext context, WidgetRef ref) async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final vm = ref.read(shopsViewModelProvider.notifier);
    final shop = item.shop;

    final nonaktifkan = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.shopsCannotDeleteTitle),
        content: Text(t.shopsCannotDeleteBody(item.videoCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.commonClose),
          ),
          if (shop.isActive)
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(t.shopsDeactivate),
            ),
        ],
      ),
    );

    if (nonaktifkan != true) return;

    final failure = await vm.setActive(shop.id, active: false);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failure != null
              ? context.failureMessage(failure)
              : t.shopsDeactivated(shop.shopName),
        ),
      ),
    );
  }
}
