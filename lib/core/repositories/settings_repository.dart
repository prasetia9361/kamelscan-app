import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_constants.dart';
import '../config/tier_config.dart';
import '../models/app_settings.dart';
import '../models/enums.dart';
import '../services/supabase_service.dart';
import '../utils/result.dart';

class SettingsRepository {
  const SettingsRepository(this._client);

  final SupabaseClient _client;

  // ---------- Preferensi pengguna ----------

  Future<Result<UserSettings>> fetchUserSettings(String userId) async {
    try {
      final row = await _client
          .from(AppConstants.tblUserSettings)
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      // Baris belum ada untuk pengguna baru — nilai default sudah benar.
      return Result.ok(
        row == null
            ? UserSettings(userId: userId)
            : UserSettings.fromJson(row),
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Pilihan pengguna berlaku di semua perangkatnya (Bab 9.11 poin 4), karena
  /// itu disimpan di server, bukan hanya SharedPreferences.
  Future<Result<UserSettings>> saveUserSettings(UserSettings settings) async {
    try {
      final row = await _client
          .from(AppConstants.tblUserSettings)
          .upsert({
            'user_id': settings.userId,
            'theme': settings.theme,
            'language': settings.language,
            'voice_over_enabled': settings.voiceOverEnabled,
            'show_record_fab': settings.showRecordFab,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();
      return Result.ok(UserSettings.fromJson(row));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  // ---------- Pengaturan tenant ----------

  Future<Result<TenantSettings>> fetchTenantSettings(String tenantId) async {
    try {
      final row = await _client
          .from(AppConstants.tblTenantSettings)
          .select()
          .eq('tenant_id', tenantId)
          .maybeSingle();
      return Result.ok(
        row == null
            ? TenantSettings(tenantId: tenantId)
            : TenantSettings.fromJson(row),
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// ⚠️ Bab 7.4 — hak memakai watermark logo kustom dicek ulang di Edge
  /// Function saat logo diunggah, bukan hanya di UI. Menyembunyikan tombol
  /// tidak menghentikan siapa pun yang memanggil API langsung (Bab 2.3).
  Future<Result<TenantSettings>> saveTenantSettings(
    TenantSettings settings,
  ) async {
    try {
      final row = await _client
          .from(AppConstants.tblTenantSettings)
          .upsert({
            'tenant_id': settings.tenantId,
            'watermark_position': settings.watermarkPosition.wire,
            'watermark_opacity': settings.watermarkOpacity,
            'show_gps_on_watermark': settings.showGpsOnWatermark,
            'shop_history_visible_to_packer':
                settings.shopHistoryVisibleToPacker,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();
      return Result.ok(TenantSettings.fromJson(row));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  // ---------- Pengaturan platform ----------

  /// Harga & kuota dibaca dari `platform_settings`, tidak ditulis mati di kode
  /// (Bab 7.1). Bila pembacaan gagal — misalnya perangkat offline saat pertama
  /// kali dibuka — nilai cadangan dipakai agar aplikasi tetap berjalan.
  Future<Result<TierCatalog>> fetchTierCatalog() async {
    try {
      final rows = await _client
          .from(AppConstants.tblPlatformSettings)
          .select()
          .inFilter('key', ['pricing', 'trial']);

      Map<String, dynamic>? pricing;
      Map<String, dynamic>? trial;
      for (final row in rows) {
        final value = row['value'];
        if (value is! Map) continue;
        final map = Map<String, dynamic>.from(value);
        if (row['key'] == 'pricing') pricing = map;
        if (row['key'] == 'trial') trial = map;
      }

      if (pricing == null) return const Result.ok(TierCatalog.fallback);
      return Result.ok(
        TierCatalog.fromPricingJson(pricing, trial: trial),
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  Future<Result<Map<String, dynamic>>> fetchPlatformSetting(String key) async {
    try {
      final row = await _client
          .from(AppConstants.tblPlatformSettings)
          .select('value')
          .eq('key', key)
          .maybeSingle();
      final value = row?['value'];
      return Result.ok(
        value is Map ? Map<String, dynamic>.from(value) : const {},
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  // ---------- Tutorial ----------

  Future<Result<List<Map<String, dynamic>>>> fetchTutorials({
    String platform = 'all',
  }) async {
    try {
      final rows = await _client
          .from(AppConstants.tblTutorials)
          .select()
          .eq('is_active', true)
          .inFilter('platform', ['all', platform])
          .order('step_order');
      return Result.ok(
        rows.map(Map<String, dynamic>.from).toList(growable: false),
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Helper kecil agar ViewModel tidak menyusun sendiri nilai kolom `theme`.
  static String themeValue(UserSettings settings) => settings.theme;

  static WatermarkPosition parsePosition(String? raw) =>
      WatermarkPosition.fromWire(raw);
}
