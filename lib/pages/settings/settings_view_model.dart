import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/models/app_settings.dart';
import '../../core/providers/pipeline_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/session_provider.dart';
import '../../core/utils/app_failure.dart';

part 'settings_view_model.g.dart';

/// Pengaturan milik **tenant** pada halaman Pengaturan (Bab 9.7).
///
/// Terpisah dari `AppPreferences` — yang itu milik orangnya (tema, bahasa,
/// voice-over) dan ikut ke semua perangkatnya. Yang di sini milik usahanya, dan
/// hanya Owner yang boleh mengubahnya.
@riverpod
class TenantSettingsViewModel extends _$TenantSettingsViewModel {
  @override
  Future<TenantSettings> build() async {
    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;

    return (await ref
            .read(settingsRepositoryProvider)
            .fetchTenantSettings(session.tenantId))
        .unwrap();
  }

  /// Bab 9.7 — tampilkan koordinat GPS pada watermark video.
  ///
  /// ⚠️ Berlaku untuk video yang **direkam sesudah ini**. Video lama sudah
  /// terbakar apa adanya dan tidak berubah — itu memang sifat bukti: ia
  /// merekam keadaan saat itu, bukan pengaturan hari ini.
  Future<AppFailure?> setShowGps(bool value) =>
      _simpan((s) => s.copyWith(showGpsOnWatermark: value));

  /// Bab 2.2 catatan 3 — packer boleh melihat seluruh video pada toko yang
  /// ditugaskan kepadanya.
  ///
  /// 🔴 Ini bukan sekadar pengaturan tampilan. Nilainya dibaca langsung oleh
  /// policy RLS `videos_select` **dan** oleh Edge Function `get-video-url`,
  /// jadi mematikannya benar-benar menutup aksesnya di server — bukan hanya
  /// menyembunyikan menu.
  Future<AppFailure?> setShopHistoryVisible(bool value) =>
      _simpan((s) => s.copyWith(shopHistoryVisibleToPacker: value));

  Future<AppFailure?> _simpan(
    TenantSettings Function(TenantSettings) ubah,
  ) async {
    final current = state.value;
    if (current == null) return null;

    final next = ubah(current);

    // Tampilkan perubahannya lebih dulu supaya sakelar tidak terasa berat,
    // lalu kembalikan bila server menolak. Pengguna melihat sakelarnya kembali
    // ke posisi semula — itu jujur, dan lebih baik daripada sakelar yang
    // tampak menyala padahal servernya tidak menerima.
    state = AsyncData(next);

    final result =
        await ref.read(settingsRepositoryProvider).saveTenantSettings(next);

    final failure = result.failureOrNull;
    if (failure != null) {
      debugPrint('KAMELSCAN_SETTING simpan tenant GAGAL · $failure');
      state = AsyncData(current);
      return failure;
    }

    // Salinan lokal `tenant_settings` dipakai saat memberi watermark video di
    // gudang tanpa sinyal (`prefTenantSettings`). Tanpa penyegaran ini, video
    // berikutnya masih memakai pengaturan lama sampai aplikasi dibuka ulang.
    ref.invalidate(tenantSettingsProvider);
    return null;
  }
}
