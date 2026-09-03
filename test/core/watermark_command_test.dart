import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/domain/watermark_command.dart';
import 'package:kamelscan/core/models/enums.dart';

void main() {
  group('escapeDrawText — penyebab kegagalan ffmpeg paling sering (Bab 8.5)', () {
    test('titik dua di-escape', () {
      expect(WatermarkCommand.escapeDrawText('RESI: 123'), r'RESI\: 123');
    });

    test('jam dengan dua titik dua ikut ter-escape semuanya', () {
      expect(
        WatermarkCommand.escapeDrawText('14:30:22'),
        r'14\:30\:22',
      );
    });

    test('petik satu di-escape — nama toko sering memakainya', () {
      expect(
        WatermarkCommand.escapeDrawText("Toko D'Grosir"),
        r"Toko D\'Grosir",
      );
    });

    test('persen di-escape agar tidak dibaca sebagai penanda format', () {
      expect(WatermarkCommand.escapeDrawText('Diskon 50%'), r'Diskon 50\%');
    });

    test('garis miring terbalik di-escape LEBIH DULU, tidak berlipat', () {
      // Bila urutannya terbalik, escape yang baru ditambahkan ikut ter-escape
      // lagi dan hasilnya rusak.
      expect(WatermarkCommand.escapeDrawText(r'A\B'), r'A\\B');
      expect(WatermarkCommand.escapeDrawText(r'A\:B'), r'A\\\:B');
    });

    test('baris baru diubah jadi spasi, bukan merusak perintah', () {
      expect(
        WatermarkCommand.escapeDrawText('Toko\nCabang'),
        'Toko Cabang',
      );
      expect(WatermarkCommand.escapeDrawText('A\r\nB'), 'A  B');
    });

    test('teks biasa tidak berubah', () {
      expect(
        WatermarkCommand.escapeDrawText('SPXID000123456'),
        'SPXID000123456',
      );
    });

    test('gabungan karakter khusus sekaligus', () {
      expect(
        WatermarkCommand.escapeDrawText("GPS: -7.25, 112.76 (D'Toko) 50%"),
        r"GPS\: -7.25, 112.76 (D\'Toko) 50\%",
      );
    });
  });

  group('buildFilterChain (Bab 8.5)', () {
    List<String> lines() => [
          'RESI: SPXID000123456',
          '13/08/2026 14.30.22',
          'Toko Maju Jaya (Shopee)',
          'GPS: -7.250445, 112.768845',
        ];

    String chain(WatermarkPosition pos) => WatermarkCommand.buildFilterChain(
          lines: lines(),
          fontFile: '/system/fonts/Roboto-Regular.ttf',
          position: pos,
          heightPx: 480,
        );

    test('selalu diawali penurunan skala ke 480p (Bab 1.3 poin 3)', () {
      expect(chain(WatermarkPosition.bottomRight), startsWith('scale=-2:480,'));
    });

    test('satu drawtext tiap baris, PLUS kepala plakat', () {
      // 4 baris isi + 1 kepala `KAMELSCAN · BUKTI VIDEO`.
      expect(
        'drawtext='.allMatches(chain(WatermarkPosition.bottomLeft)).length,
        5,
      );
    });

    test('kepala plakat ikut tergambar', () {
      expect(
        chain(WatermarkPosition.bottomLeft),
        contains('KAMELSCAN'),
      );
    });

    test('satu bidang gelap untuk seluruh plakat, bukan kotak per baris', () {
      final c = chain(WatermarkPosition.bottomRight);
      // Bidang gelap + garis aksen camel = dua drawbox.
      expect('drawbox='.allMatches(c).length, 2);
      expect(c, contains('color=black@0.5'));
      // 🔴 Kotak per baris sudah tidak dipakai: bidang blok sudah gelap, dan
      // menumpuknya lagi membuat teks duduk di atas gelap berlapis.
      expect(c, isNot(contains('box=1:boxcolor')));
    });

    test('garis aksen camel ada di tepi plakat', () {
      expect(
        chain(WatermarkPosition.bottomLeft),
        contains('color=0x9A5B00@0.95'),
      );
    });

    test('fontfile selalu disertakan — drawtext gagal tanpanya', () {
      // Terverifikasi di perangkat: tanpa fontfile, drawtext keluar kode 1.
      expect(
        chain(WatermarkPosition.topLeft),
        contains('fontfile=/system/fonts/Roboto-Regular.ttf'),
      );
    });

    test('🔴 seluruh baris mulai di x yang SAMA — plakat rata kiri', () {
      // Bentuk lama memakai `w-tw-16` pada sudut kanan, sehingga tiap baris
      // mulai di tempat berbeda menurut panjangnya sendiri. Yang paling
      // terganggu justru nomor resi: posisi awalnya berpindah tiap kali
      // panjang resinya berbeda, padahal itu angka yang dibaca orang.
      for (final pos in WatermarkPosition.values) {
        final c = chain(pos);
        expect('x=28:'.allMatches(c).length, 5, reason: '$pos');
        expect(c, isNot(contains('w-tw')), reason: '$pos');
      }
    });

    test('plakat selebar bidang video, bukan setengahnya', () {
      // Pratinjau di layar rekam menggambarnya selebar layar. Kalau di sini
      // setengah lebar, packer melihat satu bentuk dan mendapat bentuk lain
      // di videonya — kesalahan yang dilarang dartdoc pratinjau itu sendiri.
      expect(chain(WatermarkPosition.bottomRight), contains('w=w-32:'));
    });

    test('blok ditambatkan ke sudut yang diminta', () {
      // 4 baris → tinggi blok 15 + 34 + (18 × 3) = 103.
      expect(chain(WatermarkPosition.bottomLeft), contains('y=h-16-103'));
      expect(chain(WatermarkPosition.topLeft), contains(':y=16:'));
    });

    test('baris berjarak tetap, tidak saling menimpa', () {
      final c = chain(WatermarkPosition.topLeft);
      // Kepala di 16, resi di 31, lalu tiga keterangan tiap 18 px.
      for (final y in ['y=16', 'y=31', 'y=65', 'y=83', 'y=101']) {
        expect(c, contains(':$y:'), reason: 'baris $y hilang');
      }
    });

    test('nomor resi memakai ukuran huruf jauh lebih besar', () {
      final c = chain(WatermarkPosition.bottomRight);
      expect(c, contains('fontsize=26'), reason: 'resi');
      expect(c, contains('fontsize=13'), reason: 'keterangan');
      expect(c, contains('fontsize=11'), reason: 'kepala plakat');
    });

    test('titik dua pada isi baris ikut ter-escape di dalam rantai', () {
      expect(chain(WatermarkPosition.topLeft), contains(r'RESI\: SPXID'));
    });
  });

  group('buildMetadataComment (Bab 8.5)', () {
    final t = DateTime.utc(2026, 8, 13, 7, 30, 22);

    test('memuat penanda aplikasi, resi, waktu, dan toko', () {
      final m = WatermarkCommand.buildMetadataComment(
        resiCode: 'SPXID000123456',
        serverTime: t,
        shopId: 'shop-1',
      );
      expect(m, startsWith('KamelScan|'));
      expect(m, contains('resi=SPXID000123456'));
      expect(m, contains('ts=2026-08-13T07:30:22.000Z'));
      expect(m, contains('shop_id=shop-1'));
    });

    test('koordinat disertakan hanya bila ada', () {
      final tanpa = WatermarkCommand.buildMetadataComment(
        resiCode: 'A123456', serverTime: t, shopId: 's1',
      );
      expect(tanpa, isNot(contains('lat=')));

      final dengan = WatermarkCommand.buildMetadataComment(
        resiCode: 'A123456', serverTime: t, shopId: 's1',
        lat: -7.250445, lng: 112.768845,
      );
      expect(dengan, contains('lat=-7.250445'));
      expect(dengan, contains('lng=112.768845'));
    });

    test('pemisah tidak bisa disusupkan lewat nomor resi', () {
      // Resi yang disusun khusus tidak boleh menambah medan metadata palsu.
      final m = WatermarkCommand.buildMetadataComment(
        resiCode: 'A123|shop_id=palsu',
        serverTime: t,
        shopId: 's1',
      );
      expect(m, contains('resi=A123shop_idpalsu'));
      expect('shop_id='.allMatches(m).length, 1);
    });
  });

  group('build — perintah utuh (Bab 8.5)', () {
    String cmd() => WatermarkCommand.build(
          inputPath: '/data/rekam mentah.mp4',
          outputPath: '/data/hasil.mp4',
          filterChain: 'scale=-2:480',
          metadataComment: 'KamelScan|resi=A1',
        );

    test('preset ultrafast dan crf 28 sesuai anggaran waktu 3 detik', () {
      expect(cmd(), contains('-preset ultrafast'));
      expect(cmd(), contains('-crf 28'));
    });

    test('faststart wajib agar video bisa diputar tanpa diunduh penuh', () {
      expect(cmd(), contains('-movflags +faststart'));
    });

    test('jalur berisi spasi dibungkus tanda kutip', () {
      expect(cmd(), contains('"/data/rekam mentah.mp4"'));
    });

    test('menimpa berkas keluaran tanpa bertanya', () {
      expect(cmd(), startsWith('-y '));
    });
  });

  group('buildLines — satu sumber isi watermark (Bab 8.5)', () {
    final waktu = DateTime.utc(2026, 8, 17, 12, 59);

    List<String> lines({
      String? coordinates,
      bool timeVerified = true,
      bool showGps = true,
    }) =>
        WatermarkCommand.buildLines(
          resiCode: '10952ERTY',
          serverTime: waktu,
          shopName: 'Shopee · Toko Uji',
          coordinates: coordinates,
          timeVerified: timeVerified,
          showGps: showGps,
        );

    test('nomor resi selalu pertama — ia digambar paling besar', () {
      // Bukan selera tata letak: indeks 0 adalah baris yang dicari petugas
      // resolusi marketplace, dan `buildFilterChain` memberinya huruf terbesar.
      //
      // Awalan `RESI:` dibuang 1 September 2026 — kepala plakat sudah
      // menyatakan blok ini bukti video, dan awalan itu hanya mendorong angka
      // terpentingnya ke kanan.
      expect(lines().first, '10952ERTY');
    });

    test('urutannya resi, waktu, GPS, lalu toko', () {
      expect(lines(coordinates: '-6.972683, 109.711146'), [
        '10952ERTY',
        WatermarkCommand.formatStamp(waktu),
        '-6.972683, 109.711146',
        'Shopee · Toko Uji',
      ]);
    });

    test('izin lokasi ditolak tetap menyisakan barisnya, bukan menghilang', () {
      // Baris yang hilang membuat pembacanya tidak dapat membedakan "lokasi
      // tidak ada" dari "versi aplikasi ini belum menulis lokasi".
      expect(lines(), contains('Lokasi tidak tersedia'));
    });

    test('GPS dimatikan tenant menghapus barisnya sama sekali', () {
      final hasil = lines(coordinates: '1, 2', showGps: false);
      expect(hasil, hasLength(3));
      expect(hasil.any((l) => l.contains('GPS')), isFalse);
      expect(hasil.any((l) => l.contains('Lokasi')), isFalse);
    });

    test('waktu belum terverifikasi ikut terbaca di gambar', () {
      // Aturan 4 Product Owner: videonya tetap dibuat, tetapi tidak boleh
      // tampil seolah waktunya terjamin.
      expect(
        lines(timeVerified: false)[1],
        contains('(waktu belum terverifikasi)'),
      );
    });
  });
}
