import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../domain/quota_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';

/// AppColors adalah ThemeExtension, bukan kumpulan konstanta statis — warnanya
/// berbeda antara tema terang dan gelap, jadi harus diambil dari context.
AppColors _colors(BuildContext context) =>
    Theme.of(context).extension<AppColors>()!;

/// Tampilan kuota token dan masa langganan (Bab 7.3, 7.5, 7.6).
///
/// Keputusan kapan sesuatu muncul TIDAK dibuat di sini — semuanya berasal dari
/// [QuotaStatus] dan [SubscriptionStatus] yang sudah teruji. Berkas ini hanya
/// menggambar.

/// Chip di App Bar selama uji coba: *"Uji Coba · 62 video tersisa"* (Bab 7.5).
class TrialChip extends StatelessWidget {
  const TrialChip({required this.quota, super.key});

  final QuotaStatus quota;

  @override
  Widget build(BuildContext context) {
    if (!quota.isTrial) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final color = _colors(context).tokenIndicator(quota.ratio);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        AppL10n.of(context).trialChip(quota.balance),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: quota.level == QuotaLevel.normal ? scheme.onSurface : color,
            ),
      ),
    );
  }
}

/// Kartu saldo token di Beranda. Menampilkan `62 / 100` saat uji coba
/// (Bab 7.5) dan angka besar minimal 20 sp (Bab 9.10).
class TokenBalanceCard extends StatelessWidget {
  const TokenBalanceCard({
    required this.quota,
    this.onTap,
    super.key,
  });

  final QuotaStatus quota;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = _colors(context).tokenIndicator(quota.ratio);

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.confirmation_number_outlined,
                      size: 20, color: color),
                  const SizedBox(width: 8),
                  Text(
                    quota.isTrial ? t.trialQuotaLabel : t.tokenBalanceLabel,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    Formatters.number(quota.balance),
                    style: AppTextStyles.statNumber.copyWith(color: color),
                  ),
                  if (quota.quota > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '/ ${Formatters.number(quota.quota)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: quota.ratio,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spanduk Beranda saat kuota menipis atau habis (Bab 7.3).
///
/// Mengembalikan widget kosong bila belum perlu — pemanggil tidak perlu
/// memeriksa apa pun.
class QuotaBanner extends StatelessWidget {
  const QuotaBanner({required this.quota, this.onAction, super.key});

  final QuotaStatus quota;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final key = quota.bannerKey;
    if (key == null) return const SizedBox.shrink();

    final t = AppL10n.of(context);
    final message = switch (key) {
      'trialLowBanner' => t.trialLowBanner(quota.balance),
      'trialExhaustedBanner' => t.trialExhaustedBanner,
      'quotaLowBanner' => t.quotaLowBanner(quota.balance),
      _ => t.quotaExhaustedBanner,
    };

    return _Banner(
      message: message,
      color: _colors(context).tokenIndicator(quota.ratio),
      icon: quota.isExhausted
          ? Icons.block
          : Icons.warning_amber_rounded,
      actionLabel: t.commonUpgrade,
      onAction: onAction,
    );
  }
}

/// Peringatan sebelum langganan berakhir (Bab 7.6 — H-7, H-3, H-1).
///
/// ⚠️ Bab 7.6 menegaskan peringatan ini **wajib ada** meski tidak ada masa
/// tenggang: mengunci pelanggan tanpa peringatan adalah cara tercepat
/// kehilangan mereka.
class SubscriptionExpiryBanner extends StatelessWidget {
  const SubscriptionExpiryBanner({
    required this.subscription,
    this.onAction,
    super.key,
  });

  final SubscriptionStatus subscription;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    if (!subscription.shouldWarnExpiry) return const SizedBox.shrink();
    final days = subscription.daysRemaining ?? 0;
    final t = AppL10n.of(context);

    return _Banner(
      message: days <= 0
          ? t.subscriptionExpiryToday
          : t.subscriptionExpiryWarning(days),
      color: days <= 1 ? _colors(context).danger : _colors(context).warning,
      icon: Icons.schedule,
      actionLabel: t.commonRenew,
      onAction: onAction,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.color,
    required this.icon,
    required this.actionLabel,
    this.onAction,
  });

  final String message;
  final Color color;
  final IconData icon;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
