import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/packer_summary.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../navigation/route_names.dart';
import 'packers_view_model.dart';
import 'widgets/add_packer_sheet.dart';
import 'widgets/packer_credentials_dialog.dart';

/// Kelola Akun Packer (Bab 9.6 — Owner saja).
class PackersPage extends ConsumerWidget {
  const PackersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final async = ref.watch(packersViewModelProvider);
    final vm = ref.read(packersViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(t.accountManagePackers)),
      body: switch (async) {
        AsyncValue(:final value?) => _Body(items: value),
        AsyncError(:final error) =>
          AppErrorView(failure: error, onRetry: vm.refresh),
        _ => const AppListSkeleton(),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.items});

  final List<PackerSummary> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final session = ref.watch(sessionProvider).value;
    final vm = ref.read(packersViewModelProvider.notifier);
    if (session == null) return const SizedBox.shrink();

    final tier = session.tier;
    final bolehTambah = tier.canAddPacker(items.length);

    return RefreshIndicator(
      onRefresh: vm.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _KuotaCard(
            terpakai: items.length,
            maksimal: tier.maxPackers,
            bolehTambah: bolehTambah,
          ),
          const SizedBox(height: 16),

          if (items.isEmpty)
            AppEmptyState(
              icon: Icons.groups_outlined,
              title: t.packersEmptyTitle,
              message: t.packersEmptyBody,
            )
          else
            for (final item in items) ...[
              _PackerTile(item: item),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

/// Bab 9.6 — *"3 dari 5 akun packer terpakai"* (Standar) atau *"Tidak
/// terbatas"* (Pro), beserta tombol tambah.
class _KuotaCard extends ConsumerWidget {
  const _KuotaCard({
    required this.terpakai,
    required this.maksimal,
    required this.bolehTambah,
  });

  final int terpakai;
  final int maksimal;
  final bool bolehTambah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final takTerbatas = maksimal < 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.groups_rounded, size: 20, color: colors.packing),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    takTerbatas
                        ? t.packersQuotaUnlimited(terpakai)
                        : t.packersQuotaUsed(terpakai, maksimal),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),

            if (!takTerbatas) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: maksimal <= 0 ? 0 : (terpakai / maksimal).clamp(0, 1),
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(
                    bolehTambah ? colors.success : colors.warning,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Bab 9.6 — tombol dinonaktifkan saat kuota penuh, **disertai
            // ajakan upgrade**. Tombol mati tanpa penjelasan adalah cara
            // tercepat membuat Owner mengira aplikasinya rusak.
            if (bolehTambah)
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => _tambah(context, ref),
                  icon: const Icon(Icons.person_add_alt_rounded),
                  label: Text(t.packersAdd),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: colors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.packersQuotaFull,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => context.push(Routes.payment),
                      icon: const Icon(Icons.arrow_upward_rounded),
                      label: Text(t.commonUpgrade),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _tambah(BuildContext context, WidgetRef ref) async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final hasil = await showModalBottomSheet<AddPackerResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddPackerSheet(),
    );
    if (hasil == null || !context.mounted) return;

    final (kredensial, failure) = await ref
        .read(packersViewModelProvider.notifier)
        .create(
          email: hasil.email,
          fullName: hasil.fullName,
          shopIds: hasil.shopIds,
        );

    if (!context.mounted) return;

    if (failure != null || kredensial == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failure == null
                ? t.errorUnknown
                : context.failureMessage(failure),
          ),
        ),
      );
      return;
    }

    // 🔴 Bab 6.7 — password sementara hanya ada sekali. Dialognya ditampilkan
    // segera dan sengaja tidak dapat ditutup dengan mengetuk di luar.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PackerCredentialsDialog(credentials: kredensial),
    );
  }
}

class _PackerTile extends ConsumerWidget {
  const _PackerTile({required this.item});

  final PackerSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final user = item.user;
    final aktif = user.isActive;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Opacity(
              opacity: aktif ? 1 : 0.45,
              child: ProfileAvatar(
                initials: user.initials,
                seed: user.id,
                avatarUrl: user.avatarUrl,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: aktif
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _StatusChip(active: aktif),
                      Text(
                        t.packersVideoCount(item.videoCount),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (item.shopNames.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      t.packersShops(item.shopNames.join(', ')),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      t.packersNoShop,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colors.warning),
                    ),
                  ],
                ],
              ),
            ),
            _PackerMenu(item: item),
          ],
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

enum _PackerAction { resetPassword, toggleActive, delete }

class _PackerMenu extends ConsumerWidget {
  const _PackerMenu({required this.item});

  final PackerSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;
    final aktif = item.user.isActive;

    return PopupMenuButton<_PackerAction>(
      tooltip: t.packersMenuTooltip,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _PackerAction.resetPassword,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_reset_rounded),
            title: Text(t.packersResetPassword),
          ),
        ),
        PopupMenuItem(
          value: _PackerAction.toggleActive,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              aktif ? Icons.person_off_outlined : Icons.person_add_alt_rounded,
            ),
            title: Text(aktif ? t.shopsDeactivate : t.shopsActivate),
          ),
        ),
        PopupMenuItem(
          value: _PackerAction.delete,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline_rounded, color: colors.danger),
            title: Text(t.commonDelete, style: TextStyle(color: colors.danger)),
          ),
        ),
      ],
      onSelected: (aksi) => _jalankan(context, ref, aksi),
    );
  }

  Future<void> _jalankan(
    BuildContext context,
    WidgetRef ref,
    _PackerAction aksi,
  ) async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final vm = ref.read(packersViewModelProvider.notifier);
    final user = item.user;

    switch (aksi) {
      case _PackerAction.resetPassword:
        final failure = await vm.sendPasswordReset(user.email);
        if (!context.mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              failure != null
                  ? context.failureMessage(failure)
                  : t.packersResetSent(user.email),
            ),
          ),
        );

      case _PackerAction.toggleActive:
        final failure = await vm.setActive(user.id, active: !user.isActive);
        if (!context.mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              failure != null
                  ? context.failureMessage(failure)
                  : (user.isActive
                      ? t.packersDeactivated(user.fullName)
                      : t.packersActivated(user.fullName)),
            ),
          ),
        );

      case _PackerAction.delete:
        // Akun yang sudah pernah merekam tidak perlu dialog konfirmasi hapus —
        // ia memang tidak dapat dihapus. Bertanya lalu menolak sesudah ditekan
        // membuat orang mengira aplikasinya rusak.
        if (!item.canDelete) {
          await _tawarkanNonaktif(context, ref);
          return;
        }

        final yakin = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(t.packersDeleteTitle),
            content: Text(t.packersDeleteBody(user.fullName)),
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
          case PackerDeleted():
            messenger.showSnackBar(
              SnackBar(content: Text(t.packersDeleted(user.fullName))),
            );
          case PackerHasVideos():
            await _tawarkanNonaktif(context, ref);
          case PackerDeleteFailed(:final failure):
            messenger.showSnackBar(
              SnackBar(content: Text(context.failureMessage(failure))),
            );
        }
    }
  }

  /// Bab 9.6 — penghapusan ditolak, arahkan ke *Nonaktifkan*.
  Future<void> _tawarkanNonaktif(BuildContext context, WidgetRef ref) async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final vm = ref.read(packersViewModelProvider.notifier);
    final user = item.user;

    final nonaktifkan = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.packersCannotDeleteTitle),
        content: Text(t.packersCannotDeleteBody(item.videoCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.commonClose),
          ),
          if (user.isActive)
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(t.shopsDeactivate),
            ),
        ],
      ),
    );
    if (nonaktifkan != true) return;

    final failure = await vm.setActive(user.id, active: false);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failure != null
              ? context.failureMessage(failure)
              : t.packersDeactivated(user.fullName),
        ),
      ),
    );
  }
}
