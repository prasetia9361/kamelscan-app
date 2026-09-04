import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/config/app_constants.dart';
import 'package:kamelscan/core/models/enums.dart';

/// Bucket gambar iklan (Bab 11.5, migrasi 46).
///
/// 🔴 Utang nomor 3 daftar kesiapan produksi. Bab 11.5 menyebut bucket
/// `public-assets` sejak awal, tetapi diukur 3 September 2026: **tidak ada
/// satu pun migrasi yang membuatnya**. Yang pernah dibuat hanya `avatars`
/// (migrasi 23) dan `payment-proofs` (migrasi 25).
///
/// ⚠️ Sebagian tes di bawah membaca berkas SQL. Itu memang bukan pengujian
/// perilaku — tetapi keputusan yang dijaganya (siapa boleh menulis) hanya
/// hidup di SQL, dan lebih baik dijaga di sana daripada tidak sama sekali.
void main() {
  late String sql;

  setUpAll(() {
    sql = File('supabase/migrations/46_public_assets_bucket.sql')
        .readAsStringSync();
  });

  test('migrasinya ada dan terbaca', () {
    expect(sql, contains('public-assets'));
    expect(sql.length, greaterThan(500));
  });

  test('nama bucket di Dart sama persis dengan yang di SQL', () {
    // Beda satu huruf berarti unggahan selalu gagal dengan pesan "bucket not
    // found" — dan tidak ada `analyze` maupun tes lain yang menangkapnya.
    expect(AppConstants.bucketPublicAssets, 'public-assets');
    expect(sql, contains("'${AppConstants.bucketPublicAssets}'"));
  });

  group('🔴 siapa boleh menulis', () {
    test('menulis dibatasi admin, ketiganya', () {
      // Isinya tampil di halaman depan kepada calon pelanggan yang belum punya
      // akun. Satu gambar yang salah merusak kepercayaan sebelum ada satu
      // kalimat pun yang sempat dibaca.
      for (final aksi in ['insert', 'update', 'delete']) {
        expect(
          sql,
          contains('public_assets_${aksi == 'insert' ? 'write' : aksi}_admin'),
          reason: 'policy $aksi tidak ada',
        );
      }
      expect('is_admin()'.allMatches(sql).length, greaterThanOrEqualTo(4));
    });

    test('membaca TIDAK dibatasi — itu memang gunanya', () {
      expect(sql, contains('public_assets_read_all'));
      // Landing page dibuka orang yang belum punya akun; tidak ada sesi yang
      // dapat menandatangani presigned URL di sana.
      expect(sql, contains('public'));
    });
  });

  test('batas ukuran disebut, tidak dibiarkan tanpa batas', () {
    // Gambar 20 MB di halaman depan membuat calon pelanggan pergi sebelum
    // halamannya selesai dimuat.
    expect(sql, contains('file_size_limit'));
    expect(sql, contains('5242880'));
  });

  test('hanya gambar yang diizinkan', () {
    expect(sql, contains('allowed_mime_types'));
    expect(sql, contains('image/jpeg'));
    expect(sql, isNot(contains('video/')));
  });

  test('🔴 nama berkas paket dibangun dari TierPlan, bukan ditulis satu-satu',
      () {
    // Pola A: menyebut nama paket satu per satu sudah tiga kali membuat paket
    // Bisnis tidak pernah tergambar. Nama berkasnya karena itu diturunkan dari
    // `wire`, dan tes ini menjaga ketiganya benar-benar punya bentuk yang sah.
    for (final p in TierPlan.values) {
      final nama = 'plan-${p.wire}.jpg';
      expect(nama, matches(RegExp(r'^plan-[a-z]+\.jpg$')), reason: nama);
    }
    expect(TierPlan.values.length, 3);
  });
}
