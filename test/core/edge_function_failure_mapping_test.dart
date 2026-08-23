import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/services/supabase_service.dart';
import 'package:kamelscan/core/utils/app_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Kegagalan Edge Function diterjemahkan menjadi kalimat yang benar
/// (Bab 9.10).
///
/// 🔴 Cacat yang dijawab berkas ini, terlihat di logcat perangkat Product
/// Owner 20 Agustus 2026. Owner menambah packer dengan email yang sudah
/// terpakai; server menolak dengan sangat jelas:
///
///     FunctionsHttpException(status: 400,
///       details: {error: EMAIL_ALREADY_USED, ...})
///
/// tetapi yang sampai ke layar adalah *"Terjadi kesalahan. Coba lagi beberapa
/// saat."* — kalimat yang menyuruh mencoba lagi persis hal yang tidak akan
/// pernah berhasil.
///
/// Sebabnya `mapError` tidak mengenal `FunctionException` sama sekali,
/// sehingga seluruh penolakan dari Edge Function jatuh ke `unknown`. Kodenya
/// ada di dalam badan balasan, bukan di pesannya, jadi `_mapByMessage` pun
/// tidak pernah melihatnya.
void main() {
  AppFailure petakan(String kode, {int status = 400}) => SupabaseService.mapError(
        FunctionsHttpException(
          status: status,
          details: {'error': kode, 'detail': 'pesan asli dari server'},
        ),
      );

  group('Kode Edge Function punya kalimatnya sendiri', () {
    test('EMAIL_ALREADY_USED — bukan "terjadi kesalahan"', () {
      final failure = petakan('EMAIL_ALREADY_USED');

      expect(failure.kind, FailureKind.conflict);
      expect(failure.messageKey, 'packersEmailTaken');
      expect(failure.messageKey, isNot('errorUnknown'));
    });

    test('EMAIL_ALREADY_USED tidak memakai kalimat pendaftaran', () {
      // `errorEmailAlreadyUsed` menyuruh pembacanya masuk atau memakai Lupa
      // Password. Itu nasihat untuk orang yang mendaftarkan dirinya sendiri —
      // bukan untuk Owner yang sedang mendaftarkan packer-nya.
      expect(petakan('EMAIL_ALREADY_USED').messageKey,
          isNot('errorEmailAlreadyUsed'));
    });

    test('PACKER_HAS_VIDEOS dikenali agar layar dapat menahannya', () {
      final failure = petakan('PACKER_HAS_VIDEOS', status: 409);

      expect(failure.messageKey, AppFailure.packerHasVideos.messageKey);
    });

    test('PACKER_LIMIT_REACHED masuk kategori kuota', () {
      expect(petakan('PACKER_LIMIT_REACHED', status: 409).kind,
          FailureKind.quota);
    });

    test('SUBSCRIPTION_INACTIVE tidak disamarkan menjadi error umum', () {
      expect(petakan('SUBSCRIPTION_INACTIVE', status: 403).kind,
          FailureKind.subscriptionInactive);
    });

    test('FORBIDDEN menjadi penolakan izin, bukan kegagalan tak dikenal', () {
      expect(petakan('FORBIDDEN', status: 403).kind, FailureKind.permission);
    });

    test('UNAUTHORIZED menjadi sesi kedaluwarsa', () {
      expect(petakan('UNAUTHORIZED', status: 401).kind, FailureKind.auth);
    });

    test('NOT_FOUND menjadi notFound', () {
      expect(petakan('NOT_FOUND', status: 404).kind, FailureKind.notFound);
    });
  });

  group('Yang belum dikenal tetap jujur, bukan ditebak', () {
    test('kode asing jatuh ke unknown tetapi kodenya tetap terbawa', () {
      final failure = petakan('SESUATU_YANG_BELUM_ADA', status: 418);

      expect(failure.kind, FailureKind.unknown);
      // Tanpa ini, penolakan baru dari server hilang jejak sepenuhnya dan
      // hanya dapat ditemukan dengan menyambungkan perangkat ke logcat.
      expect(failure.code, 'SESUATU_YANG_BELUM_ADA');
      expect(failure.debugMessage, contains('pesan asli dari server'));
    });

    test('balasan tanpa badan yang dapat dibaca tidak membuat mapError jatuh', () {
      final failure = SupabaseService.mapError(
        const FunctionsHttpException(status: 500, details: 'bukan map'),
      );

      expect(failure.kind, FailureKind.unknown);
      expect(failure.code, '500');
    });
  });

  group('Gagal menghubungi fungsi adalah masalah jaringan', () {
    test('FunctionsFetchException dikenali sebagai jaringan, bukan penolakan', () {
      // Statusnya 0 — tidak ada balasan sama sekali. Menampilkannya sebagai
      // "terjadi kesalahan" akan membuat packer di gudang tanpa sinyal
      // menyalahkan aplikasi alih-alih berjalan ke tempat yang ada sinyalnya.
      final failure = SupabaseService.mapError(
        const FunctionsFetchException(details: 'SocketException'),
      );

      expect(failure.kind, FailureKind.network);
      expect(failure.messageKey, 'errorNetwork');
    });
  });
}
