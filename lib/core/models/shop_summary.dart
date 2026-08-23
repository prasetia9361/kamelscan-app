import 'shop.dart';

/// Satu baris pada halaman Toko: data toko beserta jumlah videonya (Bab 9.5).
///
/// Jumlahnya datang dari agregat bersarang PostgREST (`package_videos(count)`)
/// dalam permintaan yang sama — bukan satu permintaan tambahan per toko.
///
/// ⚠️ [videoCount] menghitung **seluruh** baris `package_videos` milik toko itu,
/// termasuk yang berstatus `deleted`. Itu disengaja, dan justru angka yang
/// benar untuk keperluan utamanya: `package_videos.shop_id` memakai
/// `on delete restrict`, dan yang menghalangi penghapusan toko adalah adanya
/// baris — bukan status barisnya. Angka yang menghitung lebih sedikit akan
/// menjanjikan toko dapat dihapus padahal server menolaknya.
class ShopSummary {
  const ShopSummary({required this.shop, this.videoCount = 0});

  final Shop shop;
  final int videoCount;

  /// Toko yang belum pernah dipakai merekam — satu-satunya yang benar-benar
  /// dapat dihapus (Bab 9.5).
  bool get canDelete => videoCount == 0;

  factory ShopSummary.fromJson(Map<String, dynamic> json) {
    // PostgREST mengembalikan agregat sebagai daftar berisi satu objek:
    //   "package_videos": [ { "count": 12 } ]
    // Bentuk itu tetap dipakai walau isinya nol, tetapi tidak ada salahnya
    // bertahan terhadap daftar kosong.
    final agg = json['package_videos'];
    var count = 0;
    if (agg is List && agg.isNotEmpty) {
      count = ((agg.first as Map)['count'] as num?)?.toInt() ?? 0;
    }

    return ShopSummary(shop: Shop.fromJson(json), videoCount: count);
  }
}
