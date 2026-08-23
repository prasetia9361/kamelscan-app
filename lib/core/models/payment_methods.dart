import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_methods.freezed.dart';
part 'payment_methods.g.dart';

/// Satu rekening tujuan transfer, dari
/// `platform_settings.payment_methods.bank_accounts`.
@freezed
abstract class BankAccount with _$BankAccount {
  const factory BankAccount({
    required String bank,
    required String number,
    required String holder,
  }) = _BankAccount;

  const BankAccount._();

  factory BankAccount.fromJson(Map<String, dynamic> json) =>
      _$BankAccountFromJson(json);
}

/// Metode pembayaran yang sedang aktif (Bab 12.1).
///
/// 🔴 Dibaca dari `platform_settings`, **tidak pernah ditulis mati di kode.**
/// Seluruh gunanya adalah agar Midtrans dapat dinyalakan begitu verifikasi
/// merchant selesai **tanpa merilis aplikasi baru** — verifikasi itu memakan
/// 5–14 hari kerja dan sepenuhnya di luar kendali tim.
///
/// ⚠️ Kunci rahasia Midtrans tidak pernah ada di sini. Tabel ini hanya berisi
/// sakelar aktif/nonaktif; kuncinya hidup di Edge Function secrets (Bab 4.4).
@freezed
abstract class PaymentMethods with _$PaymentMethods {
  const factory PaymentMethods({
    @Default(false) bool midtransEnabled,
    @Default(true) bool manualTransferEnabled,
    @Default(<BankAccount>[]) List<BankAccount> bankAccounts,
  }) = _PaymentMethods;

  const PaymentMethods._();

  factory PaymentMethods.fromJson(Map<String, dynamic> json) =>
      _$PaymentMethodsFromJson(json);

  /// Cadangan saat `platform_settings` belum pernah terbaca.
  ///
  /// Sengaja transfer manual, bukan Midtrans: itu keadaan yang benar pada Fase
  /// 1, dan menebak ke arah yang salah berarti menawarkan pembayaran yang
  /// belum tentu hidup.
  static const PaymentMethods fallback = PaymentMethods();

  /// Transfer manual dapat ditawarkan hanya bila ada rekening tujuannya.
  ///
  /// Sakelar menyala tetapi daftar rekening kosong adalah keadaan yang
  /// benar-benar mungkin — begitulah isi awal `platform_settings`. Layar
  /// checkout yang mempercayai sakelarnya saja akan menampilkan instruksi
  /// transfer tanpa satu pun nomor rekening.
  bool get canTransferManually =>
      manualTransferEnabled && bankAccounts.isNotEmpty;

  /// Tidak ada satu pun jalur pembayaran yang dapat dipakai sekarang.
  bool get hasNoMethod => !canTransferManually && !midtransEnabled;
}
