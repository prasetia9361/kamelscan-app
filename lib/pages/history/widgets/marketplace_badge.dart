import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Penanda marketplace pada baris Riwayat (Bab 9.4 / 9.5), daftar Toko, petak
/// toko di layar Setup, dan form Tambah Toko.
///
/// Logo asli dipasang 31 Agustus 2026 atas keputusan Product Owner. Sebelumnya
/// dipakai huruf awal karena berkas logonya belum ada di repo dan pemakaian
/// merek dagang pihak lain perlu diputuskan lebih dulu; keputusan itu sudah
/// diambil dan berkasnya ada di `assets/marketplace/`.
///
/// 🔴 **Huruf awal tetap jalur normal, bukan cadangan darurat.** Marketplace
/// disimpan sebagai teks bebas (Bab 5.2) supaya marketplace baru tidak menuntut
/// migrasi — jadi nama di luar keenam ini memang wajar terjadi, "Lainnya" salah
/// satunya. Untuk nama tak dikenal badge kembali ke huruf awal di atas warna
/// [ColorScheme.outline].
///
/// Warna tint diambil dari palet, bukan warna merek aslinya, agar mode gelap
/// tetap terbaca dan §6 palet tidak dilanggar. Saat logo ada, tint diturunkan
/// 16% → 7% dan garis tepi 40% → 22%: logonya sudah berwarna penuh, dan tint
/// kuat di belakangnya membuat keduanya berebut perhatian.
class MarketplaceBadge extends StatelessWidget {
  const MarketplaceBadge({super.key, required this.marketName, this.size = 44});

  final String? marketName;
  final double size;

  /// Peta nama → aset. Tidak ada entri berarti pakai huruf awal.
  ///
  /// Kuncinya huruf kecil semua dan sudah dipangkas, sepadan dengan hasil
  /// `nama.toLowerCase()` di [build].
  ///
  /// ⚠️ Berkas Tokopedia **diganti** 1 September 2026. Yang dikirim pertama
  /// (sumber zonalogo.com) adalah gradien pudar, bukan warna merek solid —
  /// diukur pada badan tasnya: Shopee `#EE4D2D`, TikTok Shop `#4B555C`,
  /// Tokopedia `#94A582` abu-kehijauan — dan pada ukuran badge ia tidak
  /// terbaca di latar gelap maupun terang. Penggantinya dari Product Owner
  /// rata-rata `#4F7645`, hijau pekat seperti yang lain.
  ///
  /// Kalau kelak ada logo lain yang "hilang", ukur dulu warna badannya sebelum
  /// menduga berkasnya rusak.
  static const Map<String, String> _logos = {
    'shopee': 'assets/marketplace/shopee.png',
    'tokopedia': 'assets/marketplace/tokopedia.png',
    'tiktok shop': 'assets/marketplace/tiktok-shop.png',
    'tiktokshop': 'assets/marketplace/tiktok-shop.png',
    'lazada': 'assets/marketplace/lazada.png',
    'blibli': 'assets/marketplace/blibli.png',
    'bukalapak': 'assets/marketplace/bukalapak.png',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final scheme = Theme.of(context).colorScheme;
    final nama = (marketName ?? '').trim();
    final kunci = nama.toLowerCase();

    // Marketplace disimpan sebagai teks bebas (Bab 5.2) supaya yang baru tidak
    // memerlukan migrasi — jadi nama di luar daftar ini memang wajar terjadi,
    // bukan kesalahan data.
    final color = switch (kunci) {
      'shopee' => colors.warning,
      'tokopedia' => colors.success,
      'tiktok shop' || 'tiktokshop' => scheme.onSurface,
      'lazada' => colors.packing,
      'blibli' => colors.returnColor,
      'bukalapak' => colors.danger,
      _ => scheme.outline,
    };

    final logo = _logos[kunci];

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // ⚠️ Bidang putih di belakang logo sempat dicoba 1 September 2026 dan
        // **ditolak Product Owner**: petak putih terang di antara kartu gelap
        // menarik perhatian ke logonya, padahal yang dicari orang adalah nama
        // tokonya. Tint tetap.
        color: color.withValues(alpha: logo == null ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: logo == null ? 0.4 : 0.22),
        ),
      ),
      child: logo == null
          ? Text(
              nama.isEmpty ? '?' : nama.substring(0, 1).toUpperCase(),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w700),
            )
          // `contain` supaya logo tidak pernah terpotong, berapa pun [size].
          : Padding(
              padding: EdgeInsets.all(size * 0.2),
              child: Image.asset(logo, fit: BoxFit.contain),
            ),
    );
  }
}
