/// Seberapa mendesak keadaan kapasitas platform (Bab 11.1).
enum CapacityLevel {
  /// Tidak ada yang perlu dikerjakan.
  aman,

  /// Belum mendesak, tetapi mulai siapkan langkahnya.
  siapkan,

  /// Bertindak sekarang.
  bertindak,
}

/// Angka kapasitas platform beserta ramalannya.
///
/// 🔴 **Yang dijawab kelas ini adalah "berapa lama lagi", bukan "sudah
/// berapa".** Angka 4,2 GB tidak memberi tahu siapa pun kapan harus bertindak.
/// Batas 8 GB Supabase Pro tidak mengirim peringatan apa pun sampai tercapai,
/// dan yang terjadi saat tercapai bukan aplikasi melambat melainkan
/// **penulisan ditolak** — packer tidak dapat menyimpan satu video pun, tanpa
/// satu layar pun yang dapat menjelaskan kenapa.
///
/// Ambangnya ditetapkan Product Owner 31 Agustus 2026.
class CapacityStats {
  const CapacityStats({
    required this.dbBytes,
    required this.dbLimitBytes,
    required this.videoRows,
    required this.videoBytes,
    required this.rows30d,
    required this.bytes30d,
    required this.purgeQueue,
    required this.purgeFailed,
  });

  final int dbBytes;
  final int dbLimitBytes;
  final int videoRows;
  final int videoBytes;

  /// Pertumbuhan 30 hari terakhir — dasar seluruh ramalan di bawah.
  final int rows30d;
  final int bytes30d;

  /// Berkas R2 yang menunggu dihapus, dan yang penghapusannya sudah pernah
  /// gagal.
  final int purgeQueue;
  final int purgeFailed;

  factory CapacityStats.fromJson(Map<String, dynamic> json) {
    int asInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return CapacityStats(
      dbBytes: asInt('db_bytes'),
      // Batasnya datang dari server supaya naik paket Supabase tidak menuntut
      // rilis aplikasi baru. Nol berarti server belum mengirimkannya, dan
      // membaginya akan menghasilkan tak hingga — jadi jatuh ke 8 GB.
      dbLimitBytes: asInt('db_limit_bytes') > 0
          ? asInt('db_limit_bytes')
          : 8 * 1024 * 1024 * 1024,
      videoRows: asInt('video_rows'),
      videoBytes: asInt('video_bytes'),
      rows30d: asInt('rows_30d'),
      bytes30d: asInt('bytes_30d'),
      purgeQueue: asInt('purge_queue'),
      purgeFailed: asInt('purge_failed'),
    );
  }

  /// Bagian database yang sudah terpakai, 0..1 (dipotong di 1).
  double get dbRatio =>
      dbLimitBytes <= 0 ? 0 : (dbBytes / dbLimitBytes).clamp(0.0, 1.0);

  /// Berapa bulan lagi sampai batas database tercapai.
  ///
  /// `null` berarti **tidak dapat diramalkan**, dan itu bukan kabar baik
  /// maupun buruk — ia hanya berarti belum ada pertumbuhan yang dapat diukur.
  /// Menampilkan "0 bulan" untuk keadaan itu akan membunyikan alarm palsu;
  /// menampilkan "999 bulan" akan menidurkan orang.
  ///
  /// ⚠️ Pertumbuhan nol ATAU negatif sama-sama menghasilkan `null`. Database
  /// yang menyusut memang tidak akan pernah mencapai batasnya, tetapi menulis
  /// "tidak akan pernah" dari satu bulan data yang kebetulan sepi adalah
  /// janji yang tidak dapat ditepati.
  double? get bulanSampaiPenuh {
    if (bytes30d <= 0) return null;
    final sisa = dbLimitBytes - dbBytes;
    if (sisa <= 0) return 0;
    return sisa / bytes30d;
  }

  /// Ambang database, ditetapkan Product Owner:
  /// di bawah 5 GB aman · 5–6,5 GB siapkan · di atas 6,5 GB naikkan disk.
  CapacityLevel get levelDatabase {
    const gb = 1024 * 1024 * 1024;
    if (dbBytes > 6.5 * gb) return CapacityLevel.bertindak;
    if (dbBytes >= 5 * gb) return CapacityLevel.siapkan;
    return CapacityLevel.aman;
  }

  /// Ambang jumlah baris:
  /// di bawah 10 juta aman · 10–30 juta siapkan · di atas 30 juta partisi.
  ///
  /// Angkanya bukan tentang ruang melainkan tentang kecepatan: tabel yang
  /// melewati puluhan juta baris membuat indeksnya tidak lagi muat di memori,
  /// dan pencarian resi mulai terasa lambat jauh sebelum ruangnya habis.
  CapacityLevel get levelBaris {
    if (videoRows > 30000000) return CapacityLevel.bertindak;
    if (videoRows >= 10000000) return CapacityLevel.siapkan;
    return CapacityLevel.aman;
  }

  /// Antrean penghapusan R2 yang menumpuk berarti `purge-storage` tidak pernah
  /// berjalan — dan itu tepat keadaan yang membuat tagihan R2 tumbuh diam-diam.
  ///
  /// 🔴 Satu kegagalan sudah cukup untuk menaikkannya ke [CapacityLevel.siapkan].
  /// Kunci yang gagal dihapus tidak akan pernah berhasil dengan sendirinya:
  /// sebabnya kredensial, bucket, atau kunci yang cacat — ketiganya menuntut
  /// orang, bukan waktu.
  CapacityLevel get levelAntrean {
    if (purgeFailed > 0) return CapacityLevel.siapkan;
    if (purgeQueue > 50000) return CapacityLevel.siapkan;
    return CapacityLevel.aman;
  }

  /// Keadaan terburuk di antara ketiganya — inilah yang mewarnai kartunya.
  ///
  /// Sengaja terburuk, bukan rata-rata: kartu berwarna hijau karena dua dari
  /// tiga angkanya sehat adalah kartu yang menyembunyikan satu-satunya angka
  /// yang perlu dibaca.
  CapacityLevel get level {
    final semua = [levelDatabase, levelBaris, levelAntrean];
    if (semua.contains(CapacityLevel.bertindak)) return CapacityLevel.bertindak;
    if (semua.contains(CapacityLevel.siapkan)) return CapacityLevel.siapkan;

    // Ramalan yang pendek mengangkat levelnya walaupun angka hari ini masih
    // sehat. Enam bulan adalah tenggang yang cukup untuk memindahkan database
    // tanpa tergesa; di bawah itu, keputusannya sudah harus dibuat.
    final bulan = bulanSampaiPenuh;
    if (bulan != null && bulan < 3) return CapacityLevel.bertindak;
    if (bulan != null && bulan < 6) return CapacityLevel.siapkan;

    return CapacityLevel.aman;
  }
}
