import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'admin_tenant_row.freezed.dart';
part 'admin_tenant_row.g.dart';

/// Satu baris pada tabel Kelola Pengguna — hasil RPC `admin_list_tenants()`
/// (Bab 11.2, migrasi 31).
///
/// 🔴 Data yang **melintasi batas antar pelanggan**, sama seperti
/// [PlatformStats]. Seluruh model lain otomatis terbatas pada tenant
/// pemakainya karena RLS; yang ini tidak, dan penjagaannya berada di dalam
/// fungsi server (`is_admin()` pada baris pertamanya).
///
/// ⚠️ Jangan pernah menampilkannya di layar mana pun selain panel Admin.
///
/// Ini **bukan** pengganti [Tenant]. [Tenant] adalah cerminan satu baris tabel
/// `tenants` yang dipakai seluruh aplikasi; yang ini adalah baris tabel Admin
/// yang sudah membawa angka pemakaian dari empat tabel lain, dan hanya hidup
/// di satu layar.
@freezed
abstract class AdminTenantRow with _$AdminTenantRow {
  const factory AdminTenantRow({
    required String id,

    /// Nama usaha. **Boleh kosong** — kolomnya nullable di database, dan
    /// pendaftar yang belum mengisi profil memang belum punya nama usaha.
    String? businessName,

    /// Email pemilik. Diambil lewat subquery di dalam fungsi server, bukan
    /// embedding PostgREST — `users` punya dua hubungan ke `tenants`
    /// sekaligus dan PostgREST menolak yang rancu seperti itu.
    String? ownerEmail,

    /// Tenant ini milik akun **admin**, bukan pelanggan.
    ///
    /// 🔴 Setiap akun yang mendaftar memperoleh satu tenant sendiri, termasuk
    /// akun yang belakangan dinaikkan menjadi admin — peran disimpan di
    /// `users.role`, dan menaikkannya tidak menghapus tenant yang sudah
    /// terlanjur lahir. Barisnya karena itu nyata, bukan data sampah.
    ///
    /// Layar wajib menandainya dan mematikan tombol aksinya: tanpa itu,
    /// tombol Tangguhkan pada baris ini menangguhkan tenant admin sendiri.
    @Default(false) bool ownerIsAdmin,

    @Default(TierPlan.standar) TierPlan tierPlan,
    @Default(TenantStatus.trial) TenantStatus status,
    DateTime? createdAt,

    /// Akhir periode langganan. NULL selama masa uji coba — trial dibatasi
    /// jumlah video, bukan waktu (Bab 7.5).
    DateTime? periodEnd,

    @Default(0) int shopCount,
    @Default(0) int packerCount,

    /// Seluruh baris `package_videos` milik tenant ini, **termasuk yang sudah
    /// dihapus dan kedaluwarsa** — angka yang sama persis dengan "Total Video"
    /// di dasbor platform.
    ///
    /// ⚠️ Dua angka bernama sama yang menghitung hal berbeda di dua halaman
    /// bersebelahan adalah cara tercepat membuat keduanya tidak dipercaya.
    @Default(0) int videoCount,

    @Default(0) int tokenBalance,

    /// Akhir periode **dompet token**, bukan akhir periode langganan.
    ///
    /// 🔴 Keduanya berbeda dan menyamakannya menghasilkan tanggal yang salah:
    /// cron `reset-monthly-tokens` menyetel `token_wallets.period_end` ke
    /// 30 hari ke depan pada setiap reset, sementara [periodEnd] hanya
    /// bergerak saat pelanggan membayar atau saat Admin memperpanjang. Sesudah
    /// bulan pertama keduanya sudah tidak sama lagi.
    ///
    /// Inilah tanggal yang menentukan kapan token bonus hangus.
    DateTime? tokenPeriodEnd,
  }) = _AdminTenantRow;

  const AdminTenantRow._();

  factory AdminTenantRow.fromJson(Map<String, dynamic> json) =>
      _$AdminTenantRowFromJson(json);

  /// Nama yang dipakai di layar dan di setiap dialog konfirmasi.
  ///
  /// 🔴 Jatuh ke email, lalu ke potongan id — **tidak pernah** ke string
  /// kosong. Dialog "Tangguhkan  ?" tidak memberi tahu siapa pun apa yang
  /// sedang ditangguhkannya, dan aksi di halaman ini mengunci perekaman
  /// pelanggan seketika (Bab 7.6).
  String get label {
    final nama = businessName?.trim();
    if (nama != null && nama.isNotEmpty) return nama;
    final surel = ownerEmail?.trim();
    if (surel != null && surel.isNotEmpty) return surel;
    return id.length > 8 ? id.substring(0, 8) : id;
  }

  /// Sisa hari langganan. `null` saat trial (tidak ada batas waktu).
  int? daysUntilExpiry({DateTime? now}) {
    final akhir = periodEnd;
    if (akhir == null) return null;
    return akhir.difference(now ?? DateTime.now()).inDays;
  }

  /// Bab 7.6 — hanya `trial` dan `active` yang boleh merekam.
  bool get canRecord => status.canRecord;

  /// Kapan token tambahan yang diberikan Admin akan hangus.
  ///
  /// `null` berarti **tidak akan hangus dengan sendirinya**, dan itu terjadi
  /// pada dua keadaan yang berbeda:
  ///
  /// - Pelanggan uji coba. `token_wallets.period_end` NULL, sehingga cron
  ///   tidak pernah menyentuhnya (Bab 7.5).
  /// - Pelanggan yang ditangguhkan atau periodenya berakhir. Cron hanya
  ///   menyentuh yang berstatus `active`, jadi bonusnya menunggu sampai ia
  ///   diaktifkan lagi — lalu hangus pada reset pertama sesudah itu.
  ///
  /// Kedua keadaan itu perlu dikatakan berbeda di layar, jadi jangan
  /// menggabungkannya menjadi satu kalimat.
  DateTime? get tokenResetsAt =>
      status == TenantStatus.active ? tokenPeriodEnd : null;
}
