import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kamelscan/core/services/supabase_service.dart';
import 'package:kamelscan/core/utils/app_failure.dart';

/// Pemetaan kegagalan jaringan menjadi pesan yang benar (Bab 9.10).
///
/// 🔴 Cacat yang dijawab berkas ini, terlihat di perangkat 19 Agustus 2026:
/// dengan mode pesawat menyala, layar pembuka menampilkan
///
///     "Terjadi kesalahan. Coba lagi beberapa saat."
///
/// padahal yang terjadi sinyalnya hilang. Kalimat itu menyembunyikan
/// satu-satunya hal yang perlu diketahui penggunanya, dan di gudang keliru itu
/// berarti packer mencari-cari masalah pada aplikasi padahal cukup berjalan ke
/// tempat yang ada sinyalnya.
///
/// Sebabnya `mapError` tidak mengenal `ClientException` maupun
/// `TimeoutException` sama sekali, sehingga keduanya jatuh ke `unknown`.
void main() {
  group('Kegagalan jaringan dikenali sebagai jaringan', () {
    test('TimeoutException dari batas waktu permintaan', () {
      final failure = SupabaseService.mapError(
        TimeoutException('lewat batas', const Duration(seconds: 15)),
      );

      expect(failure.kind, FailureKind.network);
      expect(failure.messageKey, 'errorNetwork');
    });

    test('ClientException — pembungkus SocketException di Android', () {
      // Bentuk aslinya, disalin dari logcat 19 Agustus 2026:
      //   ClientException with SocketException: Failed host lookup:
      //   'ofggpithmvgnhsshglwx.supabase.co' (OS Error: No address associated
      //   with hostname, errno = 7)
      final failure = SupabaseService.mapError(
        http.ClientException(
          "Failed host lookup: 'ofggpithmvgnhsshglwx.supabase.co'",
        ),
      );

      expect(failure.kind, FailureKind.network);
      expect(failure.messageKey, 'errorNetwork');
    });

    test('pesan aslinya tetap disimpan untuk diagnosis', () {
      final failure = SupabaseService.mapError(
        http.ClientException('Failed host lookup'),
      );

      // Bab 9.10 melarang pesan mentah server sampai ke layar, tetapi ia tetap
      // dibawa di `debugMessage` supaya jejak logcat masih menjelaskan sebabnya.
      expect(failure.debugMessage, contains('Failed host lookup'));
    });

    test('dapat dicoba lagi, sehingga tombol Coba lagi muncul', () {
      // `AppErrorView` hanya menampilkan tombolnya bila failure-nya retryable.
      // Kegagalan jaringan justru keadaan yang paling layak dicoba ulang.
      expect(
        SupabaseService.mapError(http.ClientException('x')).isRetryable,
        isTrue,
      );
    });
  });

  group('Kegagalan lain tidak ikut tersapu', () {
    test('AppFailure yang sudah jadi diteruskan apa adanya', () {
      expect(
        SupabaseService.mapError(AppFailure.tokenExhausted).messageKey,
        AppFailure.tokenExhausted.messageKey,
      );
    });

    test('galat yang tidak dikenal tetap unknown', () {
      final failure = SupabaseService.mapError(StateError('entah apa'));

      expect(failure.kind, FailureKind.unknown);
    });
  });
}
