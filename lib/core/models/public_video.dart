import 'enums.dart';

/// Isi halaman bukti publik `/v/{token}` (Bab 10.6).
///
/// 🔴 Sengaja **bukan** [PackageVideo]. Halaman ini dibuka orang di luar tenant
/// — pusat resolusi marketplace, kadang pembeli — dan yang boleh sampai ke sana
/// hanya isi buktinya. `tenant_id`, `user_id`, `shop_id`, dan `storage_key`
/// tidak pernah keluar dari Edge Function `get-public-video`; memakai model
/// tabel di sini akan membuat kolom-kolom itu ikut terbawa begitu ada yang
/// menambahkannya kembali tanpa sadar.
class PublicVideo {
  const PublicVideo({
    required this.url,
    required this.resiCode,
    required this.type,
    required this.scanDate,
    required this.linkExpiresAt,
    this.durationSeconds,
    this.fileSizeBytes,
    this.locationLat,
    this.locationLng,
    this.timeVerified = true,
    this.shopName,
    this.marketName,
  });

  /// URL bertanda tangan berumur 15 menit.
  final String url;

  final String resiCode;
  final VideoType type;

  /// Waktu **server** saat rekaman dibuat.
  final DateTime scanDate;

  /// Sampai kapan tautan ini masih dapat dibuka — Bab 9.4 mewajibkannya tampil,
  /// karena pusat resolusi marketplace kadang baru membukanya beberapa hari
  /// kemudian.
  final DateTime linkExpiresAt;

  final int? durationSeconds;
  final int? fileSizeBytes;
  final double? locationLat;
  final double? locationLng;

  /// L.2 — penanda ini juga sudah terbakar ke gambar videonya. Ia ditampilkan
  /// di sini agar halaman menyatakan hal yang sama dengan yang terlihat di
  /// video; menyembunyikannya akan terlihat seperti menutupi sesuatu.
  final bool timeVerified;

  final String? shopName;
  final String? marketName;

  factory PublicVideo.fromJson(Map<String, dynamic> json) => PublicVideo(
        url: json['url'] as String,
        resiCode: json['resi_code'] as String? ?? '',
        type: VideoType.fromWire(json['type'] as String?),
        scanDate:
            DateTime.tryParse(json['scan_date'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
        linkExpiresAt:
            DateTime.tryParse(json['link_expires_at'] as String? ?? '')
                    ?.toLocal() ??
                DateTime.now(),
        durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
        fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt(),
        locationLat: (json['location_lat'] as num?)?.toDouble(),
        locationLng: (json['location_lng'] as num?)?.toDouble(),
        timeVerified: json['time_verified'] as bool? ?? true,
        shopName: json['shop_name'] as String?,
        marketName: json['market_name'] as String?,
      );

  bool get hasLocation => locationLat != null && locationLng != null;

  String get shopLabel {
    final market = (marketName ?? '').trim();
    final shop = (shopName ?? '').trim();
    if (market.isEmpty) return shop;
    if (shop.isEmpty) return market;
    return '$market · $shop';
  }

  int daysUntilLinkExpiry({DateTime? now}) =>
      linkExpiresAt.difference(now ?? DateTime.now()).inDays;
}
