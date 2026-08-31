import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/domain/capacity_status.dart';

/// Kartu Kapasitas Dasbor Platform (Bab 11.1).
///
/// 🔴 Kartu ini ada supaya Product Owner **tidak perlu mengingat** untuk
/// memeriksa. Batas 8 GB Supabase Pro tidak mengirim peringatan apa pun sampai
/// tercapai, dan yang terjadi saat tercapai bukan aplikasi melambat melainkan
/// penulisan ditolak: packer tidak dapat menyimpan satu video pun.
///
/// Karena itu yang paling penting diuji di sini bukan angkanya, melainkan
/// **kapan kartunya berubah warna** — dan bahwa ia tidak pernah berkata aman
/// pada keadaan yang tidak aman.
void main() {
  const gb = 1024 * 1024 * 1024;

  CapacityStats stats({
    int dbBytes = gb,
    int videoRows = 1000,
    int bytes30d = 0,
    int rows30d = 0,
    int purgeQueue = 0,
    int purgeFailed = 0,
  }) => CapacityStats(
    dbBytes: dbBytes,
    dbLimitBytes: 8 * gb,
    videoRows: videoRows,
    videoBytes: 0,
    rows30d: rows30d,
    bytes30d: bytes30d,
    purgeQueue: purgeQueue,
    purgeFailed: purgeFailed,
  );

  group('Ambang database (5 GB / 6,5 GB)', () {
    test('di bawah 5 GB aman', () {
      expect(stats(dbBytes: 4 * gb).levelDatabase, CapacityLevel.aman);
    });

    test('tepat 5 GB sudah masuk siapkan', () {
      expect(stats(dbBytes: 5 * gb).levelDatabase, CapacityLevel.siapkan);
    });

    test('di atas 6,5 GB harus bertindak', () {
      expect(
        stats(dbBytes: (6.6 * gb).round()).levelDatabase,
        CapacityLevel.bertindak,
      );
    });
  });

  group('Ambang jumlah baris (10 juta / 30 juta)', () {
    test('di bawah 10 juta aman', () {
      expect(stats(videoRows: 9999999).levelBaris, CapacityLevel.aman);
    });

    test('tepat 10 juta sudah masuk siapkan', () {
      expect(stats(videoRows: 10000000).levelBaris, CapacityLevel.siapkan);
    });

    test('di atas 30 juta harus bertindak', () {
      expect(stats(videoRows: 30000001).levelBaris, CapacityLevel.bertindak);
    });
  });

  group('Ramalan "berapa bulan lagi"', () {
    test('dihitung dari sisa ruang dibagi pertumbuhan 30 hari', () {
      // Terpakai 4 GB dari 8 GB, tumbuh 1 GB per 30 hari → sisa 4 bulan.
      final s = stats(dbBytes: 4 * gb, bytes30d: gb);

      expect(s.bulanSampaiPenuh, closeTo(4, 0.01));
    });

    // 🔴 Pembagian dengan nol. Tanpa penjagaan ini nilainya `Infinity`, dan
    // `Infinity.round()` melempar saat hendak ditampilkan — kartunya
    // meruntuhkan seluruh Dasbor Platform, bukan sekadar salah angka.
    test('tanpa pertumbuhan tidak dapat diramalkan, bukan nol', () {
      expect(stats(bytes30d: 0).bulanSampaiPenuh, isNull);
    });

    test('pertumbuhan negatif juga tidak dapat diramalkan', () {
      // Database yang menyusut memang tidak akan mencapai batasnya, tetapi
      // menulis "tidak akan pernah" dari satu bulan yang kebetulan sepi adalah
      // janji yang tidak dapat ditepati.
      expect(stats(bytes30d: -gb).bulanSampaiPenuh, isNull);
    });

    test('sudah melewati batas berarti nol bulan', () {
      expect(stats(dbBytes: 9 * gb, bytes30d: gb).bulanSampaiPenuh, 0);
    });
  });

  group('Ramalan pendek menaikkan level walau angka hari ini sehat', () {
    test('kurang dari 3 bulan lagi = bertindak', () {
      // 2 GB terpakai — jauh di bawah ambang 5 GB — tetapi tumbuh 3 GB per
      // bulan. Kartu yang tetap hijau di sini akan hijau sampai hari
      // penulisan ditolak.
      final s = stats(dbBytes: 2 * gb, bytes30d: 3 * gb);

      expect(s.levelDatabase, CapacityLevel.aman);
      expect(s.level, CapacityLevel.bertindak);
    });

    test('antara 3 dan 6 bulan = siapkan', () {
      final s = stats(dbBytes: 2 * gb, bytes30d: (1.2 * gb).round());

      expect(s.bulanSampaiPenuh, closeTo(5, 0.1));
      expect(s.level, CapacityLevel.siapkan);
    });

    test('lebih dari 6 bulan dan angka sehat = aman', () {
      final s = stats(dbBytes: gb, bytes30d: gb ~/ 4);

      expect(s.level, CapacityLevel.aman);
    });
  });

  group('Antrean penghapusan R2', () {
    // Antrean yang menumpuk berarti `purge-storage` tidak pernah berjalan —
    // tepat keadaan yang membuat tagihan R2 tumbuh diam-diam.
    test('satu kegagalan sudah cukup untuk memperingatkan', () {
      expect(stats(purgeFailed: 1).levelAntrean, CapacityLevel.siapkan);
    });

    test('antrean besar tanpa kegagalan juga memperingatkan', () {
      expect(stats(purgeQueue: 50001).levelAntrean, CapacityLevel.siapkan);
    });

    test('antrean wajar tidak memperingatkan', () {
      expect(stats(purgeQueue: 120).levelAntrean, CapacityLevel.aman);
    });
  });

  group('Level kartu mengambil yang TERBURUK', () {
    // Kartu hijau karena dua dari tiga angkanya sehat adalah kartu yang
    // menyembunyikan satu-satunya angka yang perlu dibaca.
    test('satu angka merah mewarnai seluruh kartu', () {
      final s = stats(dbBytes: gb, videoRows: 100, purgeFailed: 3);

      expect(s.levelDatabase, CapacityLevel.aman);
      expect(s.levelBaris, CapacityLevel.aman);
      expect(s.level, CapacityLevel.siapkan);
    });

    test('bertindak mengalahkan siapkan', () {
      final s = stats(dbBytes: 7 * gb, purgeFailed: 1);

      expect(s.level, CapacityLevel.bertindak);
    });
  });

  group('Pembacaan JSON', () {
    test('batas yang tidak dikirim server jatuh ke 8 GB, bukan nol', () {
      // Nol akan membuat `dbRatio` membagi dengan nol dan bilah kemajuannya
      // menampilkan NaN.
      final s = CapacityStats.fromJson(const {'db_bytes': 1000});

      expect(s.dbLimitBytes, 8 * gb);
      expect(s.dbRatio, closeTo(0, 0.001));
    });

    test('rasio tidak pernah melebihi 1', () {
      final s = CapacityStats.fromJson({
        'db_bytes': 99 * gb,
        'db_limit_bytes': 8 * gb,
      });

      expect(s.dbRatio, 1.0);
    });

    test('kolom yang hilang menjadi nol, bukan melempar', () {
      final s = CapacityStats.fromJson(const {});

      expect(s.dbBytes, 0);
      expect(s.videoRows, 0);
      expect(s.level, CapacityLevel.aman);
    });
  });
}
