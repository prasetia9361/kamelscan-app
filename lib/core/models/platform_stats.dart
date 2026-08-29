import 'package:freezed_annotation/freezed_annotation.dart';

part 'platform_stats.freezed.dart';
part 'platform_stats.g.dart';

/// Angka ringkasan seluruh platform — hasil RPC `get_platform_stats()`
/// (Bab 11.1, migrasi 30).
///
/// 🔴 Satu-satunya data di aplikasi ini yang **melintasi batas antar
/// pelanggan**. Seluruh model lain otomatis terbatas pada tenant pemakainya
/// karena RLS; yang ini tidak, dan penjagaannya berada di dalam fungsi server
/// (`is_admin()` pada baris pertamanya).
///
/// ⚠️ Jangan pernah menampilkan angka ini di layar mana pun selain panel
/// Admin.
@freezed
abstract class PlatformStats with _$PlatformStats {
  const factory PlatformStats({
    /// Tenant berbayar yang sedang aktif, per tier.
    @Default(0) int standarActive,
    @Default(0) int proActive,

    /// Di luar daftar Bab 11.1, ditambahkan dengan sengaja: tanpa keduanya
    /// dasbor menulis "1 pelanggan" sementara ada belasan tenant uji coba
    /// yang sedang memakai server.
    @Default(0) int trialCount,
    @Default(0) int suspendedCount,

    @Default(0) int newThisMonth,

    /// Pendapatan berulang bulanan, dihitung dari **harga tier yang sedang
    /// aktif** — bukan dari pembayaran yang masuk.
    ///
    /// Keduanya berbeda dan keduanya benar untuk pertanyaan berbeda. Yang ini
    /// menjawab *"berapa yang seharusnya masuk bulan depan bila tidak ada yang
    /// berhenti"*; menjumlahkan pembayaran menjawab *"berapa yang sudah
    /// masuk"*, yang berayun mengikuti tanggal orang membayar.
    @Default(0) num mrr,

    /// Biaya infrastruktur bulanan, diisi Admin dengan tangan lewat
    /// `platform_settings.infra_cost`. **null bila belum pernah diisi.**
    num? infraCost,

    /// 🔴 null bila [infraCost] belum diisi — **bukan** sama dengan [mrr].
    ///
    /// MRR dikurangi nol menghasilkan angka yang persis sama dengan MRR, dan
    /// di layar ia terbaca sebagai *"seluruh pendapatan adalah keuntungan"*.
    /// Itu kalimat yang paling tidak boleh dikarang oleh dasbor keuangan.
    num? margin,

    /// Seluruh baris `package_videos`, **termasuk yang sudah dihapus dan
    /// kedaluwarsa** (mengikuti Bab 11.1 apa adanya).
    ///
    /// ⚠️ Karena itu ia **tidak akan pernah cocok** dengan [storageBytes],
    /// yang hanya menghitung yang masih tersimpan. Keduanya menjawab
    /// pertanyaan berbeda: "berapa yang pernah direkam" dan "berapa yang masih
    /// ada". Layar wajib mengatakannya — selisih yang tidak dijelaskan
    /// terbaca sebagai kerusakan (pelajaran dari dua grafik dasbor web, O.16).
    @Default(0) int totalVideos,

    /// Jumlah byte video berstatus `uploaded`.
    @Default(0) int storageBytes,
  }) = _PlatformStats;

  const PlatformStats._();

  factory PlatformStats.fromJson(Map<String, dynamic> json) =>
      _$PlatformStatsFromJson(json);

  /// Seluruh tenant berbayar yang aktif.
  int get paidActive => standarActive + proActive;

  /// Seluruh tenant, apa pun keadaannya.
  int get totalTenants =>
      paidActive + trialCount + suspendedCount;

  /// Biaya infrastruktur belum pernah diisi Admin.
  bool get needsInfraCost => infraCost == null;
}
