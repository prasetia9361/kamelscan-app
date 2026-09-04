import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ikon aplikasi — Android, web, dan iOS.
///
/// 🔴 Ditemukan Product Owner 4 September 2026: aplikasi masih memakai ikon
/// bawaan Flutter, di HP maupun di web. Ia hidup melewati seluruh pengembangan
/// dan tiga rilis uji, karena tidak ada satu pun jalur yang dapat
/// menandainya — `dart analyze` tidak membaca PNG, dan tes widget tidak
/// menyentuh berkas peluncur.
///
/// Yang dijaga berkas ini bukan "ikonnya bagus" — itu di luar jangkauan tes.
/// Yang dijaga: ikonnya **sudah diganti** (dibandingkan dengan sidik berkas
/// bawaan Flutter yang sebenarnya), dan ikon adaptif Android **tidak terpotong**
/// saat peluncur memotongnya menjadi lingkaran.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Seluruh piksel [berkas] sebagai RGBA.
  Future<(int lebar, int tinggi, ByteData piksel)> baca(String berkas) async {
    final bytes = await File(berkas).readAsBytes();
    final kodek = await ui.instantiateImageCodec(bytes);
    final bingkai = await kodek.getNextFrame();
    final data = await bingkai.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    return (bingkai.image.width, bingkai.image.height, data!);
  }

  // ==========================================================================
  // Setiap ikon memang sudah diganti
  // ==========================================================================
  //
  // 🔴 Percobaan pertama tes ini memeriksa "ikonnya mengandung biru merek",
  // dan itu penjagaan yang TIDAK MENJAGA APA PUN: logo Flutter juga biru, jadi
  // ikon bawaannya lolos dengan mulus. Bentuk kegagalan yang sama sudah dua
  // kali muncul di proyek ini — tes yang hijau sambil mengunci cacatnya.
  //
  // Yang dipakai sekarang: sidik SHA-256 berkas bawaan Flutter yang sebenarnya,
  // diambil dari git sebelum penggantian. Ia tidak dapat lolos karena
  // kebetulan.
  group('🔴 bukan lagi ikon bawaan Flutter', () {
    const bawaan = {
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png':
          '3c34e1f298d0c9ea3455d46db6b7759c8211a49e9ec6e44b635fc5c87dfb4180',
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png':
          'c7c0c0189145e4e32a401c61c9bdc615754b0264e7afae24e834bb81049eaf81',
      'web/favicon.png':
          '7ab2525f4b86b65d3e4c70358a17e5a1aaf6f437f99cbcc046dad73d59bb9015',
      'web/icons/Icon-192.png':
          '3dce99077602f70421c1c6b2a240bc9b83d64d86681d45f2154143310c980be3',
      'web/icons/Icon-512.png':
          'baccb205ae45f0b421be1657259b4943ac40c95094ab877f3bcbe12cd544dcbe',
      'web/icons/Icon-maskable-192.png':
          'd2c842e22a9f4ec9d996b23373a905c88d9a203b220c5c151885ad621f974b5c',
      'web/icons/Icon-maskable-512.png':
          '6aee06cdcab6b2aef74b1734c4778f4421d2da100b0ff9e52b21b55240202929',
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
              'Icon-App-1024x1024@1x.png':
          '7770183009e914112de7d8ef1d235a6a30c5834424858e0d2f8253f6b8d31926',
    };

    bawaan.forEach((berkas, sidikBawaan) {
      test('$berkas sudah diganti', () {
        final f = File(berkas);
        expect(f.existsSync(), isTrue, reason: '$berkas tidak ada');

        final sidik = sha256.convert(f.readAsBytesSync()).toString();
        expect(
          sidik,
          isNot(sidikBawaan),
          reason: '$berkas masih berkas bawaan Flutter, byte demi byte',
        );
      });
    });
  });

  // ==========================================================================
  // 🔴 Ikon adaptif tidak boleh terpotong
  // ==========================================================================
  //
  // Android menggambar `ic_launcher_foreground` pada kanvas 108dp lalu
  // memotongnya sesuai bentuk peluncur — lingkaran, kotak bulat, atau squircle.
  // Yang dijamin selamat hanya LINGKARAN berjari-jari 36dp di tengahnya.
  //
  // ⚠️ Cacat yang dijaga di sini benar-benar terjadi saat ikon ini dibuat.
  // Percobaan pertama memakai zona aman 61% dengan alasan "66 dari 108dp" —
  // dan itu keliru: 61% berlaku untuk PANJANG SISI, sedangkan yang memotong
  // adalah lingkaran. Seni selebar 60dp masih punya sudut berjarak 40dp dari
  // pusat, sementara lingkarannya hanya berjari-jari 36dp. Ujung centangnya
  // terpotong, dan hanya terlihat setelah pemotongannya disimulasikan.
  group('🔴 ikon adaptif utuh di dalam lingkaran 72dp', () {
    const densitas = {
      'mdpi': 108,
      'hdpi': 162,
      'xhdpi': 216,
      'xxhdpi': 324,
      'xxxhdpi': 432,
    };

    densitas.forEach((folder, sisi) {
      test('$folder — tidak ada seni di luar zona aman', () async {
        final (w, h, p) = await baca(
          'android/app/src/main/res/mipmap-$folder/ic_launcher_foreground.png',
        );

        expect(w, sisi, reason: 'kanvas adaptif $folder wajib ${sisi}px');
        expect(h, sisi);

        final pusat = (sisi - 1) / 2.0;
        final aman = sisi * 36.0 / 108.0;
        var terjauh = 0.0;

        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            if (p.getUint8((y * w + x) * 4 + 3) <= 24) continue;
            final d = math.sqrt(
              math.pow(x - pusat, 2) + math.pow(y - pusat, 2),
            );
            if (d > terjauh) terjauh = d;
          }
        }

        expect(
          terjauh,
          lessThanOrEqualTo(aman),
          reason: 'seni menjangkau ${terjauh.toStringAsFixed(1)}px dari pusat, '
              'melewati batas ${aman.toStringAsFixed(1)}px — peluncur '
              'berbentuk lingkaran akan memotongnya',
        );
      });
    });
  });

  // ==========================================================================
  // Berkas pendukung Android
  // ==========================================================================
  group('ikon adaptif benar-benar terpasang', () {
    // 🔴 Tanpa XML ini, Android 8+ mengabaikan `ic_launcher_foreground` dan
    // kembali memakai PNG warisan — yang lalu dikecilkan dan ditempel di atas
    // petak putih buatan peluncur. Hasilnya terlihat persis seperti aplikasi
    // yang lupa diberi ikon. Redmi Note 9 Product Owner berjalan di API 29,
    // jadi berkas inilah yang ia lihat.
    test('mipmap-anydpi-v26/ic_launcher.xml ada dan menunjuk keduanya', () {
      final f = File(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      );
      expect(f.existsSync(), isTrue);

      final isi = f.readAsStringSync();
      expect(isi, contains('<adaptive-icon'));
      expect(isi, contains('@color/ic_launcher_background'));
      expect(isi, contains('@mipmap/ic_launcher_foreground'));
    });

    test('warna latarnya terdefinisi', () {
      final f = File(
        'android/app/src/main/res/values/ic_launcher_background.xml',
      );
      expect(f.existsSync(), isTrue);
      expect(f.readAsStringSync(), contains('name="ic_launcher_background"'));
    });

    test('kelima densitas punya foreground', () {
      for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        expect(
          File('android/app/src/main/res/mipmap-$d/'
                  'ic_launcher_foreground.png')
              .existsSync(),
          isTrue,
          reason: 'densitas $d tidak punya foreground',
        );
      }
    });
  });

  // ==========================================================================
  // iOS
  // ==========================================================================
  test('🔴 ikon iOS tidak boleh bersaluran alpha', () async {
    // App Store MENOLAK ikon ber-alpha, dan penolakannya datang saat unggah —
    // bukan saat membangun. Kegagalan yang paling akhir datang adalah
    // kegagalan yang paling mahal.
    final (w, h, p) = await baca(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
      'Icon-App-1024x1024@1x.png',
    );

    for (var i = 0; i < w * h; i++) {
      if (p.getUint8(i * 4 + 3) != 255) {
        fail('ada piksel tembus pandang pada ikon 1024 — App Store menolaknya');
      }
    }
  });
}
