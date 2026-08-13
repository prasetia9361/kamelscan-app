import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';
import '../utils/app_failure.dart';
import 'failure_messages.dart';

/// Komponen bersama untuk empat kondisi wajib setiap layar berdata:
/// **loading, error, kosong, berisi** (Bab 3.4 & Bab 9.10).
///
/// Layar yang hanya menangani kondisi "berisi" akan ditolak saat review.

/// Skeleton shimmer — Bab 9.10 melarang spinner di tengah layar.
class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({super.key, this.itemCount = 6, this.itemHeight = 88});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Shimmer.fromColors(
      baseColor: colors.shimmerBase,
      highlightColor: colors.shimmerHighlight,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Container(
          height: itemHeight,
          decoration: BoxDecoration(
            color: colors.shimmerBase,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// Tampilan error: ikon, kalimat berbahasa manusia, tombol *Coba lagi*.
///
/// ⚠️ Bab 9.10 — pesan mentah server tidak pernah ditampilkan. Teks datang dari
/// `AppFailure.messageKey` yang diterjemahkan di sini.
class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, required this.failure, this.onRetry});

  /// Menerima `Object` karena `AsyncValue.error` tidak bertipe.
  final Object failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = failure is AppFailure
        ? failure as AppFailure
        : AppFailure.unknown(failure);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(f.kind), size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              context.failureMessage(f),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (onRetry != null && f.isRetryable) ...[
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(context.l10nRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(FailureKind kind) => switch (kind) {
        FailureKind.network => Icons.wifi_off_rounded,
        FailureKind.auth => Icons.lock_outline_rounded,
        FailureKind.permission => Icons.block_rounded,
        FailureKind.notFound => Icons.search_off_rounded,
        FailureKind.quota ||
        FailureKind.subscriptionInactive =>
          Icons.workspace_premium_outlined,
        FailureKind.devicePermission => Icons.perm_device_information_outlined,
        _ => Icons.error_outline_rounded,
      };
}

/// Tampilan kosong: ilustrasi + ajakan bertindak (Bab 9.10).
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
