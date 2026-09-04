import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Empat temuan Product Owner di landing page, 4 September 2026.
///
/// 🔴 Keempatnya lolos dari seluruh 754 tes yang ada, dan alasannya sama:
/// tidak satu pun tes menyentuh `landing/`. Berkas itu HTML dan CSS statis di
/// luar Flutter, sehingga "analyze bersih, tes hijau" tidak pernah berarti
/// apa-apa tentangnya. Yang menemukannya tetap mata manusia yang membuka
/// halamannya.
///
/// ⚠️ Diuji dengan membaca berkasnya, bukan dengan menggambarnya. Itu batas
/// yang jujur: tes ini menjaga KEPUTUSANNYA tetap ada di dalam teks, bukan
/// membuktikan halamannya tergambar rapi. Untuk yang terakhir tidak ada
/// penggantinya selain membuka halamannya.
void main() {
  late String css;
  late String html;
  late String js;

  setUpAll(() {
    css = File('landing/styles.css').readAsStringSync();
    html = File('landing/index.html').readAsStringSync();
    js = File('landing/app.js').readAsStringSync();
  });

  test('sumbernya terbaca — penjagaan ini tidak boleh lolos karena kosong', () {
    expect(css.length, greaterThan(2000));
    expect(html.length, greaterThan(2000));
  });

  // ==========================================================================
  // 1. Penomoran ganda di "Cara kerja"
  // ==========================================================================
  //
  // Langkahnya adalah <ol> yang menggambar nomornya sendiri lewat
  // `.langkah-no`. Reset daftar di stylesheet hanya menyebut `ul`, sehingga
  // peramban menggambar nomor bawaannya JUGA — pembaca melihat "1. 1".
  //
  // 🔴 Cacat ini hidup sejak landing page pertama kali ditulis dan tidak
  // pernah terlihat dari kode: `ol` dan `ul` berdampingan di sana, dan mata
  // membacanya seolah keduanya sudah tertangani.
  group('🔴 penomoran "Cara kerja" tidak boleh ganda', () {
    test('reset daftar mencakup ol, bukan hanya ul', () {
      final reset = RegExp(r'ul\s*,\s*ol\s*\{[^}]*list-style:\s*none');
      expect(
        reset.hasMatch(css),
        isTrue,
        reason: 'ol wajib ikut di-reset; tanpa itu nomor bawaan peramban '
            'tergambar di samping .langkah-no',
      );
    });

    test('nomor buatan sendiri masih dipakai', () {
      // Kalau suatu hari .langkah-no dibuang dan nomornya diserahkan kembali
      // ke peramban, tes di atas berhenti relevan — dan tes ini yang jatuh.
      expect(html, contains('class="langkah-no"'));
      expect(css, contains('.langkah-no'));
    });

    test('bagian Cara kerja memang <ol>', () {
      expect(html, contains('<ol class="kisi kisi-4">'));
    });
  });

  // ==========================================================================
  // 2. Langkah 4 terlalu panjang
  // ==========================================================================
  //
  // Keempat langkah berdiri berdampingan dalam kisi empat kolom. Satu kartu
  // yang isinya dua kali lebih panjang meninggikan seluruh barisnya, dan tiga
  // kartu lain berakhir dengan ruang kosong di bawahnya.
  group('langkah "Cara kerja" tetap sepadan panjangnya', () {
    /// Isi satu langkah, tanpa spasi berlebih.
    String isiLangkah(String kunci) {
      final m = RegExp(
        '<p data-i18n="cara\\.$kunci\\.isi">(.*?)</p>',
        dotAll: true,
      ).firstMatch(html);
      expect(m, isNotNull, reason: 'langkah $kunci tidak ketemu');
      return m!.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    test('🔴 langkah 4 tidak lebih dari sepertiga lebih panjang dari yang lain',
        () {
      final panjang = ['l1', 'l2', 'l3', 'l4'].map(isiLangkah).toList();
      final l4 = panjang[3].length;
      final rata = (panjang[0].length + panjang[1].length + panjang[2].length) / 3;

      expect(
        l4,
        lessThan(rata * 1.34),
        reason: 'langkah 4 panjangnya $l4 huruf terhadap rata-rata '
            '${rata.round()} — kartunya akan meninggikan seluruh baris',
      );
    });

    test('isinya tetap menyebut yang penting meski dipendekkan', () {
      // Memendekkan teks tidak boleh sampai membuang janjinya: tanpa akun,
      // tanpa memasang aplikasi, dan ada tombol unduh.
      final l4 = isiLangkah('l4').toLowerCase();
      expect(l4, contains('tanpa akun'));
      expect(l4, contains('unduh'));
    });

    test('terjemahan Inggrisnya ikut dipendekkan', () {
      // 🔴 Memendekkan yang Indonesia saja meninggalkan cacat yang sama persis
      // bagi pembaca bahasa Inggris — dan tidak ada yang akan melihatnya.
      final m = RegExp(r'"cara\.l4\.isi":\s*"([^"]*)"').firstMatch(js);
      expect(m, isNotNull);
      expect(m!.group(1)!.length, lessThan(190));
    });
  });

  // ==========================================================================
  // 3. Judul penutup yang membingungkan
  // ==========================================================================
  //
  // "Paket berikutnya yang Anda kirim bisa sudah ada buktinya" — Product Owner
  // membacanya beberapa kali dan tetap tidak yakin apa maksudnya. Kalimat itu
  // memakai pengandaian ("bisa sudah") di tempat yang seharusnya berisi ajakan
  // paling tegas di seluruh halaman.
  group('ajakan penutup terbaca sekali baca', () {
    String judulPenutup() {
      final m = RegExp(r'data-i18n="penutup\.judul">(.*?)</h2>', dotAll: true)
          .firstMatch(html);
      expect(m, isNotNull);
      return m!.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    test('🔴 kalimat lama yang membingungkan tidak kembali', () {
      expect(html, isNot(contains('bisa sudah ada buktinya')));
      expect(js, isNot(contains('could already have its proof')));
    });

    test('judulnya berupa ajakan, bukan pengandaian', () {
      final judul = judulPenutup();
      expect(judul, isNotEmpty);
      expect(judul.length, lessThan(45),
          reason: 'ajakan penutup yang panjang berhenti menjadi ajakan');
      expect(judul.toLowerCase(), isNot(contains('bisa sudah')));
    });
  });

  // ==========================================================================
  // 4. Spanduk memenuhi layar pertama
  // ==========================================================================
  //
  // Keputusan Product Owner: gambar unggahan dibuat penuh di halaman awal.
  //
  // ⚠️ Yang dibatalkan hanya batas untuk FOTO unggahan. Ilustrasi SVG bawaan
  // tetap dibatasi karena bentuknya badan HP tegak — HP setinggi 600 px di
  // layar lebar terbaca seperti galat, bukan seperti desain.
  group('spanduk unggahan memenuhi kolomnya', () {
    /// Isi satu aturan CSS berdasarkan pemilihnya.
    String aturan(String pemilih) {
      final m = RegExp('${RegExp.escape(pemilih)}\\s*\\{([^}]*)\\}')
          .firstMatch(css);
      expect(m, isNotNull, reason: 'aturan $pemilih tidak ketemu');
      return m!.group(1)!;
    }

    test('🔴 .hero-foto tidak lagi dibatasi 320 px', () {
      expect(
        aturan('.hero-foto'),
        isNot(contains('max-width: 320px')),
        reason: 'spanduk yang dikecilkan jadi 320 px kehilangan maksudnya',
      );
    });

    test('.hero-foto tetap selebar wadahnya', () {
      expect(aturan('.hero-foto'), contains('width: 100%'));
    });

    test('⚠️ ilustrasi SVG TETAP dibatasi — perbedaannya disengaja', () {
      expect(
        aturan('.hero-gambar svg'),
        contains('max-width: 320px'),
        reason: 'ilustrasi HP tegak yang dibiarkan penuh terbaca seperti galat',
      );
    });

    test('gambar unggahan tetap dimuat di luar halaman lebih dulu', () {
      // Karena ukuran keduanya kini berbeda, pergantiannya menggeser tata
      // letak. Pergeseran sekali dapat diterima; kotak kosong yang bertahan
      // selama unduhan tidak.
      expect(js, contains('new Image()'));
      expect(js, contains('img.onload'));
    });
  });
}
