import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_constants.dart';
import '../models/shop.dart';
import '../services/supabase_service.dart';
import '../utils/result.dart';

/// Sumber kebenaran data toko untuk ViewModel (pola wajib Bab 3.4).
///
/// Repository **tidak menyimpan state** (Bab 3.1 poin 3) — ia hanya
/// menerjemahkan baris mentah menjadi Model.
class ShopRepository {
  const ShopRepository(this._client);

  final SupabaseClient _client;

  Future<Result<List<Shop>>> fetchShops({bool activeOnly = false}) async {
    try {
      // RLS otomatis memfilter berdasarkan tenant (Bab 5.4).
      // Tidak perlu — dan tidak boleh diandalkan — .eq('tenant_id', ...).
      var query = _client.from(AppConstants.tblShops).select();
      if (activeOnly) query = query.eq('is_active', true);

      final rows = await query.order('created_at', ascending: false);
      return Result.ok(
        rows.map((r) => Shop.fromJson(r)).toList(growable: false),
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  Future<Result<Shop>> fetchShop(String id) async {
    try {
      final row = await _client
          .from(AppConstants.tblShops)
          .select()
          .eq('id', id)
          .single();
      return Result.ok(Shop.fromJson(row));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  Future<Result<Shop>> createShop({
    required String tenantId,
    required String marketName,
    required String shopName,
  }) async {
    try {
      final row = await _client
          .from(AppConstants.tblShops)
          .insert({
            'tenant_id': tenantId,
            'market_name': marketName,
            'shop_name': shopName,
          })
          .select()
          .single();
      return Result.ok(Shop.fromJson(row));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  Future<Result<Shop>> updateShop(
    String id, {
    String? marketName,
    String? shopName,
    bool? isActive,
  }) async {
    try {
      final row = await _client
          .from(AppConstants.tblShops)
          .update({
            'market_name': ?marketName,
            'shop_name': ?shopName,
            'is_active': ?isActive,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();
      return Result.ok(Shop.fromJson(row));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// ⚠️ `package_videos.shop_id` memakai `on delete restrict` (Bab 5.2), jadi
  /// toko yang sudah punya video **tidak dapat dihapus**. Ini disengaja: video
  /// tetap terikat pada toko saat perekaman terjadi (Bab 0.3). Untuk toko yang
  /// sudah tidak dipakai, gunakan [updateShop] dengan `isActive: false`.
  Future<Result<void>> deleteShop(String id) async {
    try {
      await _client.from(AppConstants.tblShops).delete().eq('id', id);
      return okVoid;
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }
}
