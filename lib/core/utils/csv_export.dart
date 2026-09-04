import '../models/history_item.dart';

/// Kolom yang dapat diekspor dari Riwayat.
///
/// Urutan enum ini adalah urutan kolom di berkas hasilnya. Product Owner
/// memilih kolomnya sendiri saat mengekspor (keputusan 31 Agustus 2026), jadi
/// yang tidak dicentang tidak muncul sama sekali — bukan muncul kosong.
enum CsvColumn {
  tanggal,
  resi,
  jenis,
  status,
  toko,
  marketplace,
  perekam,
  durasi,
  ukuran,
  kedaluwarsa,
}

/// Menyusun isi berkas CSV dari daftar riwayat.
///
/// 🔴 Seluruhnya fungsi murni, tanpa `dart:html` dan tanpa `kIsWeb`. Bagian
/// yang menyentuh peramban ada di berkas terpisah, dan itu disengaja: `kIsWeb`
/// konstanta waktu kompilasi, sehingga apa pun yang ditulis di baliknya tidak
/// pernah dijalankan `flutter test` satu kali pun (DEVIASI **O.14**). Yang
/// dapat salah di sini — pengutipan, pemisah, tanggal, injeksi rumus — semua
/// diuji sungguhan.
class CsvExport {
  const CsvExport._();

  /// Tanda urutan byte UTF-8.
  ///
  /// 🔴 Tanpa ini Microsoft Excel membuka berkasnya sebagai ANSI, dan setiap
  /// nama toko ber-aksen atau ber-emoji berubah menjadi karakter sampah. Tiga
  /// byte yang menentukan apakah berkasnya terbaca atau tidak.
  static const String bom = '﻿';

  /// Pemisah baris CRLF, bukan LF.
  ///
  /// RFC 4180 menuntutnya, dan Excel versi Windows lama menampilkan seluruh
  /// berkas sebagai satu baris raksasa bila hanya LF.
  static const String eol = '\r\n';

  /// Karakter yang membuat Excel memperlakukan sel sebagai **rumus**.
  static const String _pemicuRumus = '=+-@\t\r';

  /// Membungkus satu sel sesuai RFC 4180, sekaligus menjinakkan rumus.
  ///
  /// 🔴 **Injeksi rumus CSV.** `resi_code` diketik atau dipindai dari luar, dan
  /// sel yang diawali `=`, `+`, `-`, atau `@` akan DIJALANKAN Excel saat
  /// berkasnya dibuka — termasuk `=HYPERLINK(...)` yang mengirim isi baris lain
  /// ke alamat mana pun, dan pada Excel lama `=cmd|...` yang menjalankan
  /// perintah.
  ///
  /// Yang menanggung akibatnya bukan KamelScan melainkan pelanggan yang
  /// membuka ekspornya sendiri, dan ia tidak punya cara mengetahui bahwa
  /// nomor resi dari sebuah pesanan adalah muatan berbahaya.
  ///
  /// Petik tunggal di depan adalah cara baku menonaktifkannya: Excel
  /// menampilkan selnya sebagai teks dan tidak menunjukkan petiknya.
  static String sel(String? nilai) {
    var teks = nilai ?? '';

    if (teks.isNotEmpty && _pemicuRumus.contains(teks[0])) {
      teks = "'$teks";
    }

    if (teks.contains('"') || teks.contains(',') ||
        teks.contains('\n') || teks.contains('\r')) {
      return '"${teks.replaceAll('"', '""')}"';
    }
    return teks;
  }

  /// Tanggal dalam bentuk yang dibaca sama oleh Excel di zona waktu mana pun.
  ///
  /// ⚠️ Sengaja `YYYY-MM-DD HH:MM`, bukan format lokal. `31/08/2026` dibaca
  /// Excel Amerika sebagai bulan ke-31 dan berubah menjadi teks, sehingga
  /// kolomnya tidak dapat diurutkan sama sekali.
  static String tanggal(DateTime? nilai) {
    if (nilai == null) return '';
    final d = nilai.toLocal();
    String dua(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${dua(d.month)}-${dua(d.day)} '
        '${dua(d.hour)}:${dua(d.minute)}';
  }

  /// Judul kolom. [label] menerjemahkan setiap kolom ke bahasa yang aktif.
  static String barisJudul(
    List<CsvColumn> kolom,
    String Function(CsvColumn) label,
  ) => kolom.map((k) => sel(label(k))).join(',');

  /// Satu baris data.
  static String baris(
    HistoryItem item,
    List<CsvColumn> kolom, {
    required String Function(CsvColumn, HistoryItem) nilai,
  }) => kolom.map((k) => sel(nilai(k, item))).join(',');

  /// Berkas lengkap: BOM, judul, lalu satu baris per riwayat.
  ///
  /// Mengembalikan hanya BOM dan barisan judul bila [items] kosong — berkas
  /// berisi judul saja lebih jujur daripada berkas nol byte, yang terbaca
  /// seperti unduhan yang gagal.
  static String bangun({
    required List<HistoryItem> items,
    required List<CsvColumn> kolom,
    required String Function(CsvColumn) label,
    required String Function(CsvColumn, HistoryItem) nilai,
  }) {
    final buf = StringBuffer(bom)
      ..write(barisJudul(kolom, label))
      ..write(eol);

    for (final item in items) {
      buf
        ..write(baris(item, kolom, nilai: nilai))
        ..write(eol);
    }
    return buf.toString();
  }

  /// Nama berkas yang aman di seluruh sistem berkas.
  ///
  /// Titik dua pada jam (`14:30`) ilegal di Windows dan membuat unduhannya
  /// gagal tanpa pesan apa pun.
  static String namaBerkas(DateTime kini, {String awalan = 'kamelscan-riwayat'}) {
    String dua(int n) => n.toString().padLeft(2, '0');
    final d = kini.toLocal();
    return '$awalan-${d.year}${dua(d.month)}${dua(d.day)}'
        '-${dua(d.hour)}${dua(d.minute)}.csv';
  }
}
