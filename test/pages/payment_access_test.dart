import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/pages/payment/payment_access.dart';

/// Di mana pembayaran boleh diselesaikan (Bab 12.5).
///
/// 🔴 Tes ini ada justru karena widget-nya TIDAK dapat menguji cabang webnya.
///
/// `kIsWeb` konstanta waktu kompilasi, dan pada `flutter test` nilainya selalu
/// `false`. Artinya seluruh tes widget di proyek ini berjalan sebagai
/// **mobile**: cabang web tidak pernah dijalankan sekali pun, dan cacat di
/// dalamnya tidak pernah tertangkap. Itulah sebabnya aturannya dipisah menjadi
/// fungsi yang menerima `isWeb` — uraiannya di `DEVIASI_LIBRARY.md` **O.14**.
void main() {
  group('Bab 12.5 — pembayaran hanya diselesaikan di web', () {
    test('web boleh membayar', () {
      expect(PaymentAccess.canPay(isWeb: true), isTrue);
    });

    test('🔴 aplikasi HP tidak boleh menyelesaikan pembayaran', () {
      // Google Play dan Apple App Store mewajibkan pembelian dalam aplikasi
      // untuk konten digital. Melewatkannya berisiko aplikasi ditolak saat
      // review — 1–2 minggu hilang tepat di akhir proyek (Bab 12.5).
      expect(PaymentAccess.canPay(isWeb: false), isFalse);
    });

    test('canPayHere mengikuti platform yang sedang berjalan', () {
      // Pada `flutter test`, kIsWeb selalu false. Nilai ini karena itu WAJIB
      // false di sini — bila suatu hari ia berubah menjadi true, berarti ada
      // yang menyambungkannya ke sesuatu selain kIsWeb, dan seluruh penjagaan
      // Bab 12.5 ikut lumpuh tanpa satu pun galat.
      expect(PaymentAccess.canPayHere, isFalse);
    });
  });
}
