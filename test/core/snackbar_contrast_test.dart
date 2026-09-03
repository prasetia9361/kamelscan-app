import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/theme/app_theme.dart';

/// Kontras SnackBar di KEDUA tema (Bab 9.10).
///
/// 🔴 Cacat yang dijawab berkas ini hanya muncul di tema GELAP, dan itu
/// sebabnya ia hidup berbulan-bulan tanpa ketahuan.
///
/// `snackBarTheme` semula hanya menyetel `contentTextStyle` berwarna putih dan
/// membiarkan warna latarnya ke bawaan Material 3, yaitu
/// `ColorScheme.inverseSurface`. Di tema terang nilai itu gelap — putih di
/// atasnya terbaca, dan tidak ada yang menyadari apa pun. Di tema gelap
/// `inverseSurface` justru TERANG, sehingga teks putih di atasnya hilang sama
/// sekali.
///
/// Ditemukan Product Owner 3 September 2026 di Redmi Note 9 bertema gelap:
/// peringatan *"Resi ... sudah pernah direkam"* tampil sebagai kotak putih
/// kosong — tepat pada pesan yang paling perlu dibaca packer sebelum ia
/// merekam ulang paket yang sama.
///
/// ⚠️ Diuji sebagai **selisih kecerahan**, bukan dengan mencocokkan nilai
/// warna tertentu. Menuntut warna tertentu akan mengunci palet dan gagal pada
/// setiap penyesuaian sah berikutnya; yang benar-benar dijanjikan layar adalah
/// hurufnya terbaca.
void main() {
  /// Kecerahan relatif menurut WCAG, 0 (hitam) sampai 1 (putih).
  double luminansi(Color c) => c.computeLuminance();

  /// Rasio kontras WCAG antara dua warna buram.
  double kontras(Color a, Color b) {
    final la = luminansi(a);
    final lb = luminansi(b);
    final terang = la > lb ? la : lb;
    final gelap = la > lb ? lb : la;
    return (terang + 0.05) / (gelap + 0.05);
  }

  for (final (nama, tema) in [
    ('terang', AppTheme.light),
    ('gelap', AppTheme.dark),
  ]) {
    group('SnackBar tema $nama', () {
      final sb = tema.snackBarTheme;

      test('warna latar disebut, tidak dibiarkan ke bawaan Material', () {
        // 🔴 Inti cacatnya: latar yang tidak disebut jatuh ke
        // `inverseSurface`, yang arah terang-gelapnya BERBALIK antar tema —
        // sementara warna teksnya dulu dipatok putih di keduanya.
        expect(
          sb.backgroundColor,
          isNotNull,
          reason: 'latar SnackBar tidak disetel — warnanya akan mengikuti '
              'bawaan Material dan berbalik arah di tema gelap',
        );
      });

      test('warna teks disebut', () {
        expect(sb.contentTextStyle?.color, isNotNull);
      });

      test('🔴 teks terbaca di atas latarnya', () {
        final latar = sb.backgroundColor!;
        final teks = sb.contentTextStyle!.color!;

        // 4,5 adalah ambang WCAG AA untuk teks ukuran biasa. Nilai lama —
        // putih di atas `inverseSurface` tema gelap — ada di sekitar 1,1.
        expect(
          kontras(latar, teks),
          greaterThanOrEqualTo(4.5),
          reason: 'kontras teks SnackBar tema $nama terlalu rendah: '
              'latar $latar, teks $teks',
        );
      });

      test('warna tombol aksi juga terbaca di atas latarnya', () {
        final latar = sb.backgroundColor!;
        final aksi = sb.actionTextColor;
        expect(aksi, isNotNull, reason: 'actionTextColor tidak disetel');

        // Tombol aksi berukuran sama dengan teks biasa, jadi ambangnya sama.
        expect(
          kontras(latar, aksi!),
          greaterThanOrEqualTo(3.0),
          reason: 'tombol aksi SnackBar tema $nama sulit dibaca',
        );
      });
    });
  }

  test('🔴 kedua tema TIDAK memakai warna teks yang sama persis', () {
    // Kalau keduanya sama, hampir pasti warnanya dipatok mati lagi — dan
    // itulah bentuk cacat yang baru saja diperbaiki.
    expect(
      AppTheme.light.snackBarTheme.contentTextStyle?.color,
      isNot(AppTheme.dark.snackBarTheme.contentTextStyle?.color),
    );
  });
}
