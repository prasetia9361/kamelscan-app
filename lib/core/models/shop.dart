import 'package:freezed_annotation/freezed_annotation.dart';

part 'shop.freezed.dart';
part 'shop.g.dart';

/// Satu akun jualan di satu marketplace — tabel `public.shops` (Bab 5.2).
@freezed
abstract class Shop with _$Shop {
  const factory Shop({
    required String id,
    required String tenantId,
    required String marketName,
    required String shopName,
    @Default(true) bool isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Shop;

  const Shop._();

  factory Shop.fromJson(Map<String, dynamic> json) => _$ShopFromJson(json);

  /// Label yang dipakai di dropdown pemilihan toko: "Shopee · Toko Kamel".
  String get displayName => '$marketName · $shopName';
}

/// Daftar marketplace yang dikenal (Bab 5.2 kolom `market_name`).
///
/// Ini hanya bantuan pengisian form; kolomnya tetap `text` bebas sehingga
/// marketplace baru tidak memerlukan migrasi database.
class MarketNames {
  const MarketNames._();

  static const String shopee = 'Shopee';
  static const String tokopedia = 'Tokopedia';
  static const String tiktokShop = 'TikTok Shop';
  static const String lazada = 'Lazada';
  static const String other = 'Lainnya';

  static const List<String> all = [
    shopee,
    tokopedia,
    tiktokShop,
    lazada,
    other,
  ];
}
