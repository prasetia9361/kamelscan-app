import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_constants.dart';
import '../models/app_settings.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

part 'theme_provider.g.dart';

/// Tema & bahasa aplikasi.
///
/// Disimpan di dua tempat dengan sengaja:
/// - **SharedPreferences** agar pilihan langsung berlaku saat aplikasi dibuka,
///   sebelum sesi Supabase selesai dipulihkan (tidak ada kedipan tema).
/// - **`user_settings` di server** agar pilihan ikut ke semua perangkat
///   pengguna (Bab 9.11 poin 4).
@Riverpod(keepAlive: true)
class AppPreferences extends _$AppPreferences {
  @override
  Future<AppPreferencesState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final local = AppPreferencesState(
      themeMode: _parseThemeMode(prefs.getString(AppConstants.prefThemeMode)),
      languageCode: prefs.getString(AppConstants.prefLanguage) ?? 'id',
      voiceOverEnabled:
          prefs.getBool(AppConstants.prefVoiceOverEnabled) ?? true,
      showRecordFab: prefs.getBool(AppConstants.prefShowRecordFab) ?? true,
    );

    // Setelah login, nilai server menang — perangkat baru harus mengikuti
    // pilihan yang sudah dibuat pengguna di perangkat lama.
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return local;

    final remote =
        (await ref.read(settingsRepositoryProvider).fetchUserSettings(userId))
            .valueOrNull;
    if (remote == null) return local;

    final merged = AppPreferencesState(
      themeMode: remote.themeMode,
      languageCode: remote.language,
      voiceOverEnabled: remote.voiceOverEnabled,
      showRecordFab: remote.showRecordFab,
    );
    await _persistLocal(prefs, merged);
    return merged;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final current = state.value;
    if (current == null) return;
    await _update(current.copyWith(themeMode: mode));
  }

  Future<void> setLanguage(String languageCode) async {
    final current = state.value;
    if (current == null || !_supportedLanguages.contains(languageCode)) return;
    await _update(current.copyWith(languageCode: languageCode));
  }

  Future<void> setVoiceOverEnabled(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    await _update(current.copyWith(voiceOverEnabled: enabled));
  }

  /// Tampilkan tombol Rekam mengambang di kerangka mobile (Bab 9.7,
  /// diminta Product Owner 31 Agustus 2026 bersama revisi tampilan).
  ///
  /// Saat dimatikan, perekaman dimulai dari kartu di Beranda — dan jarak bawah
  /// daftar ikut mengecil, karena ruang 88 dp itu memang disisakan khusus untuk
  /// tombolnya.
  Future<void> setShowRecordFab(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    await _update(current.copyWith(showRecordFab: enabled));
  }

  Future<void> _update(AppPreferencesState next) async {
    state = AsyncData(next);

    final prefs = await SharedPreferences.getInstance();
    await _persistLocal(prefs, next);

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    // Kegagalan sinkron ke server tidak boleh membatalkan perubahan lokal —
    // pengguna sudah melihat temanya berganti.
    await ref.read(settingsRepositoryProvider).saveUserSettings(
          UserSettings(
            userId: userId,
            theme: UserSettings.themeValueOf(next.themeMode),
            language: next.languageCode,
            voiceOverEnabled: next.voiceOverEnabled,
            showRecordFab: next.showRecordFab,
          ),
        );
  }

  Future<void> _persistLocal(
    SharedPreferences prefs,
    AppPreferencesState value,
  ) async {
    await prefs.setString(
      AppConstants.prefThemeMode,
      UserSettings.themeValueOf(value.themeMode),
    );
    await prefs.setString(AppConstants.prefLanguage, value.languageCode);
    await prefs.setBool(
      AppConstants.prefVoiceOverEnabled,
      value.voiceOverEnabled,
    );
    await prefs.setBool(AppConstants.prefShowRecordFab, value.showRecordFab);
  }

  static const Set<String> _supportedLanguages = {'id', 'en'};

  static ThemeMode _parseThemeMode(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}

class AppPreferencesState {
  const AppPreferencesState({
    required this.themeMode,
    required this.languageCode,
    required this.voiceOverEnabled,
    required this.showRecordFab,
  });

  final ThemeMode themeMode;
  final String languageCode;
  final bool voiceOverEnabled;
  final bool showRecordFab;

  AppPreferencesState copyWith({
    ThemeMode? themeMode,
    String? languageCode,
    bool? voiceOverEnabled,
    bool? showRecordFab,
  }) =>
      AppPreferencesState(
        themeMode: themeMode ?? this.themeMode,
        languageCode: languageCode ?? this.languageCode,
        voiceOverEnabled: voiceOverEnabled ?? this.voiceOverEnabled,
        showRecordFab: showRecordFab ?? this.showRecordFab,
      );
}

/// Nilai default dipakai selama preferensi masih dimuat, agar `MaterialApp`
/// tidak pernah menerima `null`.
@riverpod
ThemeMode themeMode(Ref ref) =>
    ref.watch(appPreferencesProvider).value?.themeMode ??
    ThemeMode.system;

@riverpod
String languageCode(Ref ref) =>
    ref.watch(appPreferencesProvider).value?.languageCode ?? 'id';

/// Bab 9.7 — tombol Rekam mengambang.
///
/// Default `true` selama preferensi masih dimuat: kerangka dibangun sebelum
/// `SharedPreferences` selesai dibaca, dan tombol yang berkedip muncul-hilang
/// tiap kali aplikasi dibuka lebih buruk daripada tombol yang selalu ada.
@riverpod
bool showRecordFab(Ref ref) =>
    ref.watch(appPreferencesProvider).value?.showRecordFab ?? true;
