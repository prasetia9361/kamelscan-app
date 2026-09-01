import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/env.dart';
import '../../core/config/tier_config.dart';
import '../../core/models/enums.dart';
import '../../core/models/subscription.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_state_views.dart';
import '../../core/widgets/failure_messages.dart';
import '../../navigation/route_names.dart';
import 'payment_access.dart';
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
        AsyncError(:final error) => AppErrorView(
          failure: error,
          onRetry: vm.refresh,
        ),
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
            _PendingBanner(subscription: data.pending),
            const SizedBox(height: 16),
          ],

          // 🔴 Penolakan berdiri sama tinggi dengan tagihan yang menunggu.
          // Keduanya tidak pernah muncul bersamaan: tagihan baru menjawab
          // penolakan yang lama.
          if (data.rejected != null) ...[
            _RejectedBanner(subscription: data.rejected!),
            const SizedBox(height: 16),
          ],

          Text(t.paymentChoosePlan, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),

          // Berdampingan bila muat, bertumpuk bila tidak.
          //
          // 🔴 Sejak paket ketiga ada, tiga kartu berdampingan TIDAK MUAT di
          // lebar HP. Memaksakannya menghasilkan RenderFlex overflow — bentuk
          // yang sudah dua kali pecah di proyek ini (M.12 dan M.17), dan yang
          // tidak pernah terlihat pada emulator lebar.
          //
          // Membandingkan paket memang lebih enak bila semuanya terlihat
          // sekaligus, tetapi kartu yang terpotong tidak dapat dibandingkan
          // sama sekali.
          LayoutBuilder(
            builder: (context, batas) {
              final kartu = [
                for (final plan in TierPlan.values)
                  _PlanCard(data: data, plan: plan),
              ];

              if (batas.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < kartu.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      kartu[i],
                    ],
                  ],
                );
              }

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < kartu.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: kartu[i]),
                    ],
                  ],
                ),
              );
            },
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

/// Tombol membatalkan tagihan yang sedang berjalan (Bab 12.2).
///
/// 🔴 Selalu bertanya lebih dulu, dan pertanyaannya menyebut **nominalnya**.
/// Yang ditekan orang adalah tombol kecil di sudut spanduk; satu-satunya
/// penjagaan terhadap membatalkan tagihan yang sebenarnya masih ia butuhkan
/// adalah melihat angkanya tertulis ulang sebelum menekan.
class _TombolBatalkan extends ConsumerStatefulWidget {
  const _TombolBatalkan({required this.subscription});

  final Subscription? subscription;

  @override
  ConsumerState<_TombolBatalkan> createState() => _TombolBatalkanState();
}

class _TombolBatalkanState extends ConsumerState<_TombolBatalkan> {
  bool _sedang = false;

  Future<void> _batalkan() async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final sub = widget.subscription;

    final yakin = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t.paymentCancelTitle),
        content: Text(
          t.paymentCancelBody(
            sub == null ? '-' : Formatters.currency(sub.amount),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(t.commonNo),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(d).colorScheme.error,
            ),
            child: Text(t.paymentCancelConfirm),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    setState(() => _sedang = true);
    final gagal = await ref
        .read(planViewModelProvider.notifier)
        .cancelPendingBill();
    if (!mounted) return;
    setState(() => _sedang = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          gagal == null ? t.paymentCancelled : context.failureMessage(gagal),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _sedang ? null : _batalkan,
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        icon: _sedang
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.cancel_outlined, size: 18),
        label: Text(t.paymentCancelBill),
      ),
    );
  }
}

/// Pembayaran yang ditolak Admin (Bab 11.7).
///
/// 🔴 Widget ini lahir dari cacat, bukan dari permintaan fitur. Sampai
/// 29 Agustus 2026 menolak pembayaran hanya mengubah status menjadi `failed`,
/// dan di layar ini akibatnya: spanduk "menunggu verifikasi" lenyap tanpa satu
/// kalimat pun yang menggantikannya. Owner yang uangnya sudah keluar melihat
/// halaman pilih paket biasa, seolah tagihannya tidak pernah ada.
///
/// ⚠️ Alasannya ditulis Admin dan ditampilkan **apa adanya**. Ia sudah dibatasi
/// 200 huruf saat ditulis, tetapi tetap dibungkus agar kalimat panjang tidak
/// merusak susunan kartunya.
class _RejectedBanner extends StatelessWidget {
  const _RejectedBanner({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final alasan = subscription.rejectionReason?.trim();

    return Card(
      margin: EdgeInsets.zero,
      color: colors.danger.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, size: 20, color: colors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.paymentRejectedTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Baris yang ditolak sebelum kolom alasannya ada memang tidak
            // punya isi. Kalimat penggantinya mengatakan itu apa adanya
            // alih-alih menampilkan ruang kosong.
            Text(
              alasan == null || alasan.isEmpty
                  ? t.paymentRejectedNoReason
                  : t.paymentRejectedReason(alasan),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            // Dikatakan apa adanya: uangnya tidak dikembalikan aplikasi.
            // Menyembunyikannya hanya menunda pertanyaan yang pasti datang.
            Text(
              t.paymentRejectedNext,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
  const _PendingBanner({required this.subscription});

  /// Tagihan yang sedang berjalan. Dibawa masuk, bukan dibaca ulang dari
  /// provider — spanduknya harus menjelaskan tagihan YANG ITU, dan cara
  /// menyelesaikannya berbeda antara transfer manual dan Midtrans.
  final Subscription? subscription;

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
                Icon(
                  Icons.pending_actions_rounded,
                  size: 20,
                  color: colors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.paymentPendingTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(t.paymentPendingBody, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),

            // 🔴 Tagihan Midtrans TIDAK boleh diarahkan ke halaman Checkout.
            //
            // Halaman itu berisi instruksi transfer bank: nomor rekening,
            // nominal unik, batas 24 jam. Untuk tagihan yang dibuat lewat
            // Midtrans, seluruh isinya salah — dan yang membacanya akan
            // mentransfer ke rekening manual untuk tagihan yang menunggu
            // pembayaran kartu. Uangnya masuk, tagihannya tetap menggantung.
            //
            // Sesi Snap tidak dapat dilanjutkan dari sini: `redirect_url`
            // hanya hidup sekali dan tidak disimpan di mana pun. Yang benar
            // adalah mengatakan keadaannya apa adanya.
            if (subscription?.paymentMethod == 'midtrans')
              Text(
                t.paymentPendingMidtrans,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            // 🔴 Di HP tombolnya tidak ada sama sekali — halaman Checkout
            // memang tidak terdaftar di sana (Bab 12.5). Menampilkannya lalu
            // mendarat di "halaman tidak ditemukan" jauh lebih buruk daripada
            // satu kalimat yang menjelaskan ke mana harus pergi.
            else if (PaymentAccess.canPayHere)
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => context.push(Routes.checkout),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(t.paymentContinue),
                ),
              )
            else
              Text(
                t.paymentContinueOnWeb,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

            // 🔴 Jalan keluar. Sampai 31 Agustus 2026 tidak ada satu pun,
            // dan satu tagihan yang ditinggalkan mengunci pelanggan tanpa
            // batas waktu — terjadi pada Product Owner sendiri, dari Kamis
            // sampai Minggu.
            //
            // Hanya muncul selama bukti transfer belum diunggah. Sesudah itu
            // hanya Admin yang boleh menutupnya, karena hanya Admin yang dapat
            // memeriksa mutasi rekening (migrasi 36).
            if (!(subscription?.isWaitingVerification ?? false)) ...[
              const SizedBox(height: 8),
              _TombolBatalkan(subscription: subscription),
            ],
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
        // 🔴 Paket yang sedang aktif TETAP dapat dipilih, dan itu bukan
        // kelalaian. Sampai 31 Agustus 2026 modelnya naik/turun paket,
        // sehingga membeli paket yang sedang berjalan memang tidak berarti
        // apa-apa dan tombolnya sengaja dimatikan.
        //
        // Migrasi 40 menggantinya dengan model akumulatif: beli lagi menambah
        // token DAN menambah sisa hari. Membeli paket yang sama justru menjadi
        // jalur isi-ulang yang paling sering dipakai — dan mematikannya
        // mengunci pelanggan yang sudah puas dengan paketnya.
        //
        // Dilaporkan Product Owner 1 September 2026: "owner tidak bisa beli
        // pada tier yang sama".
        onTap: () => ref.read(planViewModelProvider.notifier).select(plan),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PlanIllustration(plan: plan, imageUrl: gambar),
              const SizedBox(height: 12),

              Text(
                switch (plan) {
                  TierPlan.standar => t.planStandar,
                  TierPlan.pro => t.planPro,
                  TierPlan.bisnis => t.planBisnis,
                },
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
                // ⚠️ Paket aktif tidak lagi memakai tombol MATI. Ia tetap
                // dikenali — garis tepinya hijau dan tombolnya menyebut
                // "Paket aktif" — tetapi tetap dapat ditekan, karena membeli
                // ulang paket yang sama adalah perpanjangan yang sah sejak
                // model akumulatif berlaku (migrasi 40).
                child: dipilih
                    ? FilledButton(
                        onPressed: null,
                        child: Text(t.paymentSelected),
                      )
                    : FilledButton.tonal(
                        onPressed: () => ref
                            .read(planViewModelProvider.notifier)
                            .select(plan),
                        child: Text(
                          aktif
                              ? t.paymentActivePlanBuyAgain
                              : t.paymentChoosePackage,
                        ),
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
      _Feature(
        text: t.planFeatureDuration(labelDurasi(t, tier.maxVideoSeconds)),
      ),
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
    final warna = switch (plan) {
      TierPlan.standar => theme.colorScheme.primary,
      TierPlan.pro => colors.packing,
      TierPlan.bisnis => colors.danger,
    };

    final cadangan = Container(
      height: 64,
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        switch (plan) {
          TierPlan.standar => Icons.inventory_2_rounded,
          TierPlan.pro => Icons.workspace_premium_rounded,
          TierPlan.bisnis => Icons.rocket_launch_rounded,
        },
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
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
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

    Widget baris(
      String label,
      String nilai, {
      bool tebal = false,
      Color? warna,
    }) => Padding(
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
            style:
                (tebal
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
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final data = widget.data;

    // 🔴 Bab 12.5 — di HP pembayaran tidak diselesaikan di dalam aplikasi.
    //
    // Diperiksa PALING DULU, sebelum keadaan lain apa pun. Kalau metode
    // pembayaran kebetulan sedang kosong, yang perlu dibaca pengguna HP bukan
    // "belum ada metode pembayaran" — itu masalah yang tidak dapat ia
    // selesaikan dari sana, dan menyuruhnya menunggu sesuatu yang tidak akan
    // datang. Yang benar tetap: selesaikan di dasbor web.
    if (!PaymentAccess.canPayHere) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.open_in_browser_outlined,
                    size: 20,
                    color: colors.packing,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.paymentOnWebTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(t.paymentOnWebBody, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),

              // 🔴 Tombol yang membuka peramban, bukan sekadar alamat yang
              // dapat disalin.
              //
              // Pelanggan sedang memegang HP. Menyuruhnya mengetik
              // "kamelscan.com/app" di peramban berarti menambah satu langkah
              // yang mudah salah ketik, tepat pada langkah tempat ia hendak
              // membayar — dan setiap langkah tambahan di jalur uang adalah
              // pelanggan yang berhenti di tengah jalan.
              //
              // ⚠️ `externalApplication` disengaja, BUKAN WebView. Bab 12.5:
              // alur bayar yang berjalan di dalam aplikasi adalah bentuk yang
              // paling sering ditolak App Store. Alamatnya tetap ditulis utuh
              // di tombolnya supaya pelanggan tahu ke mana ia akan dibawa.
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final pesan = t.paymentOpenFailed;
                    final dibuka = await launchUrl(
                      Uri.parse('${Env.webAppBaseUrl}${Routes.payment}'),
                      mode: LaunchMode.externalApplication,
                    );
                    if (!dibuka) {
                      messenger.showSnackBar(SnackBar(content: Text(pesan)));
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(t.paymentOpenWebButton),
                ),
              ),
              const SizedBox(height: 6),
              // Alamatnya tetap dapat disalin, untuk yang ingin membukanya di
              // perangkat lain.
              SelectableText(
                'kamelscan.com/app',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
              Text(
                t.paymentNoMethodTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(
                t.paymentNoMethodBody,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    final nominal = Formatters.currency(data.total);
    final terkunci = _sedangKirim || data.pending != null;

    // 🔴 Kedua metode dapat hidup berdampingan (Bab 12.1), dan Admin yang
    // menentukan lewat `platform_settings.payment_methods`. Seluruh gunanya
    // adalah agar Midtrans dapat dinyalakan begitu verifikasi merchant selesai
    // — 5 sampai 14 hari kerja yang sepenuhnya di luar kendali tim — **tanpa
    // merilis aplikasi baru**.
    //
    // Karena itu susunannya mengikuti data, bukan ditulis mati: satu tombol
    // bila hanya satu metode hidup, dua tombol bila keduanya hidup.
    if (data.methods.midtransEnabled) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: terkunci ? null : _bayarMidtrans,
              icon: _sedangKirim
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bolt_rounded, size: 18),
              label: Text('${t.paymentPayInstant} · $nominal'),
            ),
          ),
          if (data.methods.canTransferManually) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: terkunci ? null : _bayar,
                icon: const Icon(Icons.account_balance_outlined, size: 18),
                label: Text(t.paymentPayManual),
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Dikatakan apa adanya: uangnya diproses pihak ketiga, dan
          // langganannya aktif sendiri tanpa menunggu siapa pun.
          Text(
            t.paymentInstantNote,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: terkunci ? null : _bayar,
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

  /// Membuka halaman pembayaran Snap (Bab 12.3).
  ///
  /// 🔴 Yang dibuka adalah `redirect_url` dari Midtrans — halaman Snap yang
  /// dihosting Midtrans sendiri, bukan jendela mengambang di dalam aplikasi.
  /// Dua alasan: Bab 12.5 (alur bayar di dalam aplikasi adalah bentuk yang
  /// paling sering ditolak toko aplikasi), dan karena halaman Snap milik
  /// Midtrans selalu mengikuti metode pembayaran terbaru tanpa kita rilis apa
  /// pun.
  ///
  /// ⚠️ Aktivasi langganan TIDAK terjadi saat pelanggan kembali ke sini.
  /// Halaman `finish` hanya menampilkan keadaan; yang melunaskan tagihan
  /// adalah webhook server-to-server (Bab 12.3 aturan 1), karena callback di
  /// sisi aplikasi mudah dipalsukan.
  /// Peringatan wajib saat pembelian MENURUNKAN paket (Bab 12.4).
  ///
  /// 🔴 `tier_plan` mengikuti pembelian terakhir, dua arah. Membeli paket yang
  /// lebih rendah sementara paket yang lebih tinggi masih berjalan akan
  /// memotong durasi maksimal rekam **seketika begitu pembayaran lunas** —
  /// dari 3 menit ke 30 detik, misalnya.
  ///
  /// Tanpa peringatan ini, packer yang biasa merekam dua menit tiba-tiba
  /// terpotong di tengah pekerjaan, dan tidak ada seorang pun di toko itu yang
  /// tahu apa yang berubah. Owner-nya sendiri tidak: yang ia tekan adalah
  /// tombol beli, bukan tombol ubah paket.
  ///
  /// ⚠️ Tokennya sendiri tidak berkurang — ia tetap ditambahkan seperti
  /// pembelian mana pun. Dikatakan di dialognya supaya kekhawatiran yang salah
  /// tidak menghentikan pembelian yang memang disengaja.
  Future<bool> _lanjutMeskiTurunPaket() async {
    final data = widget.data;

    // Selama uji coba belum ada paket yang benar-benar dibeli, jadi tidak ada
    // yang dapat turun.
    if (data.isTrial || !data.selected.lebihRendahDari(data.currentPlan)) {
      return true;
    }

    final t = context.l10n;
    final lama = labelDurasi(t, data.catalog.of(data.currentPlan).maxVideoSeconds);
    final baru = labelDurasi(t, data.catalog.of(data.selected).maxVideoSeconds);

    final jawab = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t.paymentDowngradeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.paymentDowngradeBody(lama, baru)),
            const SizedBox(height: 12),
            Text(
              t.paymentDowngradeSafe,
              style: Theme.of(d).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(t.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(t.paymentDowngradeConfirm),
          ),
        ],
      ),
    );

    return jawab ?? false;
  }

  Future<void> _bayarMidtrans() async {
    if (!await _lanjutMeskiTurunPaket()) return;
    if (!mounted) return;
    setState(() => _sedangKirim = true);

    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final (tagihan, gagal) = await ref
        .read(planViewModelProvider.notifier)
        .createMidtransBill();

    if (!mounted) return;
    setState(() => _sedangKirim = false);

    if (tagihan == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            gagal == null ? t.errorUnknown : context.failureMessage(gagal),
          ),
        ),
      );
      return;
    }

    // 🔴 Lingkungan Sandbox dikatakan SEBELUM halaman bayarnya terbuka.
    //
    // Halaman pembayaran sandbox terlihat persis seperti aslinya, lengkap
    // dengan pilihan bank dan kartu. Tidak ada yang lebih mahal daripada
    // menyangka sudah menerima uang yang tidak pernah masuk — dan itu baru
    // ketahuan saat rekeningnya diperiksa berhari-hari kemudian.
    if (!tagihan.isProduction) {
      final lanjut = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(t.paymentSandboxTitle),
          content: Text(t.paymentSandboxBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(t.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text(t.paymentSandboxConfirm),
            ),
          ],
        ),
      );
      if (lanjut != true || !mounted) return;
    }

    // `_self` pada web: pelanggan berpindah di tab yang sama, lalu Snap
    // mengembalikannya ke halaman ini setelah selesai. Membuka tab baru
    // membuat sebagian peramban memblokirnya sebagai popup, dan pelanggan
    // hanya melihat tombol yang seolah tidak melakukan apa-apa.
    final dibuka = await launchUrl(
      Uri.parse(tagihan.redirectUrl),
      webOnlyWindowName: '_self',
      mode: LaunchMode.platformDefault,
    );

    if (!dibuka && mounted) {
      messenger.showSnackBar(SnackBar(content: Text(t.paymentOpenFailed)));
    }
  }

  Future<void> _bayar() async {
    // Jalur transfer manual menempuh peringatan yang sama. Aturannya milik
    // pembeliannya, bukan milik metode pembayarannya.
    if (!await _lanjutMeskiTurunPaket()) return;
    if (!mounted) return;
    setState(() => _sedangKirim = true);

    final messenger = ScaffoldMessenger.of(context);
    final (tagihan, failure) = await ref
        .read(planViewModelProvider.notifier)
        .createBill();

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
