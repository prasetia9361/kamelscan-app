import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';
import '../utils/app_failure.dart';

/// Penerjemah `AppFailure.messageKey` menjadi kalimat berbahasa manusia.
///
/// Bab 9.11 poin 5: `AppFailure` **tidak** menyimpan teks — hanya jenis error.
/// Penerjemahan terjadi di lapisan UI, sehingga pesan otomatis ikut bahasa
/// aktif tanpa perlu membangun ulang objek error.
extension FailureMessages on BuildContext {
  AppL10n get l10n => AppL10n.of(this);

  String get l10nRetry => l10n.commonRetry;

  String failureMessage(AppFailure failure) =>
      messageForKey(failure.messageKey);

  /// Kunci yang tidak dikenal jatuh ke pesan umum, bukan menampilkan kuncinya
  /// mentah-mentah ke pengguna.
  ///
  /// 🔴 **Setiap `messageKey` baru WAJIB didaftarkan di bawah ini.** Lupa
  /// mendaftarkannya tidak menimbulkan error apa pun — tidak saat `analyze`,
  /// tidak saat `test`, tidak saat dijalankan. Yang terjadi hanya pesannya
  /// diam-diam berubah menjadi *"Terjadi kesalahan. Coba lagi beberapa saat."*
  ///
  /// Terjadi 20 Agustus 2026, dan ironisnya justru pada perbaikan yang dibuat
  /// untuk menghapus kalimat itu: `packersEmailTaken` sudah ada di ARB, sudah
  /// dipetakan dari kode Edge Function, dan tetap tidak pernah sampai ke layar
  /// karena berhenti di daftar ini. Dijaga sekarang oleh
  /// `test/core/failure_message_keys_test.dart`, yang membaca `AppFailure`
  /// langsung dari sumbernya dan menolak kunci yang belum terdaftar.
  String messageForKey(String key) {
    final t = l10n;
    return switch (key) {
      'errorNetwork' => t.errorNetwork,
      'errorSessionExpired' => t.errorSessionExpired,
      'errorPermissionDenied' => t.errorPermissionDenied,
      'errorNotFound' => t.errorNotFound,
      'errorResiDuplicate' => t.errorResiDuplicate,
      'errorTokenExhausted' => t.errorTokenExhausted,
      'errorSubscriptionInactive' => t.errorSubscriptionInactive,
      'errorPackerLimitReached' => t.errorPackerLimitReached,
      'errorStorage' => t.errorStorage,
      'errorConfigMissing' => t.errorConfigMissing,
      'permissionCameraDenied' => t.permissionCameraDenied,
      'permissionMicrophoneDenied' => t.permissionMicrophoneDenied,
      'permissionLocationDenied' => t.permissionLocationDenied,
      'permissionStorageDenied' => t.permissionStorageDenied,
      'webRecordingUnavailable' => t.webRecordingUnavailable,
      'trialExhausted' => t.trialExhausted,
      'validationRequired' => t.validationRequired,
      'validationEmailRequired' => t.validationEmailRequired,
      'validationEmailInvalid' => t.validationEmailInvalid,
      'validationPasswordRequired' => t.validationPasswordRequired,
      'validationPasswordTooShort' => t.validationPasswordTooShort,
      'validationPasswordWeak' => t.validationPasswordWeak,
      'validationPasswordMismatch' => t.validationPasswordMismatch,
      'validationUsernameRequired' => t.validationUsernameRequired,
      'validationUsernameInvalid' => t.validationUsernameInvalid,
      'validationUsernameTaken' => t.validationUsernameTaken,
      'validationNameRequired' => t.validationNameRequired,
      'validationNameTooShort' => t.validationNameTooShort,
      'validationNameTooLong' => t.validationNameTooLong,
      'validationPhoneRequired' => t.validationPhoneRequired,
      'validationPhoneInvalid' => t.validationPhoneInvalid,
      'validationResiRequired' => t.validationResiRequired,
      'validationResiNotACode' => t.validationResiNotACode,
      'validationResiInvalid' => t.validationResiInvalid,
      'validationShopNameRequired' => t.validationShopNameRequired,
      'validationShopNameTooLong' => t.validationShopNameTooLong,
      'errorTooManyAttempts' => t.errorTooManyAttempts,
      'errorGoogleNotConfigured' => t.errorGoogleNotConfigured,
      'errorGoogleNoToken' => t.errorGoogleNoToken,
      'errorGoogleFailed' => t.errorGoogleFailed,
      'errorCancelled' => t.errorCancelled,
      'errorCurrentPasswordWrong' => t.errorCurrentPasswordWrong,
      'errorInvalidCredentials' => t.errorInvalidCredentials,
      'errorEmailNotConfirmed' => t.errorEmailNotConfirmed,
      'errorEmailAlreadyUsed' => t.errorEmailAlreadyUsed,
      'errorEmailRateLimited' => t.errorEmailRateLimited,
      'errorResetLinkInvalid' => t.errorResetLinkInvalid,
      'errorSamePassword' => t.errorSamePassword,
      'errorAuthGeneric' => t.errorAuthGeneric,
      'errorSignUpConflict' => t.errorSignUpConflict,
      'errorAccountDisabled' => t.errorAccountDisabled,
      'errorTenantSuspended' => t.errorTenantSuspended,
      'errorWatermarkFontMissing' => t.errorWatermarkFontMissing,
      'packersEmailTaken' => t.packersEmailTaken,
      'packersCannotDeleteTitle' => t.packersCannotDeleteTitle,

      // Bab 12.3 — kegagalan Midtrans. Masing-masing punya kalimatnya sendiri
      // karena tindakan yang benar berbeda-beda: menunggu Admin, mencoba lagi
      // nanti, atau menyelesaikan tagihan yang sudah ada. "Terjadi kesalahan"
      // membuat ketiganya diperlakukan sama, yaitu dicoba ulang berkali-kali.
      'errorMidtransDisabled' => t.errorMidtransDisabled,
      'errorMidtransNotConfigured' => t.errorMidtransNotConfigured,
      'errorMidtransUnreachable' => t.errorMidtransUnreachable,
      'errorBillPendingExists' => t.errorBillPendingExists,
      'errorPricingMissing' => t.errorPricingMissing,
      'errorAmountZero' => t.errorAmountZero,
      'promoNotFound' => t.promoNotFound,

      _ => t.errorUnknown,
    };
  }
}
