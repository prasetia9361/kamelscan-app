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
