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
  pro;

  String get wire => name;

  static TierPlan fromWire(String? v) =>
      v == 'pro' ? TierPlan.pro : TierPlan.standar;
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
  refund;

  String get wire => switch (this) {
        LedgerReason.videoUpload => 'video_upload',
        LedgerReason.monthlyReset => 'monthly_reset',
        LedgerReason.planUpgrade => 'plan_upgrade',
        LedgerReason.adminAdjust => 'admin_adjust',
        LedgerReason.refund => 'refund',
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
  queued,
  running,
  paused,
  failed,
  duplicate,
  done;

  static UploadTaskStatus fromWire(String? v) => switch (v) {
        'running' => UploadTaskStatus.running,
        'paused' => UploadTaskStatus.paused,
        'failed' => UploadTaskStatus.failed,
        'duplicate' => UploadTaskStatus.duplicate,
        'done' => UploadTaskStatus.done,
        _ => UploadTaskStatus.queued,
      };

  String get wire => name;
}
