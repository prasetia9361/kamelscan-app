import 'package:equatable/equatable.dart';

/// Taksonomi error aplikasi (Bab 3.2).
///
/// Semua error yang keluar dari Repository harus berbentuk [AppFailure],
/// bukan exception mentah. Layar error menampilkan [messageKey] setelah
/// diterjemahkan lewat l10n, bukan [debugMessage].
enum FailureKind {
  /// Tidak ada koneksi / timeout.
  network,

  /// Gagal login, sesi kedaluwarsa, kredensial salah.
  auth,

  /// Ditolak RLS atau role tidak berwenang.
  permission,

  /// Data tidak ditemukan.
  notFound,

  /// Melanggar unique constraint (mis. resi ganda, 23505).
  conflict,

  /// Input tidak valid (validasi sisi klien maupun server).
  validation,

  /// Kuota token habis / batas tier tercapai.
  quota,

  /// Langganan tidak aktif (trial habis atau `expired`).
  subscriptionInactive,

  /// Izin perangkat ditolak (kamera, mikrofon, lokasi, penyimpanan).
  devicePermission,

  /// Kegagalan penyimpanan / storage R2.
  storage,

  /// Segala hal yang tidak masuk kategori di atas.
  unknown,
}

class AppFailure extends Equatable implements Exception {
  const AppFailure({
    required this.kind,
    required this.messageKey,
    this.debugMessage,
    this.code,
    this.cause,
    this.stackTrace,
  });

  final FailureKind kind;

  /// Kunci terjemahan, contoh: `error_network`. Dipetakan di l10n.
  final String messageKey;

  /// Pesan teknis untuk log & Sentry. **Jangan tampilkan ke pengguna.**
  final String? debugMessage;

  /// Kode asli dari sumber (mis. SQLSTATE `23505`, HTTP `403`).
  final String? code;

  final Object? cause;
  final StackTrace? stackTrace;

  bool get isRetryable =>
      kind == FailureKind.network || kind == FailureKind.unknown;

  /// Error yang tidak perlu dikirim ke Sentry — bising dan sudah diketahui.
  bool get shouldReport => switch (kind) {
        FailureKind.network ||
        FailureKind.auth ||
        FailureKind.validation ||
        FailureKind.quota ||
        FailureKind.subscriptionInactive ||
        FailureKind.devicePermission ||
        FailureKind.conflict =>
          false,
        _ => true,
      };

  AppFailure copyWith({String? debugMessage, String? code}) => AppFailure(
        kind: kind,
        messageKey: messageKey,
        debugMessage: debugMessage ?? this.debugMessage,
        code: code ?? this.code,
        cause: cause,
        stackTrace: stackTrace,
      );

  // ---------- Konstruktor siap pakai ----------

  static const AppFailure network = AppFailure(
    kind: FailureKind.network,
    messageKey: 'errorNetwork',
  );

  static const AppFailure sessionExpired = AppFailure(
    kind: FailureKind.auth,
    messageKey: 'errorSessionExpired',
  );

  static const AppFailure permissionDenied = AppFailure(
    kind: FailureKind.permission,
    messageKey: 'errorPermissionDenied',
  );

  static const AppFailure notFound = AppFailure(
    kind: FailureKind.notFound,
    messageKey: 'errorNotFound',
  );

  static const AppFailure resiDuplicate = AppFailure(
    kind: FailureKind.conflict,
    messageKey: 'errorResiDuplicate',
    code: '23505',
  );

  static const AppFailure tokenExhausted = AppFailure(
    kind: FailureKind.quota,
    messageKey: 'errorTokenExhausted',
  );

  static const AppFailure subscriptionInactive = AppFailure(
    kind: FailureKind.subscriptionInactive,
    messageKey: 'errorSubscriptionInactive',
  );

  static const AppFailure packerLimitReached = AppFailure(
    kind: FailureKind.quota,
    messageKey: 'errorPackerLimitReached',
  );

  factory AppFailure.unknown(Object error, [StackTrace? stack]) => AppFailure(
        kind: FailureKind.unknown,
        messageKey: 'errorUnknown',
        debugMessage: error.toString(),
        cause: error,
        stackTrace: stack,
      );

  factory AppFailure.validation(String messageKey, {String? debugMessage}) =>
      AppFailure(
        kind: FailureKind.validation,
        messageKey: messageKey,
        debugMessage: debugMessage,
      );

  factory AppFailure.devicePermission(String messageKey) => AppFailure(
        kind: FailureKind.devicePermission,
        messageKey: messageKey,
      );

  factory AppFailure.storage(Object error, [StackTrace? stack]) => AppFailure(
        kind: FailureKind.storage,
        messageKey: 'errorStorage',
        debugMessage: error.toString(),
        cause: error,
        stackTrace: stack,
      );

  @override
  List<Object?> get props => [kind, messageKey, code];

  @override
  String toString() =>
      'AppFailure(${kind.name}, $messageKey${code == null ? '' : ', code=$code'}'
      '${debugMessage == null ? '' : ', $debugMessage'})';
}
