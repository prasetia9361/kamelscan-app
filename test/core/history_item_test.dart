import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/models/enums.dart';
import 'package:kamelscan/core/models/history_item.dart';

/// Bab 9.4 — jembatan antara hasil embedding PostgREST dan baris Riwayat.
///
/// Yang diuji di sini bukan kuerinya, melainkan **pembacaan objek bersarang**:
/// PostgREST menaruh hasil join sebagai objek di bawah nama tabelnya, dan
/// mengisinya `null` bila relasinya tidak terbaca. Salah membaca bagian itu
/// menghasilkan baris riwayat tanpa nama toko — kelihatan seperti data hilang,
/// padahal datanya ada.
void main() {
  Map<String, dynamic> row({
    Object? shops = const {'shop_name': 'Toko Kamel', 'market_name': 'Shopee'},
    Object? users = const {'full_name': 'Budi Santoso'},
  }) =>
      <String, dynamic>{
        'id': '7f0ac1a5-8d24-4986-88e9-5079ad646802',
        'tenant_id': '0b5ae403-f6a3-4117-9f8f-76ba141caece',
        'shop_id': '03b1fe18-2cd2-46ab-8c51-7bf1877ee0d5',
        'user_id': 'f999c837-6e7c-4607-a75a-5af2b33147bd',
        'resi_code': '6896RTI',
        'type': 'return',
        'status': 'uploaded',
        'scan_date': '2026-08-18T15:23:52.000+00:00',
        'expires_at': '2026-09-17T15:23:52.000+00:00',
        'duration_seconds': 30,
        'file_size_bytes': 1034380,
        'shops': shops,
        'users': users,
      };

  group('Objek bersarang hasil embedding', () {
    test('nama toko, marketplace, dan perekam terbaca', () {
      final item = HistoryItem.fromJson(row());

      expect(item.shopName, 'Toko Kamel');
      expect(item.marketName, 'Shopee');
      expect(item.recorderName, 'Budi Santoso');
    });

    test('kolom videonya sendiri tetap terbaca utuh', () {
      final video = HistoryItem.fromJson(row()).video;

      expect(video.resiCode, '6896RTI');
      expect(video.type, VideoType.returned);
      expect(video.status, VideoStatus.uploaded);
      expect(video.durationSeconds, 30);
      expect(video.fileSizeBytes, 1034380);
    });

    test('kolom tambahan hasil join tidak mengganggu PackageVideo', () {
      // `shops` dan `users` bukan kolom `package_videos`. Bila serialisasinya
      // menolak kunci asing, seluruh Riwayat akan gagal dimuat — bukan sekadar
      // kehilangan nama tokonya.
      expect(() => HistoryItem.fromJson(row()), returnsNormally);
    });
  });

  group('Relasi yang tidak terbaca tidak boleh membuat baris gagal', () {
    test('shops null menghasilkan nama kosong, bukan lemparan', () {
      final item = HistoryItem.fromJson(row(shops: null, users: null));

      expect(item.shopName, isNull);
      expect(item.marketName, isNull);
      expect(item.recorderName, isNull);
      expect(item.video.resiCode, '6896RTI');
    });
  });

  group('shopLabel', () {
    test('menggabungkan marketplace dan nama toko', () {
      expect(HistoryItem.fromJson(row()).shopLabel, 'Shopee · Toko Kamel');
    });

    test('hanya salah satu bila yang lain kosong', () {
      expect(
        HistoryItem.fromJson(row(shops: {'shop_name': 'Toko Kamel'})).shopLabel,
        'Toko Kamel',
      );
      expect(
        HistoryItem.fromJson(row(shops: {'market_name': 'Lazada'})).shopLabel,
        'Lazada',
      );
    });

    test('kosong sama sekali bila relasinya tidak ada', () {
      expect(HistoryItem.fromJson(row(shops: null)).shopLabel, isEmpty);
    });
  });
}
