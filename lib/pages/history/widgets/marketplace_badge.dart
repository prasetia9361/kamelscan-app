import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Penanda marketplace pada baris Riwayat (Bab 9.4 / 9.5).
///
/// ⚠️ **Penampung sampai aset logo tersedia.** Acuan dari Product Owner
/// menampilkan logo Shopee sungguhan; berkas logonya belum ada di repo, dan
/// logo marketplace adalah merek dagang pihak lain yang pemakaiannya perlu
/// diputuskan lebih dulu. Sementara itu dipakai huruf awal di atas warna tetap
/// per marketplace — tetap dapat dibedakan sekilas dari jarak satu meja packing.
///
/// Warnanya diambil dari palet, bukan warna merek aslinya, agar mode gelap
/// tetap terbaca dan §6 palet tidak dilanggar.
class MarketplaceBadge extends StatelessWidget {
  const MarketplaceBadge({super.key, required this.marketName, this.size = 44});

  final String? marketName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final scheme = Theme.of(context).colorScheme;
    final nama = (marketName ?? '').trim();

    // Marketplace disimpan sebagai teks bebas (Bab 5.2) supaya yang baru tidak
    // memerlukan migrasi — jadi nama di luar daftar ini memang wajar terjadi,
    // bukan kesalahan data.
    final color = switch (nama.toLowerCase()) {
      'shopee' => colors.warning,
      'tokopedia' => colors.success,
      'tiktok shop' || 'tiktokshop' => scheme.onSurface,
      'lazada' => colors.packing,
      'blibli' => colors.returnColor,
      'bukalapak' => colors.danger,
      _ => scheme.outline,
    };

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        nama.isEmpty ? '?' : nama.substring(0, 1).toUpperCase(),
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
