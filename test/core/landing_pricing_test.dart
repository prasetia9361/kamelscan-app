import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/config/tier_config.dart';
import 'package:kamelscan/core/models/enums.dart';

/// Harga di landing page harus sama dengan `tier_config.dart` (Bab 10.2).
///
/// 🔴 Cacat yang dijawab berkas ini hidup BERMINGGU-MINGGU tanpa ketahuan, dan
/// ia bukan cacat tampilan — halaman depan menjual angka yang salah:
///
///     Standar   Rp 99.000   -> sebenarnya Rp 149.000
///     Pro       Rp 249.000  -> sebenarnya Rp 299.000
///     Bisnis    tidak ada   -> paket ketiga sejak migrasi 39
///
/// Calon pelanggan datang dengan angka yang salah di kepalanya, lalu menemukan
/// harga lain di halaman pembayaran.
///
/// Sebabnya tertulis di halaman itu sendiri: angkanya sengaja DITULIS MATI agar
/// halaman pemasaran tidak bergantung pada API — pertukaran yang disadari.
/// Yang tidak disadari: tidak ada satu pun yang mengingatkan saat harga
/// berubah, karena landing page berada di luar Flutter.
///
/// ⚠️ Tes ini yang mengingatkan. Ia membaca kedua sumber dan mencocokkannya,
/// jadi harga yang berubah tanpa memperbarui halaman depan **menggagalkan
/// tes**, bukan diam-diam menyesatkan orang.
void main() {
  late String html;

  setUpAll(() {
    html = File('landing/index.html').readAsStringSync();
  });

  /// Harga yang tertulis pada kartu paket [plan].
  ///
  /// Diambil dari atribut `data-i18n`, BUKAN dengan mencari angkanya di
  /// seluruh berkas: komentar di kepala bagian Harga sengaja memuat angka
  /// LAMA sebagai catatan sejarah, dan pencarian polos akan menemukannya.
  String? hargaDiLanding(TierPlan plan) {
    final pola = RegExp(
      'data-i18n="harga[.]${plan.wire}[.]harga">([^<]+)<',
    );
    return pola.firstMatch(html)?.group(1)?.trim();
  }

  String rupiah(num v) {
    final s = v.toInt().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp $buf';
  }

  test('sumbernya terbaca — penjagaan ini tidak boleh lolos karena kosong', () {
    expect(html, contains('id="harga"'));
    expect(TierPlan.values.length, 3);
  });

  test('🔴 KETIGA paket punya kartunya sendiri di halaman depan', () {
    // Pola A: paket yang tidak disebut tidak akan pernah tergambar. Sudah
    // terjadi tiga kali di aplikasi; di halaman depan akibatnya paket termahal
    // tidak pernah ditawarkan kepada siapa pun.
    for (final plan in TierPlan.values) {
      expect(
        hargaDiLanding(plan),
        isNotNull,
        reason: 'kartu paket ${plan.wire} tidak ada di landing page',
      );
    }
  });

  test('🔴 harga di landing SAMA dengan tier_config.dart', () {
    for (final plan in TierPlan.values) {
      final seharusnya = rupiah(TierCatalog.fallbackFor(plan).price);
      expect(
        hargaDiLanding(plan),
        seharusnya,
        reason: 'harga ${plan.wire} di landing page sudah basi. '
            'Perbarui landing/index.html — halaman itu di luar Flutter dan '
            'tidak ikut berubah sendiri.',
      );
    }
  });

  test('durasi video tiap paket ikut benar', () {
    // Durasi adalah satu-satunya pembeda nyata antar paket bagi pelanggan
    // bervolume rendah, jadi salah di sini langsung menyesatkan pilihan.
    const teks = {
      TierPlan.standar: '30 detik',
      TierPlan.pro: '60 detik',
      TierPlan.bisnis: '3 menit',
    };
    for (final plan in TierPlan.values) {
      final detik = TierCatalog.fallbackFor(plan).maxVideoSeconds;
      expect(
        detik,
        plan == TierPlan.bisnis ? 180 : (plan == TierPlan.pro ? 60 : 30),
        reason: 'durasi ${plan.wire} berubah di kode',
      );
      expect(html, contains(teks[plan]!),
          reason: 'durasi ${plan.wire} tidak disebut di landing page');
    }
  });

  test('🔴 retensi disebut 30 hari, bukan angka lama yang berbeda per paket',
      () {
    // Sampai 4 September 2026 halaman ini menjanjikan 60 hari pada Pro.
    // Retensi sudah 30 hari untuk KETIGANYA sejak migrasi 41.
    for (final plan in TierPlan.values) {
      expect(TierCatalog.fallbackFor(plan).retentionDays, 30);
    }
    expect(html, contains('30 hari'));
    expect(
      html.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ''),
      isNot(contains('60 hari')),
      reason: 'klaim retensi 60 hari masih terlihat pelanggan',
    );
  });

  test('🔴 watermark logo toko TIDAK dijanjikan lagi', () {
    // Dibatalkan 1 September 2026: seluruh paket memakai watermark teks.
    // Menjanjikannya di halaman depan berarti menjual fitur yang tidak ada.
    final terlihat = html.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    expect(terlihat.toLowerCase(), isNot(contains('watermark logo')));
  });
}
