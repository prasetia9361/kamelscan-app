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

  group('plaqueHeight & plaqueOffset — jarak atas/bawah plakat', () {
    // 🔴 Ditambahkan 3 September 2026 bersama `padTop`/`padBottom`. Sebelum
    // ini kepala plakat digambar tepat pada tepi bidang gelapnya di sisi
    // video — sementara pratinjau di layar rekam memberinya jarak. Product
    // Owner melihat keduanya berdampingan dan melaporkan tidak samanya.
    test('tinggi blok memasukkan padTop DAN padBottom', () {
      // 1 baris (hanya resi): padTop(8) + kickerLine(15) + resiLine(34)
      // + padBottom(6) = 63.
      expect(WatermarkCommand.plaqueHeight(1), 63);
      // 4 baris: 63 + metaLine(18) × 3 = 117.
      expect(WatermarkCommand.plaqueHeight(4), 117);
    });

    test('kepala (indeks −1) dimulai pada padTop, bukan pada 0', () {
      expect(WatermarkCommand.plaqueOffset(-1), WatermarkCommand.padTop);
      expect(WatermarkCommand.padTop, greaterThan(0),
          reason: 'padTop=0 berarti cacat lamanya kembali');
    });

    test('baris resi (indeks 0) berdiri sesudah kepala', () {
      expect(
        WatermarkCommand.plaqueOffset(0),
        WatermarkCommand.plaqueOffset(-1) + 15, // _kickerLine, lewat offset
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

    // =======================================================================
    // 🔴 Warna kepala dan kepekatan — satu sumber, bukan ditulis dua kali
    // =======================================================================
    //
    // Diminta Product Owner 3 September 2026 sesudah melihat video sungguhan
    // pertamanya: kepala plakat nyaris tak terbaca dan bidang gelapnya terasa
    // terlalu pekat. Diukur ke kode, bukan ditebak: sampai saat itu pratinjau
    // di layar rekam dan sisi video menulis warnanya sendiri-sendiri —
    // pratinjau emas terang, video coklat gelap sewarna garis aksen.
    group('kepala & kepekatan — satu sumber untuk video dan pratinjau', () {
      test('kepala memakai kickerArgb, BUKAN warna aksen', () {
        final c = chain(WatermarkPosition.bottomLeft);
        final kicker = WatermarkCommand.hexOf(WatermarkCommand.kickerArgb);
        expect(c, contains('fontcolor=$kicker@0.95'));

        // 🔴 Sebelum 3 September 2026 nilainya sama dengan warna aksen —
        // coklat gelap di atas bidang tembus pandang, praktis tidak terbaca.
        expect(WatermarkCommand.kickerArgb, isNot(WatermarkCommand.accentArgb));
      });

      test('plaqueBoxOpacity lebih transparan dari kepekatan lama (0,75)',
          () {
        expect(WatermarkCommand.plaqueBoxOpacity, lessThan(0.75));

        // ⚠️ Bukan sekadar "lebih transparan" tanpa batas — Bab 8.5 menulis
        // bidang gelap ini ada karena teks putih di atas kardus terang tidak
        // terbaca. Turun terlalu jauh mengembalikan masalah yang sama.
        expect(WatermarkCommand.plaqueBoxOpacity, greaterThanOrEqualTo(0.4));
      });

      test('bawaan buildFilterChain TIDAK ikut berubah — pemanggil wajib '
          'menyebutnya', () {
        // buildFilterChain sendiri masih berbawaan 0.5 (dipakai tes-tes lain
        // di berkas ini yang tidak menyebut boxOpacity). Yang berubah adalah
        // apa yang DIKIRIM `video_processor_mobile.dart` dan
        // `recording_camera_view_model.dart` — keduanya sekarang mengirim
        // `WatermarkCommand.plaqueBoxOpacity` secara eksplisit, bukan
        // mengandalkan bawaan ini.
        expect(
          chain(WatermarkPosition.bottomLeft),
          contains('color=black@0.5'),
        );
      });
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

    // =======================================================================
    // 🔴 drawbox memakai iw/ih, drawtext memakai w/h
    // =======================================================================
    //
    // Cacat yang dijawab ketiga tes di bawah menghentikan SELURUH perekaman,
    // dan tidak satu pun dari 687 tes menangkapnya — karena semuanya memeriksa
    // string yang disusun, bukan apakah FFmpeg menerimanya.
    //
    // Di `drawbox`, `w`/`h` dalam ekspresi berarti ukuran KOTAK yang sedang
    // digambar; ukuran videonya `iw`/`ih`. Di `drawtext` justru sebaliknya.
    // Dua filter bersebelahan memakai arti berlawanan untuk huruf yang sama.
    //
    // Semula tertulis `y=h-16-103`, yang di drawbox berarti
    // `103-16-103` = −16, dan `w=w-32` bahkan menunjuk dirinya sendiri.
    // FFmpeg menolaknya dengan kode 1, video berhenti selamanya di antrean
    // lokal, dan satu-satunya keterangan yang tersimpan berbunyi
    // "FFmpeg keluar dengan kode 1".
    //
    // Ditemukan Product Owner 3 September 2026, dan sudah gagal sejak plakat
    // ini dibuat — sama di worktree `revisi-desain-aplikasimobile`.
    group('🔴 satuan ukuran drawbox vs drawtext', () {
      /// Potongan `drawbox=` saja.
      ///
      /// ⚠️ Diambil dengan pola, BUKAN `split(',')`. Teks watermark memuat
      /// koma — koordinat GPS `-7.250445, 112.768845` salah satunya — sehingga
      /// memecah rantai filter pada setiap koma akan mencacah satu `drawtext`
      /// menjadi beberapa potongan palsu. Parameter `drawbox` sendiri tidak
      /// pernah memuat koma, jadi pola ini aman.
      List<String> kotak(WatermarkPosition p) => RegExp(r'drawbox=[^,]*')
          .allMatches(chain(p))
          .map((m) => m.group(0)!)
          .toList();

      test('drawbox TIDAK PERNAH memakai w/h polos sebagai ukuran video', () {
        for (final p in WatermarkPosition.values) {
          final daftar = kotak(p);
          expect(daftar, hasLength(2), reason: 'harus dua drawbox');

          for (final f in daftar) {
            expect(
              f,
              isNot(matches(RegExp(r'[:=]w-'))),
              reason: '$f memakai `w` sebagai lebar video — di drawbox itu '
                  'lebar kotaknya sendiri, jadi `w-32` menunjuk dirinya '
                  'sendiri. Harus `iw`.',
            );
            expect(
              f,
              isNot(matches(RegExp(r'y=h-'))),
              reason: '$f memakai `h` sebagai tinggi video — di drawbox itu '
                  'tinggi kotaknya sendiri, jadi hasilnya negatif. Harus `ih`.',
            );
          }
        }
      });

      test('drawbox memakai iw/ih saat plakat ditambatkan ke bawah', () {
        for (final p in [
          WatermarkPosition.bottomLeft,
          WatermarkPosition.bottomRight,
        ]) {
          final daftar = kotak(p);
          for (final f in daftar) {
            expect(f, contains('y=ih-'), reason: f);
          }
          expect(daftar.first, contains('w=iw-'), reason: daftar.first);
        }
      });

      test('drawtext tetap memakai h — di sana artinya memang tinggi video',
          () {
        final c = chain(WatermarkPosition.bottomRight);

        // Dihitung, bukan dipecah: `y=ih-` hanya boleh muncul pada kedua
        // drawbox, dan tidak sekali pun pada drawtext.
        expect('y=ih-'.allMatches(c).length, 2);
        expect(c, contains(':y=h-16-'));
      });
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
      //
      // 🔴 `iw`, bukan `w`. Tes ini semula menuntut `w=w-32:` dan karena itu
      // ikut MENGUNCI cacat yang menghentikan seluruh perekaman: di drawbox
      // `w` adalah lebar kotaknya sendiri, sehingga `w=w-32` menunjuk dirinya
      // sendiri dan FFmpeg keluar dengan kode 1. Ia benar saat ditulis dan
      // menjadi salah tanpa pernah gagal. Uraiannya di grup di bawah.
      expect(chain(WatermarkPosition.bottomRight), contains('w=iw-32:'));
    });

    test('blok ditambatkan ke sudut yang diminta', () {
      // 4 baris → tinggi blok padTop(8) + 15 + 34 + (18 × 3) + padBottom(6)
      // = 117.
      //
      // ⚠️ Diperiksa pada KEDUA satuan sekaligus, dan itu disengaja: `ih-16-117`
      // milik drawbox, `h-16-117` milik drawtext. Sebelum 3 September 2026
      // baris ini hanya menuntut `y=h-16-...` — yang tetap lulus lewat
      // drawtext walaupun drawbox-nya rusak, sehingga ia tidak menjaga apa pun
      // pada filter yang justru gagal.
      final c = chain(WatermarkPosition.bottomLeft);

      // drawbox — seluruh blok, memakai satuan video `ih`.
      expect(c, contains('y=ih-16-117'));

      // drawtext kepala — turun `padTop` (8) dari puncak blok, jadi
      // 117 − 8 = 109. Sengaja BUKAN 117: kalau sama, artinya `padTop`
      // hilang lagi dan huruf kembali menempel di tepi bidang gelapnya.
      expect(c, contains('y=h-16-109'));
      expect(c, isNot(contains('y=h-16-117')));

      expect(chain(WatermarkPosition.topLeft), contains(':y=16:'));
    });

    test('baris berjarak tetap, tidak saling menimpa', () {
      final c = chain(WatermarkPosition.topLeft);
      // margin(16) + padTop(8) = 24 untuk kepala; resi 24 + kickerLine(15)
      // = 39; lalu tiga keterangan tiap metaLine(18) px sesudah resiLine(34).
      //
      // ⚠️ Angkanya bergeser 8 px pada 3 September 2026 karena `padTop`
      // ditambahkan — sebelumnya kepala menempel di tepi bidang gelapnya.
      for (final y in ['y=24', 'y=39', 'y=73', 'y=91', 'y=109']) {
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
