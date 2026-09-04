import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'token_wallet.freezed.dart';
part 'token_wallet.g.dart';

/// Dompet kuota — tabel `public.token_wallets` (Bab 5.2 / Bab 7.2).
///
/// ⚠️ **Semua perubahan saldo terjadi di server** (trigger/Edge Function).
/// Model ini hanya membaca. Jangan pernah menghitung pemotongan token di
/// Flutter (Bab 5.1 poin 4).
@freezed
abstract class TokenWallet with _$TokenWallet {
  const factory TokenWallet({
    required String tenantId,
    @Default(0) int balance,
    @Default(100) int monthlyQuota,
    DateTime? periodStart,

    /// NULL selama uji coba — saldo tidak pernah di-reset (Bab 7.5).
    DateTime? periodEnd,
    DateTime? updatedAt,
  }) = _TokenWallet;

  const TokenWallet._();

  factory TokenWallet.fromJson(Map<String, dynamic> json) =>
      _$TokenWalletFromJson(json);

  bool get isTrialWallet => periodEnd == null;

  bool get isExhausted => balance <= 0;

  /// Rasio sisa saldo terhadap kuota, 0..1. Dipakai indikator warna Bab 7.3.
  double get remainingRatio {
    if (monthlyQuota <= 0) return 0;
    return (balance / monthlyQuota).clamp(0.0, 1.0);
  }

  bool get isLow => remainingRatio <= 0.20 && !isExhausted;
  bool get isCritical => remainingRatio <= 0.05 && !isExhausted;

  int get used => (monthlyQuota - balance).clamp(0, monthlyQuota);
}

/// Satu baris riwayat perubahan saldo — `public.token_ledger`.
///
/// Bab 7.2 poin 5: setiap perubahan saldo **wajib** menghasilkan satu baris.
/// Tanpa ledger, sengketa dengan pelanggan tidak bisa diselesaikan.
@freezed
abstract class TokenLedgerEntry with _$TokenLedgerEntry {
  const factory TokenLedgerEntry({
    required int id,
    required String tenantId,
    required int delta,

    // 🔴 Lewat `fromWire`, BUKAN pemetaan bawaan generator. `$enumDecode`
    // melempar untuk nilai di luar daftar, dan daftar itu selalu tertinggal
    // satu langkah di belakang database: migrasi 39 menambahkan
    // `token_expired` tanpa satu pun galat sampai baris pertamanya lahir.
    @JsonKey(fromJson: LedgerReason.fromWire)
    required LedgerReason reason,
    required int balanceAfter,
    String? videoId,
    String? note,
    DateTime? createdAt,
  }) = _TokenLedgerEntry;

  const TokenLedgerEntry._();

  factory TokenLedgerEntry.fromJson(Map<String, dynamic> json) =>
      _$TokenLedgerEntryFromJson(json);

  bool get isDebit => delta < 0;
}
