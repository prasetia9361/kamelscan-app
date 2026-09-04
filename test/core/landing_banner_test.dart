import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Spanduk landing page dari `platform_settings.banner_landing` (Bab 10.2).
///
/// 🔴 Cacat yang dijawab berkas ini ditemukan Product Owner 4 September 2026:
/// halaman Admin "Gambar iklan" menyimpan alamat spanduk dengan benar, dan
/// **tidak ada satu pun kode yang membacanya**. Landing page menggambar
/// ilustrasi SVG buatan tangan dan tidak melakukan satu panggilan jaringan pun
/// — komentarnya sendiri sudah menulis bahwa gambarnya "belum ada".
///
/// Layar yang menyimpan sesuatu yang tidak pernah dipakai adalah bentuk
/// kebohongan yang sama dengan tombol yang tidak menghasilkan apa-apa.
///
/// ⚠️ Diuji dengan membaca berkasnya. Landing page adalah HTML/JS statis di
/// luar Flutter, jadi tidak ada cara lain menjangkaunya dari sini — tetapi
/// keputusan yang dijaga terlihat jelas di teksnya.
void main() {
  late String js;
  late String html;
  late String deploy;

  setUpAll(() {
    js = File('landing/app.js').readAsStringSync();
    html = File('landing/index.html').readAsStringSync();
    deploy = File('deploy_web.ps1').readAsStringSync();
  });

  test('sumbernya terbaca — penjagaan ini tidak boleh lolos karena kosong', () {
    expect(js.length, greaterThan(2000));
    expect(html, contains('hero-gambar'));
  });

  test('landing membaca banner_landing dari platform_settings', () {
    expect(js, contains('banner_landing'));
    expect(js, contains('platform_settings'));
    expect(js, contains('image_url'));
  });

  test('wadah spanduk punya id yang dicari app.js', () {
    // Tanpa id ini `spanduk()` berhenti diam dan tidak ada yang menandainya.
    expect(html, contains('id="hero-gambar"'));
    expect(js, contains("getElementById('hero-gambar')"));
  });

  group('🔴 tidak boleh memblokir halaman', () {
    test('ilustrasi SVG TETAP ada — ia yang tergambar lebih dulu', () {
      // Halaman ini dibuka calon pelanggan dari gudang bersinyal buruk.
      // Menunggu unduhan sebelum menggambar apa pun membuatnya tampak kosong
      // justru di tempat yang paling menentukan.
      expect(html, contains('<svg'));
      expect(html, contains('ilus-judul'));
    });

    test('gambar dimuat di luar DOM dulu, bukan ditempel langsung', () {
      // Menempelkan <img> langsung berarti ilustrasinya lenyap saat itu juga
      // dan digantikan kotak kosong selama gambarnya masih diunduh.
      expect(js, contains('new Image()'));
      expect(js, contains('img.onload'));
    });

    test('kegagalan jaringan tidak merusak apa pun', () {
      expect(js, contains('.catch('));
    });
  });

  group('🔴 kredensial tidak boleh masuk repositori', () {
    test('app.js menyimpan PENANDA, bukan kunci sungguhan', () {
      expect(js, contains('__SUPABASE_URL__'));
      expect(js, contains('__SUPABASE_ANON_KEY__'));

      // Kunci Supabase selalu JWT berawalan `eyJ`. Kalau ia muncul di sini,
      // kunci sungguhan sudah masuk git.
      expect(
        js,
        isNot(contains('eyJ')),
        reason: 'kunci sungguhan tertulis di landing/app.js',
      );
    });

    test('deploy_web.ps1 menyuntikkan keduanya dan menjaga penandanya', () {
      expect(deploy, contains("\$js.Replace('__SUPABASE_URL__'"));
      expect(deploy, contains("\$js.Replace('__SUPABASE_ANON_KEY__'"));

      // ⚠️ Penanda yang lolos TIDAK merusak halaman — `spanduk()` berhenti
      // diam. Justru karena itu penjaganya wajib ada: kegagalannya tidak akan
      // terlihat siapa pun, dan spanduk Admin diam-diam tidak pernah tampil.
      expect(deploy, contains('penanda kredensial masih tersisa di landing/app.js'));
    });
  });
}
