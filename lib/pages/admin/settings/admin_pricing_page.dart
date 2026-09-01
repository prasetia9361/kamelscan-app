import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/tier_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import 'admin_settings_view_model.dart';

/// Pengaturan harga & paket (Bab 11.3).
///
/// 🔴 Sepuluh angka di halaman ini berlaku bagi **seluruh pelanggan
/// sekaligus**, dan salah satunya yang keliru tidak menghasilkan galat apa pun
/// — ia hanya membuat setiap perangkat membaca batas yang berbeda dari yang
/// dimaksud. Karena itu setiap kolom punya satuannya tertulis, dan dua
/// kolom yang paling berbahaya (harga dan jumlah packer) punya keterangan
/// tersendiri di bawahnya.
///
/// ⚠️ Sampai 29 Agustus 2026 kesepuluh angka ini disunting sebagai JSON lewat
/// Supabase Dashboard. Satu tanda kutip yang hilang di sana merusak baris yang
/// dibaca setiap perangkat, dan tidak ada yang memeriksanya sebelum tersimpan.
class AdminPricingPage extends ConsumerStatefulWidget {
  const AdminPricingPage({super.key});

  @override
  ConsumerState<AdminPricingPage> createState() => _AdminPricingPageState();
}

class _AdminPricingPageState extends ConsumerState<AdminPricingPage> {
  /// Dua kolom mulai selebar ini; di bawahnya menumpuk.
  static const double duaKolom = 900;

  final _kolom = <String, TextEditingController>{};
  bool _sedang = false;
  bool _terisi = false;

  @override
  void dispose() {
    for (final c in _kolom.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _c(String kunci, String awal) =>
      _kolom.putIfAbsent(kunci, () => TextEditingController(text: awal));

  /// Mengisi kolom sekali saja, saat data pertama tiba.
  ///
  /// 🔴 Tanpa penjaga `_terisi`, setiap penyegaran menimpa apa yang sedang
  /// diketik Admin — termasuk penyegaran yang dipicu oleh penyimpanan itu
  /// sendiri. Cacat semacam ini terasa seperti papan ketik yang rusak.
  void _isiSekali(AdminPricingData data) {
    if (_terisi) return;
    _terisi = true;
    for (final tier in data.catalog.semua) {
      final p = tier.plan.wire;
      _c('$p.price', '${tier.price.toInt()}');
      _c('$p.max_video_seconds', '${tier.maxVideoSeconds}');
      _c('$p.retention_days', '${tier.retentionDays}');
      _c('$p.max_packers', '${tier.maxPackers}');
      _c('$p.monthly_tokens', '${tier.monthlyTokens}');
    }
    _c(
      'infra_cost',
      data.infraCost == null ? '' : '${data.infraCost!.toInt()}',
    );
  }

  int _int(String kunci, int cadangan) =>
      int.tryParse(_kolom[kunci]?.text.trim() ?? '') ?? cadangan;

  TierConfig _bacaTier(TierConfig asal) {
    final p = asal.plan.wire;
    return asal.copyWith(
      price: _int('$p.price', asal.price.toInt()),
      maxVideoSeconds: _int('$p.max_video_seconds', asal.maxVideoSeconds),
      retentionDays: _int('$p.retention_days', asal.retentionDays),
      maxPackers: _int('$p.max_packers', asal.maxPackers),
      monthlyTokens: _int('$p.monthly_tokens', asal.monthlyTokens),
    );
  }

  Future<void> _simpan(AdminPricingData data) async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final biayaTeks = _kolom['infra_cost']?.text.trim() ?? '';

    // 🔴 Kolom kosong berarti "belum diisi" (null), BUKAN nol. Nol membuat
    // Dasbor Platform menulis margin = seluruh pendapatan, yaitu kalimat
    // "seluruh pendapatan adalah keuntungan" (migrasi 30 keputusan 3).
    final biaya = biayaTeks.isEmpty ? null : num.tryParse(biayaTeks);

    final tiersBaru = data.catalog.semua.map(_bacaTier).toList();

    final yakin = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t.adminPricingSaveTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ⚠️ Bab 11.3 — perubahan harga TIDAK berlaku surut. Dikatakan di
            // sini supaya Admin tidak menahan diri mengubah harga karena takut
            // menagih ulang pelanggan lama.
            Text(t.adminPricingSaveBody),
            const SizedBox(height: 10),
            Text(
              t.adminPricingLimitsImmediate,
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
            child: Text(t.commonSave),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    setState(() => _sedang = true);
    final gagal = await ref
        .read(adminPricingViewModelProvider.notifier)
        .save(tiers: tiersBaru, infraCost: biaya);
    if (!mounted) return;
    setState(() => _sedang = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          gagal == null ? t.adminSettingsSaved : context.failureMessage(gagal),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final async = ref.watch(adminPricingViewModelProvider);
    final vm = ref.read(adminPricingViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(t.adminPricingTitle)),
      body: async.when(
        loading: () => const AppListSkeleton(itemCount: 2, itemHeight: 260),
        error: (error, _) => AppErrorView(failure: error, onRetry: vm.refresh),
        data: (data) {
          _isiSekali(data);

          return LayoutBuilder(
            builder: (context, batas) {
              // Dibangun dari katalog, bukan disebut satu per satu — paket
              // baru cukup menambah nilai enum, tanpa menyentuh berkas ini.
              final kartu = [
                for (final tier in data.catalog.semua)
                  _KartuTier(
                    tier: tier,
                    kolom: _c,
                    label: labelTier(t, tier.plan),
                  ),
              ];

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // 🔴 JANGAN menyebut kartu[0] dan kartu[1] satu per satu.
                  // Sampai 1 September 2026 baris inilah yang melakukannya,
                  // tepat di bawah komentar yang menjanjikan sebaliknya —
                  // sehingga paket Bisnis yang sudah ada di katalog TIDAK
                  // PERNAH digambar, di lebar mana pun. Dilaporkan Product
                  // Owner setelah melihat Admin > Harga & Paket masih dua
                  // kartu padahal halaman pembayaran pelanggan sudah tiga.
                  //
                  // Tidak ada satu pun galat: daftarnya memang berisi tiga,
                  // hanya yang ketiga tidak pernah diminta.
                  ...(() {
                    if (batas.maxWidth < duaKolom) {
                      return <Widget>[
                        for (var i = 0; i < kartu.length; i++) ...[
                          if (i > 0) const SizedBox(height: 16),
                          kartu[i],
                        ],
                      ];
                    }
                    final baris = <Widget>[];
                    for (var i = 0; i < kartu.length; i += 2) {
                      if (i > 0) baris.add(const SizedBox(height: 16));
                      baris.add(
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // `Expanded` di kedua sisi — kartu berisi tombol
                            // bertema yang menuntut lebar tak terhingga.
                            Expanded(child: kartu[i]),
                            const SizedBox(width: 16),
                            // Baris terakhir yang ganjil diisi ruang kosong,
                            // supaya kartunya selebar kartu di baris atasnya
                            // dan tidak melar sendirian.
                            if (i + 1 < kartu.length)
                              Expanded(child: kartu[i + 1])
                            else
                              const Expanded(child: SizedBox.shrink()),
                          ],
                        ),
                      );
                    }
                    return baris;
                  })(),

                  const SizedBox(height: 16),
                  _KartuBiaya(controller: _c('infra_cost', '')),

                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _sedang ? null : () => _simpan(data),
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: Text(t.commonSave),
                    ),
                  ),
                  if (_sedang) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _KartuTier extends StatelessWidget {
  const _KartuTier({
    required this.tier,
    required this.kolom,
    required this.label,
  });

  final TierConfig tier;
  final TextEditingController Function(String, String) kolom;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final p = tier.plan.wire;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.titleMedium),
            const SizedBox(height: 14),
            AngkaField(
              controller: kolom('$p.price', '${tier.price.toInt()}'),
              label: t.adminPricingPrice,
              helper: t.adminPricingPriceHelp,
            ),
            const SizedBox(height: 12),
            AngkaField(
              controller: kolom(
                '$p.max_video_seconds',
                '${tier.maxVideoSeconds}',
              ),
              label: t.adminPricingVideoSeconds,
            ),
            const SizedBox(height: 12),
            AngkaField(
              controller: kolom('$p.retention_days', '${tier.retentionDays}'),
              label: t.adminPricingRetentionDays,
              helper: t.adminPricingRetentionHelp,
            ),
            const SizedBox(height: 12),
            AngkaField(
              controller: kolom('$p.max_packers', '${tier.maxPackers}'),
              label: t.adminPricingMaxPackers,
              // 🔴 −1 berarti tanpa batas, dan itu mustahil ditebak dari
              // kolom angka biasa. Tanpa keterangan ini, yang mengisinya akan
              // menulis angka besar seperti 999 — yang bekerja, tetapi
              // membuat aturan "tanpa batas" tidak pernah benar-benar ada.
              helper: t.adminPricingMaxPackersHelp,
              izinkanMinus: true,
            ),
            const SizedBox(height: 12),
            AngkaField(
              controller: kolom('$p.monthly_tokens', '${tier.monthlyTokens}'),
              label: t.adminPricingMonthlyTokens,
              helper: t.adminPricingTokensHelp,
            ),
          ],
        ),
      ),
    );
  }
}

class _KartuBiaya extends StatelessWidget {
  const _KartuBiaya({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.savings_outlined, size: 20, color: colors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.adminPricingInfraTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t.adminPricingInfraBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            AngkaField(
              controller: controller,
              label: t.adminPricingInfraLabel,
              // 🔴 Dikosongkan berarti "belum diisi", bukan nol. Nol membuat
              // Dasbor Platform menulis bahwa seluruh pendapatan adalah
              // keuntungan.
              helper: t.adminPricingInfraHelp,
            ),
          ],
        ),
      ),
    );
  }
}

/// Kolom angka bulat dengan satuannya tertulis di bawah.
///
/// 🔴 `FilteringTextInputFormatter` dipasang supaya papan ketik ponsel yang
/// tetap mengizinkan koma dan titik tidak menghasilkan `"99.000"` — yang
/// `int.tryParse` tolak diam-diam menjadi null, lalu jatuh ke nilai cadangan
/// tanpa memberi tahu siapa pun bahwa perubahannya tidak tersimpan.
class AngkaField extends StatelessWidget {
  const AngkaField({
    super.key,
    required this.controller,
    required this.label,
    this.helper,
    this.izinkanMinus = false,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;

  /// Hanya kolom "maksimal packer" yang memerlukannya (−1 = tanpa batas).
  final bool izinkanMinus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(signed: izinkanMinus),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          izinkanMinus ? RegExp(r'^-?\d*') : RegExp(r'\d*'),
        ),
      ],
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 3,
        isDense: true,
      ),
    );
  }
}
