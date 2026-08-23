import 'app_user.dart';

/// Satu baris pada sub-halaman Kelola Akun Packer (Bab 9.6).
///
/// Menggabungkan profil packer dengan dua hal yang ada di tabel lain: berapa
/// video yang pernah ia rekam, dan toko mana saja yang ditugaskan kepadanya.
/// Keduanya diambil lewat embedding PostgREST dalam permintaan yang sama —
/// Owner dengan lima packer tidak perlu menunggu sebelas perjalanan
/// bolak-balik.
class PackerSummary {
  const PackerSummary({
    required this.user,
    this.videoCount = 0,
    this.shopNames = const [],
  });

  final AppUser user;

  /// ⚠️ Menghitung **seluruh** video milik packer ini, termasuk yang berstatus
  /// `deleted`. Sama seperti pada halaman Toko: `package_videos.user_id`
  /// memakai `on delete restrict`, dan yang menghalangi penghapusan akun adalah
  /// adanya baris — bukan statusnya. Angka yang menghitung lebih sedikit akan
  /// menjanjikan akun dapat dihapus padahal server menolaknya.
  final int videoCount;

  final List<String> shopNames;

  /// Bab 9.6 — akun packer yang sudah pernah merekam **tidak boleh dihapus**.
  /// Ini menjaga rantai bukti: video harus tetap menunjuk orang yang merekamnya.
  bool get canDelete => videoCount == 0;

  factory PackerSummary.fromJson(Map<String, dynamic> json) {
    final agg = json['package_videos'];
    var count = 0;
    if (agg is List && agg.isNotEmpty) {
      count = ((agg.first as Map)['count'] as num?)?.toInt() ?? 0;
    }

    // `shop_packers` adalah tabel penghubung; tiap barisnya membawa objek
    // `shops` di dalamnya. Relasi yang kosong dikembalikan sebagai daftar
    // kosong, bukan null.
    final penugasan = json['shop_packers'];
    final toko = <String>[];
    if (penugasan is List) {
      for (final baris in penugasan) {
        final shop = (baris as Map)['shops'];
        if (shop is Map) {
          final nama = (shop['shop_name'] as String?)?.trim() ?? '';
          if (nama.isNotEmpty) toko.add(nama);
        }
      }
    }

    return PackerSummary(
      user: AppUser.fromJson(json),
      videoCount: count,
      shopNames: toko,
    );
  }
}
