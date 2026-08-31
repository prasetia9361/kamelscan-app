/// Enum aplikasi — cerminan satu-per-satu dari `01_enums.sql` (Bab 5.2).
///
/// Nilai `wire` HARUS sama persis dengan label enum PostgreSQL. Jangan pernah
/// mengandalkan `name` Dart secara langsung untuk dikirim ke database.
library;

import 'package:json_annotation/json_annotation.dart';

enum UserRole {
  @JsonValue('admin')
  admin,
  @JsonValue('owner')
  owner,
  @JsonValue('packer')
  packer;

  String get wire => name;

  static UserRole fromWire(String? v) => switch (v) {
        'admin' => UserRole.admin,
        'owner' => UserRole.owner,
        _ => UserRole.packer,
      };

  bool get isAdmin => this == UserRole.admin;
  bool get isOwner => this == UserRole.owner;
  bool get isPacker => this == UserRole.packer;
}

enum TierPlan {
  @JsonValue('standar')
  standar,
  @JsonValue('pro')
  pro,

  /// Ditambahkan 31 Agustus 2026 (Bab 7.1).
  @JsonValue('bisnis')
  bisnis;

  String get wire => name;

  /// 🔴 Urutannya BUKAN urutan deklarasi belaka — ia dipakai membandingkan
  /// tinggi paket, misalnya untuk mengetahui apakah sebuah pembelian
  /// **menurunkan** tier dan karena itu wajib memunculkan peringatan durasi
  /// (Bab 12.4). Menyisipkan paket baru di tengah akan mengubah arti setiap
  /// perbandingan itu sekaligus, tanpa satu pun galat.
  int get tingkat => index;

  bool lebihRendahDari(TierPlan lain) => tingkat < lain.tingkat;

  /// ⚠️ Nilai yang tidak dikenal jatuh ke [standar], BUKAN ke paket tertinggi.
  /// Aplikasi lama yang membaca tenant berpaket `bisnis` akan memperlakukannya
  /// sebagai Standar — membatasi, bukan memberi lebih.
  static TierPlan fromWire(String? v) => switch (v) {
    'pro' => TierPlan.pro,
    'bisnis' => TierPlan.bisnis,
    _ => TierPlan.standar,
  };
}

enum VideoType {
  @JsonValue('packing')
  packing,
  @JsonValue('return')
  returned;

  /// `return` adalah kata kunci Dart, karena itu nama Dart-nya `returned`
  /// sementara nilai di database tetap `return`.
  String get wire => this == VideoType.returned ? 'return' : 'packing';

  static VideoType fromWire(String? v) =>
      v == 'return' ? VideoType.returned : VideoType.packing;
}

enum VideoStatus {
  @JsonValue('pending_upload')
  pendingUpload,
  @JsonValue('uploading')
  uploading,
  @JsonValue('uploaded')
  uploaded,
  @JsonValue('failed')
  failed,
  @JsonValue('expired')
  expired,
  @JsonValue('deleted')
  deleted;

  String get wire => switch (this) {
        VideoStatus.pendingUpload => 'pending_upload',
        VideoStatus.uploading => 'uploading',
        VideoStatus.uploaded => 'uploaded',
        VideoStatus.failed => 'failed',
        VideoStatus.expired => 'expired',
        VideoStatus.deleted => 'deleted',
      };

  static VideoStatus fromWire(String? v) => switch (v) {
        'uploading' => VideoStatus.uploading,
        'uploaded' => VideoStatus.uploaded,
        'failed' => VideoStatus.failed,
        'expired' => VideoStatus.expired,
        'deleted' => VideoStatus.deleted,
        _ => VideoStatus.pendingUpload,
      };

  bool get isPlayable => this == VideoStatus.uploaded;
}

enum TenantStatus {
  @JsonValue('trial')
  trial,
  @JsonValue('active')
  active,
  @JsonValue('suspended')
  suspended,
  @JsonValue('expired')
  expired;

  String get wire => name;

  static TenantStatus fromWire(String? v) => switch (v) {
        'active' => TenantStatus.active,
        'suspended' => TenantStatus.suspended,
        'expired' => TenantStatus.expired,
        _ => TenantStatus.trial,
      };

  /// Bab 7.6 — hanya `trial` dan `active` yang boleh merekam.
  bool get canRecord => this == TenantStatus.trial || this == TenantStatus.active;
}

enum SubStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('paid')
  paid,
  @JsonValue('failed')
  failed,
  @JsonValue('expired')
  expired,
  @JsonValue('cancelled')
  cancelled;

  String get wire => name;

  static SubStatus fromWire(String? v) => switch (v) {
        'paid' => SubStatus.paid,
        'failed' => SubStatus.failed,
        'expired' => SubStatus.expired,
        'cancelled' => SubStatus.cancelled,
        _ => SubStatus.pending,
      };
}

enum LedgerReason {
  @JsonValue('video_upload')
  videoUpload,
  @JsonValue('monthly_reset')
  monthlyReset,
  @JsonValue('plan_upgrade')
  planUpgrade,
  @JsonValue('admin_adjust')
  adminAdjust,
  @JsonValue('refund')
  refund,

  /// Ditambahkan 1 September 2026 bersama migrasi 39. Ditulis
  /// `expire_tenant_tokens()` (migrasi 40) saat langganan berakhir dan
  /// saldonya dihanguskan.
  @JsonValue('token_expired')
  tokenExpired,

  /// 🔴 TIDAK ADA di database, dan memang tidak boleh ada. Ia hanya nilai
  /// jatuhan bagi baris yang alasannya belum dikenal versi aplikasi ini.
  ///
  /// Sebelum ini `LedgerReason` satu-satunya enum di berkas ini yang tidak
  /// punya jatuhan, sehingga satu nilai baru di database membuat seluruh
  /// pembacaan buku besar **melempar**. Itu terjadi diam-diam pada 1
  /// September 2026: migrasi 39 menambahkan `token_expired`, dan tidak ada
  /// satu pun galat sampai baris pertamanya lahir.
  ///
  /// ⚠️ Jatuhannya sengaja BUKAN salah satu alasan yang sudah ada. Buku besar
  /// token adalah satu-satunya alat menyelesaikan sengketa dengan pelanggan
  /// (Bab 7.2 poin 5); melabeli baris sistem sebagai `admin_adjust` berarti
  /// memalsukan bukti di dokumen yang gunanya justru membuktikan.
  ///
  /// Aman karena aplikasi tidak punya izin tulis ke `token_ledger` sama
  /// sekali (migrasi 14) — nilai ini tidak akan pernah tersimpan.
  unknown;

  String get wire => switch (this) {
        LedgerReason.videoUpload => 'video_upload',
        LedgerReason.monthlyReset => 'monthly_reset',
        LedgerReason.planUpgrade => 'plan_upgrade',
        LedgerReason.adminAdjust => 'admin_adjust',
        LedgerReason.refund => 'refund',
        LedgerReason.tokenExpired => 'token_expired',
        LedgerReason.unknown => 'unknown',
      };

  /// ⚠️ Nilai yang tidak dikenal jatuh ke [unknown], bukan melempar. Lihat
  /// keterangan di [unknown] untuk alasan keduanya.
  static LedgerReason fromWire(String? v) => switch (v) {
        'video_upload' => LedgerReason.videoUpload,
        'monthly_reset' => LedgerReason.monthlyReset,
        'plan_upgrade' => LedgerReason.planUpgrade,
        'admin_adjust' => LedgerReason.adminAdjust,
        'refund' => LedgerReason.refund,
        'token_expired' => LedgerReason.tokenExpired,
        _ => LedgerReason.unknown,
      };
}

/// Tiga mode pemicu perekaman (Bab 0.3 / Bab 8.3).
enum TriggerMode {
  qrCode,
  barcode1d,
  manual;

  String get wire => switch (this) {
        TriggerMode.qrCode => 'qr_code',
        TriggerMode.barcode1d => 'barcode_1d',
        TriggerMode.manual => 'manual',
      };

  static TriggerMode fromWire(String? v) => switch (v) {
        'barcode_1d' => TriggerMode.barcode1d,
        'manual' => TriggerMode.manual,
        _ => TriggerMode.qrCode,
      };
}

/// Posisi watermark (`tenant_settings.watermark_position`).
enum WatermarkPosition {
  @JsonValue('top_left')
  topLeft,
  @JsonValue('top_right')
  topRight,
  @JsonValue('bottom_left')
  bottomLeft,
  @JsonValue('bottom_right')
  bottomRight;

  String get wire => switch (this) {
        WatermarkPosition.topLeft => 'top_left',
        WatermarkPosition.topRight => 'top_right',
        WatermarkPosition.bottomLeft => 'bottom_left',
        WatermarkPosition.bottomRight => 'bottom_right',
      };

  static WatermarkPosition fromWire(String? v) => switch (v) {
        'top_left' => WatermarkPosition.topLeft,
        'top_right' => WatermarkPosition.topRight,
        'bottom_left' => WatermarkPosition.bottomLeft,
        _ => WatermarkPosition.bottomRight,
      };
}

/// Status antrian upload lokal (SQLite). `duplicate` menandai resi yang
/// ditolak server dengan error 23505 — jangan diulang terus (Bab 7.7).
enum UploadTaskStatus {
  /// Rekaman **mentah**, watermark-nya belum ditempelkan (Bab 8.5).
  ///
  /// 🔴 Baris pada status ini belum boleh diunggah: yang disimpan ke cloud
  /// wajib berkas hasil proses. Berkas mentah 14 kali lebih besar dan tidak
  /// membawa satu pun keterangan bukti — resi, waktu, toko, koordinat.
  ///
  /// Statusnya disimpan di database, bukan hanya di memori, supaya rekaman
  /// yang belum sempat diolah saat aplikasi tertutup tidak menjadi berkas
  /// yatim yang memenuhi penyimpanan tanpa ada yang tahu.
  pendingProcess,
  queued,
  running,
  paused,
  failed,
  duplicate,
  done;

  static UploadTaskStatus fromWire(String? v) => switch (v) {
        'pending_process' => UploadTaskStatus.pendingProcess,
        'running' => UploadTaskStatus.running,
        'paused' => UploadTaskStatus.paused,
        'failed' => UploadTaskStatus.failed,
        'duplicate' => UploadTaskStatus.duplicate,
        'done' => UploadTaskStatus.done,
        _ => UploadTaskStatus.queued,
      };

  String get wire => switch (this) {
        UploadTaskStatus.pendingProcess => 'pending_process',
        _ => name,
      };
}
