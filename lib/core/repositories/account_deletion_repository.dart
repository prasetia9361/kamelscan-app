import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../utils/app_failure.dart';
import '../utils/result.dart';

/// Hasil permintaan hapus akun — dijawab RPC `request_account_deletion()`.
///
/// Dibedakan karena layarnya berbeda: akun trial sudah **tidak ada lagi** saat
/// jawabannya tiba, sedangkan akun berbayar baru dijadwalkan dan masih dapat
/// dibatalkan. Menampilkan kalimat "dapat dibatalkan dalam 7 hari" kepada
/// pemilik akun trial adalah janji yang tidak dapat ditepati siapa pun.
enum DeletionOutcome {
  /// Trial — datanya sudah musnah saat ini juga.
  dihapusSekarang,

  /// Berbayar — dijadwalkan, tenggang 7 hari berjalan.
  dijadwalkan,

  /// Permintaannya memang sudah ada sebelumnya. Bukan kegagalan.
  sudahDiminta,
}

/// Penghapusan akun oleh Owner sendiri (Bab 9.6, migrasi 37).
///
/// 🔴 Seluruhnya lewat RPC, bukan `update` biasa. Tabel `tenants` sengaja tidak
/// punya policy tulis bagi Owner sama sekali — dan itu benar: kolom yang
/// menentukan kapan datanya dimusnahkan tidak boleh dapat digeser dari
/// aplikasi. Verifikasi nama usahanya pun berlangsung di server, sehingga
/// memanggil RPC-nya langsung tanpa melewati layar konfirmasi tidak menolong
/// siapa pun.
class AccountDeletionRepository {
  const AccountDeletionRepository(this._client);

  final SupabaseClient _client;

  /// Meminta akun dihapus. [confirmation] adalah nama usaha yang diketik ulang
  /// Owner, dan server yang mencocokkannya.
  Future<Result<DeletionOutcome>> requestDeletion(String confirmation) async {
    try {
      final hasil = await _client.rpc<Object?>(
        'request_account_deletion',
        params: {'p_confirm': confirmation},
      );

      return Result.ok(switch (hasil?.toString()) {
        'DIHAPUS_SEKARANG' => DeletionOutcome.dihapusSekarang,
        'SUDAH_DIMINTA' => DeletionOutcome.sudahDiminta,
        _ => DeletionOutcome.dijadwalkan,
      });
    } on Object catch (e, s) {
      // 🔴 Ketidakcocokan nama usaha WAJIB punya kalimatnya sendiri. Inilah
      // satu-satunya galat yang benar-benar mungkin terjadi di layar ini, dan
      // "Terjadi kesalahan" tidak memberi tahu apa pun tentang apa yang harus
      // diperbaiki — cacat M.16.
      if (e.toString().contains('CONFIRM_MISMATCH')) {
        return Result.err(AppFailure.validation('errorDeleteConfirmMismatch'));
      }
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Membatalkan permintaan yang tenggangnya belum habis.
  Future<Result<void>> cancelDeletion() async {
    try {
      await _client.rpc<Object?>('cancel_account_deletion');
      return okVoid;
    } on Object catch (e, s) {
      // Tenggangnya habis di sela-sela: layarnya masih terbuka, tetapi cron
      // sudah berjalan atau tinggal menghitung detik. Menyebutnya "kesalahan"
      // menyesatkan — yang terjadi adalah kesempatannya memang sudah lewat.
      if (e.toString().contains('CANCEL_TOO_LATE')) {
        return Result.err(AppFailure.validation('errorCancelDeleteTooLate'));
      }
      return Result.err(SupabaseService.mapError(e, s));
    }
  }
}
