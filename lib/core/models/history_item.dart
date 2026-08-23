import 'package_video.dart';

/// Satu baris Riwayat: video beserta konteks yang dibaca dari tabel lain
/// (Bab 9.4).
///
/// Dipisahkan dari [PackageVideo] dengan sengaja. [PackageVideo] adalah
/// cerminan satu tabel dan dipakai juga di jalur unggah; menempelkan nama toko
/// dan nama perekam ke sana berarti kolom yang tidak pernah ada di tabelnya
/// ikut terbawa ke tempat-tempat yang tidak membutuhkannya.
///
/// Nama toko dan nama perekam datang dari **embedding PostgREST**, bukan dari
/// permintaan terpisah per baris. Riwayat memuat 20 baris sekali jalan, dan
/// 20 permintaan tambahan pada jaringan gudang akan terasa seperti aplikasi
/// yang menggantung.
class HistoryItem {
  const HistoryItem({
    required this.video,
    this.shopName,
    this.marketName,
    this.recorderName,
  });

  final PackageVideo video;

  /// `null` bila barisnya tidak terbaca — RLS mengizinkan seluruh anggota
  /// tenant membaca `shops` dan `users`, jadi ini seharusnya hanya terjadi
  /// pada data yang memang janggal, bukan pada keadaan normal.
  final String? shopName;
  final String? marketName;
  final String? recorderName;

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    // PostgREST menaruh hasil embedding sebagai objek bersarang di bawah nama
    // tabelnya. Bila relasinya kosong, nilainya null — bukan map kosong.
    final shop = json['shops'] as Map<String, dynamic>?;
    final user = json['users'] as Map<String, dynamic>?;

    return HistoryItem(
      video: PackageVideo.fromJson(json),
      shopName: shop?['shop_name'] as String?,
      marketName: shop?['market_name'] as String?,
      recorderName: user?['full_name'] as String?,
    );
  }

  /// "Shopee · Toko Kamel", atau salah satunya bila yang lain kosong.
  String get shopLabel {
    final market = (marketName ?? '').trim();
    final shop = (shopName ?? '').trim();
    if (market.isEmpty) return shop;
    if (shop.isEmpty) return market;
    return '$market · $shop';
  }
}
