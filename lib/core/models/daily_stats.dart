import 'package:freezed_annotation/freezed_annotation.dart';

part 'daily_stats.freezed.dart';
part 'daily_stats.g.dart';

/// Isi dasbor web — hasil RPC `get_daily_stats()` (Bab 10.4, migrasi 27).
///
/// 🔴 Angka di sini **tidak akan sama** dengan kartu monitoring Beranda, dan
/// itu disengaja. [HomeStats] menghitung sejak `token_wallets.period_start`
/// karena ia menjawab *"jatah saya tinggal berapa"*; dasbor menghitung menurut
/// hari kalender karena ia alat analisis. Keputusan Product Owner 18 Agustus
/// 2026; alasan lengkapnya di `supabase/migrations/20_home_stats.sql`.
/// Jangan "memperbaiki" salah satunya agar cocok dengan yang lain.
///
/// ⚠️ Cakupannya ditentukan RLS (`security invoker`), bukan oleh kode ini.
/// Packer hanya menghitung rekaman yang boleh ia lihat.
@freezed
abstract class DailyStats with _$DailyStats {
  const factory DailyStats({
    /// Panjang rentang yang benar-benar dihitung server (7/30/90).
    ///
    /// Dikirim balik, bukan diasumsikan sama dengan yang diminta: server
    /// menjepit nilai di luar 7..90. Layar menulis keterangannya dari sini
    /// supaya tidak pernah menyebut rentang yang berbeda dari yang dihitung.
    required int days,

    /// Hari pertama dan terakhir rentang, menurut waktu Jakarta.
    ///
    /// Ikut dikirim agar layar dapat menulis keterangan yang dapat dicocokkan
    /// ("1 – 30 Agustus") alih-alih "30 hari terakhir" yang tidak dapat
    /// diperiksa siapa pun. Alasan yang sama seperti `periodStart` pada
    /// [HomeStats].
    required DateTime startDate,
    required DateTime endDate,

    /// Satu titik per hari, **termasuk hari tanpa rekaman**.
    ///
    /// 🔴 Hari kosong sengaja ikut sebagai nol, bukan dihilangkan. Grafik yang
    /// melompati hari libur menyambungkan 20 Agustus langsung ke 24 Agustus,
    /// dan libur jadi tampak seperti hari kerja biasa.
    @Default(<DailyPoint>[]) List<DailyPoint> series,

    /// Jumlah pada rentang yang dipilih.
    @Default(StatTotal()) StatTotal total,

    /// Jumlah pada rentang sepanjang sama, persis sebelumnya.
    @Default(StatTotal()) StatTotal previous,

    /// Pemakaian token per hari — grafik kedua (Bab 10.4).
    @Default(<TokenPoint>[]) List<TokenPoint> tokenSeries,

    /// Antrean unggah **di server**.
    @Default(PendingUploads()) PendingUploads pending,

    /// null bila dompetnya belum terbentuk — bukan nol.
    WalletInfo? wallet,
  }) = _DailyStats;

  const DailyStats._();

  factory DailyStats.fromJson(Map<String, dynamic> json) =>
      _$DailyStatsFromJson(json);

  int get totalVideos => total.total;

  /// Belum ada satu pun rekaman pada rentang ini — kondisi "kosong" Bab 3.4.
  ///
  /// ⚠️ Sengaja **tidak** memeriksa [series] kosong. Deret selalu berisi
  /// sepanjang rentang (server mengisi hari kosong dengan nol), jadi
  /// `series.isEmpty` hanya benar bila terjadi kesalahan — dan itu bukan
  /// keadaan "kosong", melainkan keadaan "rusak".
  bool get isEmpty => totalVideos == 0;

  /// Rata-rata video per hari pada rentang ini.
  ///
  /// Pembaginya [days], bukan jumlah hari yang ada rekamannya. Rata-rata yang
  /// mengabaikan hari kosong selalu terlihat bagus dan tidak dapat dipakai
  /// membandingkan dua periode.
  double get averagePerDay => days == 0 ? 0 : totalVideos / days;

  /// Nilai tertinggi yang benar-benar **digambar** — dipakai menentukan batas
  /// atas sumbu tegak.
  ///
  /// 🔴 Bukan `packing + return`. Grafiknya dua garis terpisah, bukan tumpukan:
  /// memakai jumlah keduanya membuat batas atas sumbu hampir dua kali lebih
  /// tinggi daripada garis tertingginya, dan seluruh grafik memipih ke dasar
  /// tanpa satu pun galat yang memberi tahu.
  int get peak => series.fold(0, (tertinggi, p) {
        final sehari = p.packing > p.returnCount ? p.packing : p.returnCount;
        return sehari > tertinggi ? sehari : tertinggi;
      });

  double? get packingChange => _change(total.packing, previous.packing);
  double? get returnChange => _change(total.returnCount, previous.returnCount);
  double? get totalChange => _change(total.total, previous.total);

  /// Perubahan terhadap periode sebelumnya sebagai pecahan (`0.25` = naik 25%).
  ///
  /// 🔴 Mengembalikan **null** bila periode sebelumnya nol, bukan 0 atau 1.
  /// Naik dari 0 ke 40 bukan "naik 100%" maupun "tidak berubah" — kenaikannya
  /// tidak terdefinisi, dan angka apa pun yang dipaksakan di sini akan
  /// dituliskan layar sebagai fakta. Layar yang memutuskan kalimatnya
  /// ("belum ada pembanding").
  static double? _change(int now, int before) =>
      before == 0 ? null : (now - before) / before;

  // ---------- Kartu Token Tersedia ----------

  /// Rata-rata token terpakai per hari pada rentang ini.
  double get averageTokensPerDay {
    if (tokenSeries.isEmpty) return 0;
    final jumlah = tokenSeries.fold<int>(0, (a, p) => a + p.used);
    return jumlah / tokenSeries.length;
  }

  /// Perkiraan berapa hari lagi saldonya cukup pada laju sekarang.
  ///
  /// 🔴 null bila lajunya nol atau dompetnya belum ada. Membaginya tetap akan
  /// menghasilkan tak-hingga, dan layar akan menuliskan *"cukup ∞ hari"* —
  /// kalimat yang secara teknis benar dan sama sekali tidak berguna. Yang
  /// tidak dapat diperkirakan lebih baik tidak diperkirakan.
  int? get estimatedDaysLeft {
    final saldo = wallet?.balance;
    final laju = averageTokensPerDay;
    if (saldo == null || laju <= 0) return null;
    return (saldo / laju).floor();
  }

  // ---------- Kartu Menunggu Unggah ----------

  /// Umur video tertua yang masih menunggu diunggah.
  Duration? get oldestPendingAge {
    final sejak = pending.oldestAt;
    if (sejak == null) return null;
    final umur = DateTime.now().difference(sejak);
    return umur.isNegative ? Duration.zero : umur;
  }

  /// Ambang "wajar" antrean unggah.
  ///
  /// Enam jam dipilih desainer sebagai batas antara "sedang jalan" dan
  /// "tersangkut": satu giliran kerja penuh. Video yang belum terkirim
  /// sesudah sepanjang itu hampir pasti bukan soal jaringan yang lambat.
  static const Duration pendingWarnAfter = Duration(hours: 6);

  bool get pendingIsStale {
    final umur = oldestPendingAge;
    return umur != null && umur >= pendingWarnAfter;
  }
}

/// Satu hari pada grafik pemakaian token.
@freezed
abstract class TokenPoint with _$TokenPoint {
  const factory TokenPoint({
    required DateTime date,

    /// Token terpakai hari itu. Sudah dibalik tandanya di server — buku besar
    /// mencatat pemakaian sebagai angka negatif.
    @Default(0) int used,
  }) = _TokenPoint;

  const TokenPoint._();

  factory TokenPoint.fromJson(Map<String, dynamic> json) =>
      _$TokenPointFromJson(json);
}

/// Antrean unggah di server (Bab 10.4).
///
/// ⚠️ **Bukan** antrean di perangkat. `DEVIASI_LIBRARY.md` L.5: baris
/// `package_videos` baru dibuat saat mengunggah, jadi video yang direkam di
/// gudang tanpa sinyal belum terhitung di sini sama sekali. Di web antrean
/// perangkat memang tidak dapat dilihat — perangkatnya bukan yang sedang
/// dipakai — jadi angka ini yang terbaik yang tersedia, bukan angka yang
/// salah.
@freezed
abstract class PendingUploads with _$PendingUploads {
  const factory PendingUploads({
    @Default(0) int count,

    /// Waktu rekam video tertua yang masih tersangkut. null bila antreannya
    /// kosong.
    DateTime? oldestAt,
  }) = _PendingUploads;

  const PendingUploads._();

  factory PendingUploads.fromJson(Map<String, dynamic> json) =>
      _$PendingUploadsFromJson(json);

  bool get isEmpty => count == 0;
}

/// Saldo dan kuota dompet token.
@freezed
abstract class WalletInfo with _$WalletInfo {
  const factory WalletInfo({
    @Default(0) int balance,
    @Default(0) int quota,
  }) = _WalletInfo;

  const WalletInfo._();

  factory WalletInfo.fromJson(Map<String, dynamic> json) =>
      _$WalletInfoFromJson(json);

  /// Sisa kuota 0..1. Dipakai bilah kemajuan dan ambang warna Bab 7.3.
  double get ratio => quota <= 0 ? 0 : (balance / quota).clamp(0.0, 1.0);
}

/// Satu hari pada grafik.
@freezed
abstract class DailyPoint with _$DailyPoint {
  const factory DailyPoint({
    required DateTime date,
    @Default(0) int packing,

    /// 🔴 `@JsonKey` wajib di sini karena dua alasan sekaligus: `return` adalah
    /// kata kunci Dart sehingga field tidak boleh bernama itu, dan
    /// `field_rename: snake` di `build.yaml` akan memetakan `returnCount`
    /// menjadi `return_count` — kunci yang tidak dikirim server.
    ///
    /// Kuncinya sengaja dipendekkan di sisi SQL: deret ini berisi sampai 90
    /// baris, dan nama panjang terkirim 90 kali.
    @JsonKey(name: 'return') @Default(0) int returnCount,
  }) = _DailyPoint;

  const DailyPoint._();

  factory DailyPoint.fromJson(Map<String, dynamic> json) =>
      _$DailyPointFromJson(json);

  int get total => packing + returnCount;
}

/// Jumlah packing dan return pada satu rentang.
@freezed
abstract class StatTotal with _$StatTotal {
  const factory StatTotal({
    @Default(0) int packing,
    @JsonKey(name: 'return') @Default(0) int returnCount,
  }) = _StatTotal;

  const StatTotal._();

  factory StatTotal.fromJson(Map<String, dynamic> json) =>
      _$StatTotalFromJson(json);

  int get total => packing + returnCount;
}
