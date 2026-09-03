import 'package:flutter/material.dart' show ThemeMode;
import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'app_settings.freezed.dart';
part 'app_settings.g.dart';

/// Preferensi milik **pengguna** — tabel `public.user_settings` (Bab 5.2).
/// Tema, bahasa, dan voice-over mengikuti orangnya, bukan tenant.
@freezed
abstract class UserSettings with _$UserSettings {
  const factory UserSettings({
    required String userId,

    /// `default` | `light` | `dark`
    @Default('default') String theme,

    /// `id` | `en` (Bab 9.11)
    @Default('id') String language,
    @Default(true) bool voiceOverEnabled,

    /// Tampilkan tombol Rekam mengambang di kerangka mobile.
    ///
    /// Saat `false`, perekaman dimulai dari kartu di Beranda. Ditambahkan
    /// 31 Agustus 2026 atas permintaan Product Owner bersama revisi tampilan.
    ///
    /// ⚠️ Default `true` disengaja dan penting: kolom ini baru, jadi seluruh
    /// baris `user_settings` yang sudah ada tidak memilikinya. Kalau
    /// defaultnya `false`, setiap pengguna lama akan kehilangan tombol
    /// Rekamnya begitu aplikasi diperbarui — tanpa pernah meminta.
    @Default(true) bool showRecordFab,
    DateTime? updatedAt,
  }) = _UserSettings;

  const UserSettings._();

  factory UserSettings.fromJson(Map<String, dynamic> json) =>
      _$UserSettingsFromJson(json);

  ThemeMode get themeMode => switch (theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String themeValueOf(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'default',
      };

  /// Bahasa TTS mengikuti bahasa aktif (Bab 9.11 poin 6).
  String get ttsLocale => language == 'en' ? 'en-US' : 'id-ID';
}

/// Pengaturan milik **tenant** — tabel `public.tenant_settings`.
/// Hanya Owner yang boleh mengubah.
@freezed
abstract class TenantSettings with _$TenantSettings {
  const factory TenantSettings({
    required String tenantId,

    @Default(WatermarkPosition.bottomRight) WatermarkPosition watermarkPosition,
    @Default(0.75) double watermarkOpacity,
    @Default(true) bool showGpsOnWatermark,

    /// Bila true, packer boleh melihat seluruh video pada toko yang
    /// ditugaskan kepadanya (Bab 2.2 catatan 3).
    @Default(false) bool shopHistoryVisibleToPacker,
    DateTime? updatedAt,
  }) = _TenantSettings;

  const TenantSettings._();

  factory TenantSettings.fromJson(Map<String, dynamic> json) =>
      _$TenantSettingsFromJson(json);
}
