import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/models/enums.dart';
import 'package:kamelscan/core/models/history_item.dart';
import 'package:kamelscan/core/models/package_video.dart';
import 'package:kamelscan/core/utils/csv_export.dart';

/// Ekspor CSV Riwayat (Bab 10, keputusan Product Owner 31 Agustus 2026).
///
/// 🔴 Berkas hasil ekspor adalah **satu-satunya keluaran aplikasi ini yang
/// dibaca tanpa aplikasinya**. Tidak ada layar yang dapat memperbaiki isinya,
/// tidak ada tombol *Coba lagi*, dan yang membukanya tidak punya cara
/// mengetahui bahwa ada yang salah. Karena itu yang diuji di sini bukan
/// "berhasil membuat berkas", melainkan setiap cara berkasnya dapat berbohong.
void main() {
  HistoryItem item({
    String resi = 'JX123456',
    String? toko = 'Toko A',
    String? perekam = 'Budi',
    VideoType tipe = VideoType.packing,
    VideoStatus status = VideoStatus.uploaded,
    int? durasi = 28,
  }) => HistoryItem(
    video: PackageVideo(
      id: 'v1',
      tenantId: 't1',
      shopId: 's1',
      userId: 'u1',
      resiCode: resi,
      type: tipe,
      status: status,
      scanDate: DateTime(2026, 8, 31, 14, 5),
      expiresAt: DateTime(2026, 9, 30, 14, 5),
      durationSeconds: durasi,
    ),
    shopName: toko,
    recorderName: perekam,
  );

  String label(CsvColumn k) => k.name;
  String nilai(CsvColumn k, HistoryItem i) => switch (k) {
    CsvColumn.resi => i.video.resiCode,
    CsvColumn.toko => i.shopName ?? '',
    CsvColumn.perekam => i.recorderName ?? '',
    CsvColumn.tanggal => CsvExport.tanggal(i.video.scanDate),
    CsvColumn.durasi => i.video.durationSeconds?.toString() ?? '',
    _ => '',
  };

  group('🔴 Injeksi rumus — sel tidak boleh dijalankan Excel', () {
    // `resi_code` diketik atau dipindai dari luar. Sel yang diawali `=`, `+`,
    // `-`, atau `@` DIJALANKAN Excel saat berkasnya dibuka — termasuk
    // `=HYPERLINK(...)` yang mengirim isi baris lain ke alamat mana pun.
    //
    // Yang menanggung akibatnya adalah pelanggan yang membuka ekspornya
    // sendiri, dan ia tidak punya cara mengetahui bahwa nomor resi sebuah
    // pesanan adalah muatan berbahaya.
    for (final jahat in ['=1+1', '+1', '-1', '@SUM(A1)', '=HYPERLINK("x")']) {
      test('"$jahat" dijinakkan dengan petik di depan', () {
        final hasil = CsvExport.sel(jahat);

        expect(
          hasil.startsWith("'") || hasil.startsWith('"\''),
          isTrue,
          reason: '$jahat masih akan dijalankan Excel',
        );
      });
    }

    test('teks biasa tidak ikut diberi petik', () {
      expect(CsvExport.sel('JX123456'), 'JX123456');
      expect(CsvExport.sel('Toko A'), 'Toko A');
    });

    // Tab dan carriage return juga memulai rumus di Excel. Keduanya dijinakkan
    // petik, tetapi hanya `\r` yang perlu dikutip — RFC 4180 tidak menuntut
    // tab dikutip, dan mengutipnya hanya menambah tanda yang harus dibuang
    // pembacanya.
    test('tab dijinakkan tanpa perlu dikutip', () {
      expect(CsvExport.sel('\tSUM'), "'\tSUM");
    });

    test('carriage return dijinakkan DAN dikutip', () {
      // Dibiarkan telanjang, `\r` memecah barisnya jadi dua.
      expect(CsvExport.sel('\rSUM'), '"\'\rSUM"');
    });
  });

  group('Pengutipan RFC 4180', () {
    test('koma membuat selnya dikutip', () {
      expect(CsvExport.sel('Toko A, Cabang B'), '"Toko A, Cabang B"');
    });

    test('petik ganda digandakan', () {
      expect(CsvExport.sel('Toko "A"'), '"Toko ""A"""');
    });

    test('baris baru tidak memecah barisnya', () {
      final hasil = CsvExport.sel('baris1\nbaris2');

      expect(hasil.startsWith('"'), isTrue);
      expect(hasil.endsWith('"'), isTrue);
    });

    test('null menjadi sel kosong, bukan tulisan "null"', () {
      expect(CsvExport.sel(null), '');
    });
  });

  group('Bentuk berkas', () {
    test('diawali BOM supaya Excel membaca aksen dengan benar', () {
      final isi = CsvExport.bangun(
        items: [item()],
        kolom: [CsvColumn.resi],
        label: label,
        nilai: nilai,
      );

      expect(isi.codeUnitAt(0), 0xFEFF);
    });

    test('memakai CRLF, bukan LF', () {
      final isi = CsvExport.bangun(
        items: [item()],
        kolom: [CsvColumn.resi],
        label: label,
        nilai: nilai,
      );

      expect(isi, contains('\r\n'));
      expect(isi.replaceAll('\r\n', '').contains('\n'), isFalse);
    });

    test('daftar kosong tetap menghasilkan barisan judul', () {
      final isi = CsvExport.bangun(
        items: const [],
        kolom: [CsvColumn.resi, CsvColumn.toko],
        label: label,
        nilai: nilai,
      );

      // Berkas nol byte terbaca seperti unduhan yang gagal.
      expect(isi, contains('resi,toko'));
      expect(isi.trim().isNotEmpty, isTrue);
    });

    test('hanya kolom yang dipilih yang muncul', () {
      final isi = CsvExport.bangun(
        items: [item()],
        kolom: [CsvColumn.resi, CsvColumn.perekam],
        label: label,
        nilai: nilai,
      );

      expect(isi, contains('resi,perekam'));
      expect(isi, contains('JX123456,Budi'));
      expect(isi, isNot(contains('toko')));
      expect(isi, isNot(contains('Toko A')));
    });

    test('satu baris per riwayat', () {
      final isi = CsvExport.bangun(
        items: [item(resi: 'A'), item(resi: 'B'), item(resi: 'C')],
        kolom: [CsvColumn.resi],
        label: label,
        nilai: nilai,
      );

      // Judul + tiga baris, masing-masing diakhiri CRLF.
      expect('\r\n'.allMatches(isi).length, 4);
    });
  });

  group('Tanggal', () {
    // 🔴 `31/08/2026` dibaca Excel Amerika sebagai bulan ke-31, berubah jadi
    // teks, dan kolomnya tidak dapat diurutkan sama sekali.
    test('YYYY-MM-DD HH:MM, bukan format lokal', () {
      expect(
        CsvExport.tanggal(DateTime(2026, 8, 31, 14, 5)),
        '2026-08-31 14:05',
      );
    });

    test('null menjadi kosong', () {
      expect(CsvExport.tanggal(null), '');
    });

    test('satu digit tetap diberi nol di depan', () {
      expect(CsvExport.tanggal(DateTime(2026, 1, 2, 3, 4)), '2026-01-02 03:04');
    });
  });

  group('Nama berkas', () {
    // Titik dua pada jam ilegal di Windows dan membuat unduhannya gagal tanpa
    // pesan apa pun.
    test('tidak memuat karakter yang ilegal di Windows', () {
      final nama = CsvExport.namaBerkas(DateTime(2026, 8, 31, 14, 5));

      for (final terlarang in [':', '/', r'\', '?', '*', '<', '>', '|', '"']) {
        expect(nama, isNot(contains(terlarang)), reason: 'memuat $terlarang');
      }
      expect(nama, endsWith('.csv'));
    });

    test('memuat tanggal dan jam supaya dua ekspor tidak saling menimpa', () {
      final pagi = CsvExport.namaBerkas(DateTime(2026, 8, 31, 9, 0));
      final sore = CsvExport.namaBerkas(DateTime(2026, 8, 31, 16, 30));

      expect(pagi, isNot(sore));
    });
  });
}
