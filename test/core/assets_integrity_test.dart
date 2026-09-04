import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 🔴 Aset gambar terpotong lolos ke aplikasi — 1 September 2026.
///
/// `assets/images/logo-mark.png` ditulis dari keluaran alat yang dipotong pada
/// batas 256 KB. Berkasnya tetap punya tanda tangan PNG dan header `IHDR` yang
/// sah, sehingga `file` melaporkannya "PNG image data, 873 x 626" dan pemuat
/// gambar Windows membukanya tanpa mengeluh — tetapi tidak punya penanda akhir
/// `IEND`. Di aplikasi, bidang logonya tergambar **kosong**, dan Product Owner
/// melaporkannya sebagai "logo aplikasi belum ada".
///
/// Ukurannya 196.608 byte — persis 192 KiB. Angka sebulat itu pada berkas
/// gambar hampir selalu berarti pemotongan, bukan kebetulan.
///
/// Yang diuji di sini bukan bagus atau tidaknya gambar, melainkan bahwa tiap
/// berkas **utuh** dan **benar-benar terdaftar**. `flutter analyze` tidak
/// pernah melihat isi berkas aset, dan tidak ada tes widget yang akan gagal
/// karena sebuah gambar gagal didekode — `Image.asset` hanya menggambar ruang
/// kosong.
void main() {
  /// Tanda tangan PNG: 8 byte pertama, tetap untuk semua berkas PNG.
  const tandaTangan = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  final berkas = Directory('assets')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.png'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('ada berkas PNG untuk diperiksa', () {
    // Penjaga bagi tes ini sendiri: kalau foldernya pindah, seluruh grup di
    // bawah akan lulus tanpa memeriksa apa pun.
    expect(berkas, isNotEmpty);
  });

  for (final f in berkas) {
    final nama = f.path.replaceAll(r'\', '/');

    test('$nama — utuh', () {
      final b = f.readAsBytesSync();

      expect(b.length, greaterThan(67), reason: '$nama terlalu kecil');
      expect(
        b.sublist(0, 8),
        tandaTangan,
        reason: '$nama bukan PNG yang sah',
      );

      // 🔴 Inti tes ini. Tanpa `IEND` berkasnya terpotong, dan gejalanya di
      // aplikasi adalah ruang kosong — bukan galat yang bisa dilacak.
      final ekor = String.fromCharCodes(b.sublist(b.length - 8, b.length - 4));
      expect(
        ekor,
        'IEND',
        reason: '$nama TERPOTONG — tidak ada penanda akhir IEND. '
            'Ukurannya ${b.length} byte.',
      );
    });
  }

  test('🔴 setiap folder aset yang dipakai terdaftar di pubspec.yaml', () {
    // Aset yang tidak terdaftar juga tergambar kosong, dengan gejala yang
    // persis sama seperti berkas terpotong.
    //
    // Dibaca sebagai teks, bukan lewat paket `yaml`: menambah satu dependensi
    // hanya untuk mencari satu baris tidak sebanding, dan bentuk yang dicari
    // di sini memang satu baris daftar.
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final terdaftar = pubspec
        .map((l) => l.trim())
        .where((l) => l.startsWith('- assets/'))
        .map((l) => l.substring(2).trim())
        .toSet();

    expect(terdaftar, isNotEmpty,
        reason: 'Tidak ada satu pun baris "- assets/..." di pubspec.yaml');

    final folder = berkas
        .map((f) => '${f.parent.path.replaceAll(r'\', '/')}/')
        .toSet();

    for (final d in folder) {
      expect(
        terdaftar.contains(d) || terdaftar.contains(d.substring(0, d.length - 1)),
        isTrue,
        reason: 'Folder $d berisi PNG tetapi tidak terdaftar di pubspec.yaml. '
            'Yang terdaftar: $terdaftar',
      );
    }
  });
}
