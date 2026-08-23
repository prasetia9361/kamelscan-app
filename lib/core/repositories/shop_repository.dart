import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_constants.dart';
import '../models/shop.dart';
import '../models/shop_summary.dart';
import '../services/supabase_service.dart';
import '../utils/result.dart';

/// Sumber kebenaran data toko untuk ViewModel (pola wajib Bab 3.4).
///
/// Repository **tidak menyimpan state** (Bab 3.1 poin 3) — ia hanya
/// menerjemahkan baris mentah menjadi Model.
class ShopRepository {
  const ShopRepository(this._client);

  final SupabaseClient _client;

  /// Daftar toko yang boleh dipakai pengguna aktif.
  ///
  /// [assignedOnly] menyaring ke toko yang **ditugaskan** kepada pengguna ini
  /// lewat `shop_packers`. Wajib dinyalakan untuk packer di layar pemilihan
  /// toko (panduan §8.2: *"Bagi packer, hanya toko yang ditugaskan kepadanya"*).
  ///
  /// 🔴 Jangan andalkan RLS untuk penyaringan ini. `shops_select` sengaja
  /// memberi seluruh anggota tenant hak baca atas semua toko, supaya nama toko
  /// tetap dapat ditampilkan di Riwayat — termasuk pada video lama dari toko
  /// yang penugasannya sudah dicabut. Menyempitkan policy itu akan membuat
  /// riwayat packer kehilangan nama tokonya.
  ///
  /// ⚠️ Sampai 20 Agustus 2026 layar perekaman memanggil metode ini tanpa
  /// penyaringan apa pun sambil menuliskan komentar bahwa "filter sesungguhnya
  /// ada di RLS". Filter itu tidak pernah ada. Akibatnya, packer yang hanya
  /// ditugaskan ke 2 toko tetap melihat ketiga toko di layar Pilih Toko **dan
  /// berhasil merekam atas nama toko yang bukan tugasnya** — terbukti di
  /// perangkat Product Owner. Penjagaan sesungguhnya sekarang ada di policy
  /// `videos_insert` (migrasi `24_videos_insert_assignment.sql`); penyaringan
  /// di sini yang membuat pilihannya tidak pernah muncul sejak awal.
  Future<Result<List<Shop>>> fetchShops({
    bool activeOnly = false,
    bool assignedOnly = false,
  }) async {
    try {
      // RLS otomatis memfilter berdasarkan tenant (Bab 5.4).
      // Tidak perlu — dan tidak boleh diandalkan — .eq('tenant_id', ...).
      //
      // `!inner` membuat toko tanpa baris penugasan yang cocok ikut tersingkir;
      // tanpa tanda itu PostgREST tetap mengembalikan tokonya dengan daftar
      // penugasan kosong, dan penyaringannya tidak terjadi sama sekali.
      final uid = SupabaseService.currentUser?.id;
      var query = assignedOnly && uid != null
          ? _client.from(AppConstants.tblShops).select(
                '*, ${AppConstants.tblShopPackers}!inner(user_id)',
              ).eq('${AppConstants.tblShopPackers}.user_id', uid)
          : _client.from(AppConstants.tblShops).select();

      if (activeOnly) query = query.eq('is_active', true);

      final rows = await query.order('created_at', ascending: false);
      return Result.ok(
        rows.map((r) => Shop.fromJson(r)).toList(growable: false),
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Daftar toko beserta jumlah videonya, untuk halaman Toko (Bab 9.5).
  ///
  /// Jumlahnya diambil lewat agregat bersarang PostgREST dalam permintaan yang
  /// sama. Alternatifnya satu permintaan `count` per toko — pada Owner dengan
  /// belasan toko itu belasan perjalanan bolak-balik hanya untuk mengisi satu
  /// baris angka.
  Future<Result<List<ShopSummary>>> fetchShopSummaries() async {
    try {
      final rows = await _client
          .from(AppConstants.tblShops)
          .select('*, ${AppConstants.tblPackageVideos}(count)')
          .order('created_at', ascending: false);

      return Result.ok(
        rows.map((r) => ShopSummary.fromJson(r)).toList(growable: false),
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
