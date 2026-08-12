import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_constants.dart';
import '../models/token_wallet.dart';
import '../services/supabase_service.dart';
import '../utils/result.dart';

/// Akses dompet & buku besar token (Bab 7).
///
/// 🔴 **Read-only.** Semua perubahan saldo dilakukan server: trigger
/// `before_video_insert` memeriksa saldo, dan pemotongan terjadi saat status
/// video berubah menjadi `uploaded` (Bab 7.2). Menghitung saldo di Flutter
/// akan salah begitu dua packer merekam bersamaan (Bab 7.3).
class TokenRepository {
  const TokenRepository(this._client);

  final SupabaseClient _client;

  Future<Result<TokenWallet>> fetchWallet(String tenantId) async {
    try {
      final row = await _client
          .from(AppConstants.tblTokenWallets)
          .select()
          .eq('tenant_id', tenantId)
          .single();
      return Result.ok(TokenWallet.fromJson(row));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Saldo langsung dari server. Realtime dipakai agar indikator token di
  /// Beranda ikut berubah saat packer lain menyelesaikan unggahan.
  Stream<TokenWallet> watchWallet(String tenantId) => _client
      .from(AppConstants.tblTokenWallets)
      .stream(primaryKey: ['tenant_id'])
      .eq('tenant_id', tenantId)
      .map((rows) => TokenWallet.fromJson(rows.first));

  Future<Result<List<TokenLedgerEntry>>> fetchLedger(
    String tenantId, {
    int limit = 50,
  }) async {
    try {
      final rows = await _client
          .from(AppConstants.tblTokenLedger)
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false)
          .limit(limit);
      return Result.ok(
        rows.map((r) => TokenLedgerEntry.fromJson(r)).toList(growable: false),
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }
}
