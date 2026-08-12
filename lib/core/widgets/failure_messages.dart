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
      _ => t.errorUnknown,
    };
  }
}
