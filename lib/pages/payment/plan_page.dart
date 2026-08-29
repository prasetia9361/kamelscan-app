import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/tier_config.dart';
import '../../core/models/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_state_views.dart';
import '../../core/widgets/failure_messages.dart';
import '../../navigation/route_names.dart';
import 'plan_view_model.dart';
import 'widgets/promo_field.dart';

/// Halaman Pembayaran — pilih paket (Bab 9.8, Owner saja).
class PlanPage extends ConsumerWidget {
  const PlanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(planViewModelProvider);
    final vm = ref.read(planViewModelProvider.notifier);

    return SafeArea(
      child: switch (async) {
        AsyncValue(:final value?) => _Body(data: value),
        AsyncError(:final error) =>
          AppErrorView(failure: error, onRetry: vm.refresh),
        _ => const AppListSkeleton(),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.data});

  final PlanData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final vm = ref.read(planViewModelProvider.notifier);

    return RefreshIndicator(
      onRefresh: vm.refresh,
      child: ListView(
        // 88 dp bawah: tombol Rekam mengambang menumpang di atas isi halaman.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          if (data.pending != null) ...[
            _PendingBanner(),
            const SizedBox(height: 16),
          ],

          Text(t.paymentChoosePlan, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),

          // Dua kartu berdampingan, bukan bertumpuk. Membandingkan dua paket
          // menuntut keduanya terlihat sekaligus; kartu bertumpuk memaksa
          // pembacanya mengingat isi kartu pertama sambil menggulir.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _PlanCard(data: data, plan: TierPlan.standar)),
                const SizedBox(width: 12),
                Expanded(child: _PlanCard(data: data, plan: TierPlan.pro)),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const PromoField(),

          const SizedBox(height: 20),
          _BillSummary(data: data),

          const SizedBox(height: 20),
          _PayButton(data: data),
        ],
      ),
    );
  }
}

/// Tagihan yang belum tuntas selalu berdiri paling atas.
///
/// Owner yang lupa pernah menekan Bayar akan membuat tagihan kedua, mentransfer
/// nominal yang berbeda dari tagihan pertama, dan pembayarannya tidak akan
/// cocok dengan satu pun di antaranya.
class _PendingBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return Card(
      margin: EdgeInsets.zero,
      color: colors.warning.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pending_actions_rounded,
                    size: 20, color: colors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(t.paymentPendingTitle,
                      style: theme.textTheme.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(t.paymentPendingBody, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => context.push(Routes.checkout),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(t.paymentContinue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.data, required this.plan});

  final PlanData data;
  final TierPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    final tier = data.catalog.of(plan);
    final aktif = data.isActivePlan(plan);
    final dipilih = data.selected == plan;
    final gambar = data.banners['${plan.wire}_image_url'];

    return Card(
      margin: EdgeInsets.zero,
      elevation: dipilih ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: aktif
              ? colors.success
              : dipilih
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
          width: aktif || dipilih ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: aktif
            ? null
            : () => ref.read(planViewModelProvider.notifier).select(plan),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PlanIllustration(plan: plan, imageUrl: gambar),
              const SizedBox(height: 12),

              Text(
                plan == TierPlan.pro ? t.planPro : t.planStandar,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),

              // Harga memakai baris tersendiri dan ukuran besar: inilah angka
              // yang dicari orang saat membuka halaman ini (Bab 9.10 — angka
              // penting minimal 20 sp).
              Text(
                Formatters.currency(tier.price),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                t.paymentPerMonth,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 12),
              ..._fitur(context, tier),

              const SizedBox(height: 14),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: aktif
                    ? OutlinedButton(
                        onPressed: null,
                        child: Text(t.paymentActivePlan),
                      )
                    : dipilih
                        ? FilledButton(
                            onPressed: null,
                            child: Text(t.paymentSelected),
                          )
                        : FilledButton.tonal(
                            onPressed: () => ref
                                .read(planViewModelProvider.notifier)
                                .select(plan),
                            child: Text(t.paymentChoosePackage),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _fitur(BuildContext context, TierConfig tier) {
    final t = context.l10n;
    return [
      _Feature(text: t.planFeatureSeconds(tier.maxVideoSeconds)),
      _Feature(text: t.planFeatureRetention(tier.retentionDays)),
      _Feature(text: t.planFeatureTokens(tier.monthlyTokens)),
      _Feature(
        text: tier.hasUnlimitedPackers
            ? t.planFeaturePackersUnlimited
            : t.planFeaturePackers(tier.maxPackers),
      ),
    ];
  }
}

/// Gambar kartu paket dari `platform_settings.banner_payment`.
///
/// Kosong sampai desainer mengisinya, jadi selalu ada bentuk cadangan — kartu
/// dengan ruang gambar kosong terlihat seperti gambar yang gagal dimuat.
class _PlanIllustration extends StatelessWidget {
  const _PlanIllustration({required this.plan, this.imageUrl});

  final TierPlan plan;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final warna = plan == TierPlan.pro ? colors.packing : theme.colorScheme.primary;

    final cadangan = Container(
      height: 64,
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        plan == TierPlan.pro
            ? Icons.workspace_premium_rounded
            : Icons.inventory_2_rounded,
        size: 32,
        color: warna,
      ),
    );

    if (imageUrl == null || imageUrl!.isEmpty) return cadangan;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl!,
        height: 64,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => cadangan,
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.text});

  final String text;

  /// ⚠️ Parameter `included` dibuang 29 Agustus 2026 bersama satu-satunya
  /// baris yang memakainya (watermark logo kustom). Sisa fitur seluruhnya
  /// berupa ANGKA yang berbeda antar paket — detik, hari retensi, jumlah
  /// token, jumlah packer — bukan fitur yang ada-atau-tidak.
  ///
  /// Bila kelak ada lagi fitur yang hanya dimiliki satu paket, kembalikan
  /// parameternya: menampilkannya sebagai baris tercoret jauh lebih jelas
  /// daripada menghilangkannya, karena perbedaan antar paket justru yang
  /// paling ingin dilihat pembacanya.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_rounded, size: 16, color: colors.success),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillSummary extends StatelessWidget {
  const _BillSummary({required this.data});

  final PlanData data;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    Widget baris(String label, String nilai, {bool tebal = false, Color? warna}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: tebal
                      ? theme.textTheme.titleSmall
                      : theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                nilai,
                style: (tebal
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(
                  fontWeight: tebal ? FontWeight.w700 : null,
                  color: warna,
                ),
              ),
            ],
          ),
        );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            baris(t.billingSubtotal, Formatters.currency(data.subtotal)),
            if (data.discount > 0)
              baris(
                t.billingDiscount,
                '− ${Formatters.currency(data.discount)}',
                warna: colors.success,
              ),
            const Divider(height: 18),
            baris(t.billingTotal, Formatters.currency(data.total), tebal: true),
          ],
        ),
      ),
    );
  }
}

class _PayButton extends ConsumerStatefulWidget {
  const _PayButton({required this.data});

  final PlanData data;

  @override
  ConsumerState<_PayButton> createState() => _PayButtonState();
}

class _PayButtonState extends ConsumerState<_PayButton> {
  bool _sedangKirim = false;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final data = widget.data;

    // Tidak ada satu pun metode pembayaran yang hidup — biasanya karena daftar
    // rekening di `platform_settings` masih kosong. Tombol Bayar yang tetap
    // menyala akan membawa Owner ke halaman instruksi transfer tanpa nomor
    // rekening.
    if (data.methods.hasNoMethod) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.paymentNoMethodTitle,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(t.paymentNoMethodBody,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: _sedangKirim || data.pending != null ? null : _bayar,
        icon: _sedangKirim
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.lock_outline_rounded, size: 18),
        label: Text('${t.paymentPay} · ${Formatters.currency(data.total)}'),
      ),
    );
  }

  Future<void> _bayar() async {
    setState(() => _sedangKirim = true);

    final messenger = ScaffoldMessenger.of(context);
    final (tagihan, failure) =
        await ref.read(planViewModelProvider.notifier).createBill();

    if (!mounted) return;
    setState(() => _sedangKirim = false);

    if (tagihan == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failure == null
                ? context.l10n.errorUnknown
                : context.failureMessage(failure),
          ),
        ),
      );
      return;
    }

    await context.push(Routes.checkout);
  }
}
