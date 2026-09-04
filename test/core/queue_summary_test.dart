import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/models/queue_summary.dart';

/// Aturan ringkasan antrian (Bab 8.7).
///
/// 🔴 Kenapa pemisahan ini ada. Sampai 3 September 2026 Beranda hanya tahu
/// satu angka — jumlah baris yang belum selesai — dan kalimat di sebelahnya
/// ditulis mati: *"{n} video dalam antrean — menunggu Wi-Fi"*.
///
/// Kalimat itu diucapkan tanpa peduli sebab sebenarnya. Saat sebuah video
/// gagal diberi watermark, layar tetap menyalahkan jaringan; Product Owner
/// lalu menyalakan "Unggah lewat data seluler" — pengaturan yang sama sekali
/// tidak berhubungan — dan tentu saja tidak terjadi apa-apa.
void main() {
  group('total & kosong', () {
    test('total menjumlahkan keempat golongan', () {
      const r = QueueSummary(
        siap: 1,
        sedangDiproses: 2,
        gagal: 3,
        tertunda: 4,
      );
      expect(r.total, 10);
      expect(r.kosong, isFalse);
    });

    test('bawaan kosong', () {
      const r = QueueSummary();
      expect(r.total, 0);
      expect(r.kosong, isTrue);
    });
  });

  group('🔴 adaYangDapatDiunggah — janji tombol "Unggah sekarang"', () {
    test('hanya benar bila ada yang SIAP', () {
      expect(const QueueSummary(siap: 1).adaYangDapatDiunggah, isTrue);
    });

    test('baris gagal TIDAK membuatnya benar', () {
      // Baris yang jatah percobaannya habis tidak akan pernah disentuh
      // penjalan antrian. Menghitungnya sebagai "dapat diunggah" berarti
      // tombolnya menjanjikan sesuatu yang tidak dapat ia tepati — dan itulah
      // yang membuat tombol terasa rusak.
      expect(const QueueSummary(gagal: 3).adaYangDapatDiunggah, isFalse);
    });

    test('rekaman yang masih diproses TIDAK membuatnya benar', () {
      // Rekaman mentah tidak pernah boleh diunggah (Bab 8.5).
      expect(
        const QueueSummary(sedangDiproses: 2).adaYangDapatDiunggah,
        isFalse,
      );
    });

    test('baris yang menunggu giliran TIDAK membuatnya benar', () {
      expect(const QueueSummary(tertunda: 5).adaYangDapatDiunggah, isFalse);
    });

    test('🔴 antrian TIDAK kosong tetapi tidak ada yang dapat diunggah', () {
      // Keadaan yang persis dialami Product Owner: satu video gagal watermark,
      // spanduk tetap menghitungnya, dan menekan tombolnya tidak mungkin
      // berhasil berapa kali pun.
      const r = QueueSummary(gagal: 1);
      expect(r.kosong, isFalse);
      expect(r.total, 1);
      expect(r.adaYangDapatDiunggah, isFalse);
    });
  });

  test('kesetaraan dipakai untuk menahan emisi yang tidak berubah', () {
    // Aliran ringkasan hanya memancar saat nilainya BERBEDA; tanpa `==` yang
    // benar, denyut 8 detik akan membangun ulang spanduk setiap kali walau
    // tidak ada yang berubah.
    expect(const QueueSummary(siap: 1), const QueueSummary(siap: 1));
    expect(
      const QueueSummary(siap: 1),
      isNot(const QueueSummary(siap: 1, gagal: 1)),
    );
    expect(
      const QueueSummary(siap: 1).hashCode,
      const QueueSummary(siap: 1).hashCode,
    );
  });
}
