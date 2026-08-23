import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/models/shop.dart';
import 'package:kamelscan/core/models/shop_summary.dart';

/// Bab 9.5 — pembacaan agregat bersarang PostgREST pada halaman Toko.
///
/// Bentuk yang dikembalikan server tidak biasa: jumlahnya datang sebagai
/// **daftar berisi satu objek**, bukan angka. Salah membacanya membuat setiap
/// toko tampak belum pernah dipakai — dan itu berbahaya, karena angka inilah
/// yang menentukan apakah tombol Hapus dijalankan atau ditolak.
void main() {
  /// Bentuk asli dari `select=*,package_videos(count)`, disalin dari jawaban
  /// server 19 Agustus 2026.
  Map<String, dynamic> row({Object? agg = const [{'count': 12}]}) =>
      <String, dynamic>{
        'id': '03b1fe18-2cd2-46ab-8c51-7bf1877ee0d5',
        'tenant_id': '0b5ae403-f6a3-4117-9f8f-76ba141caece',
        'market_name': 'Shopee',
        'shop_name': 'Toko Uji Bab 8',
        'is_active': true,
        'package_videos': agg,
      };

  group('Agregat bersarang', () {
    test('jumlah video terbaca dari daftar berisi satu objek', () {
      expect(ShopSummary.fromJson(row()).videoCount, 12);
    });

    test('kolom tokonya sendiri tetap terbaca', () {
      final shop = ShopSummary.fromJson(row()).shop;

      expect(shop.shopName, 'Toko Uji Bab 8');
      expect(shop.marketName, 'Shopee');
      expect(shop.isActive, isTrue);
      expect(shop.displayName, 'Shopee · Toko Uji Bab 8');
    });

    test('nol video terbaca sebagai nol, bukan gagal', () {
      expect(ShopSummary.fromJson(row(agg: [{'count': 0}])).videoCount, 0);
    });

    test('daftar kosong atau null tidak melemparkan apa pun', () {
      expect(ShopSummary.fromJson(row(agg: const [])).videoCount, 0);
      expect(ShopSummary.fromJson(row(agg: null)).videoCount, 0);
    });
  });

  group('canDelete menentukan tombol Hapus dijalankan atau ditolak', () {
    test('toko yang belum pernah dipakai boleh dihapus', () {
      expect(ShopSummary.fromJson(row(agg: [{'count': 0}])).canDelete, isTrue);
    });

    test('satu video saja sudah cukup untuk menolak penghapusan', () {
      // `package_videos.shop_id` memakai `on delete restrict`: satu baris pun
      // membuat server menolak. Ambang di sini harus sama persis, kalau tidak
      // aplikasi menjanjikan sesuatu yang tidak akan terjadi.
      expect(ShopSummary.fromJson(row(agg: [{'count': 1}])).canDelete, isFalse);
      expect(ShopSummary.fromJson(row()).canDelete, isFalse);
    });

    test('agregat yang tidak terbaca dianggap boleh dihapus', () {
      // Keadaan ini seharusnya tidak pernah terjadi. Bila terjadi, server tetap
      // yang memutuskan: percobaan hapusnya ditolak `23503`, dan
      // `ShopsViewModel.delete` menerjemahkannya menjadi tawaran menonaktifkan
      // — bukan pesan error mentah.
      expect(ShopSummary.fromJson(row(agg: null)).canDelete, isTrue);
    });
  });

  group('Daftar marketplace Bab 9.5', () {
    test('memuat keenam marketplace beserta jalan keluar Lainnya', () {
      expect(
        MarketNames.all,
        containsAll(<String>[
          MarketNames.shopee,
          MarketNames.tokopedia,
          MarketNames.tiktokShop,
          MarketNames.lazada,
          MarketNames.blibli,
          MarketNames.bukalapak,
          MarketNames.other,
        ]),
      );
    });

    test('Lainnya berdiri paling akhir', () {
      expect(MarketNames.all.last, MarketNames.other);
    });

    test('tidak ada nama ganda', () {
      expect(MarketNames.all.toSet().length, MarketNames.all.length);
    });
  });
}
