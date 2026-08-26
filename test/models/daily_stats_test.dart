import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/models/daily_stats.dart';

/// Model dasbor web (Bab 10.4) — pemetaan JSON dan hitungan turunannya.
///
/// 🔴 Yang paling perlu dijaga di sini adalah kunci `return`. Ia melanggar dua
/// aturan sekaligus: `return` kata kunci Dart, dan `field_rename: snake` di
/// `build.yaml` akan mencari `return_count` yang tidak pernah dikirim server.
/// Bila `@JsonKey` hilang, angka return **diam-diam menjadi nol** — tidak ada
/// galat, tidak ada peringatan, grafiknya hanya rata di bawah.
void main() {
  /// Bentuk yang dikirim `get_daily_stats()` apa adanya.
  Map<String, dynamic> contohJson({
    List<Map<String, dynamic>>? series,
    Map<String, dynamic>? total,
    Map<String, dynamic>? previous,
    int days = 3,
  }) =>
      {
        'days': days,
        'start_date': '2026-08-24',
        'end_date': '2026-08-26',
        'series': series ??
            [
              {'date': '2026-08-24', 'packing': 5, 'return': 1},
              {'date': '2026-08-25', 'packing': 0, 'return': 0},
              {'date': '2026-08-26', 'packing': 7, 'return': 2},
            ],
        'total': total ?? {'packing': 12, 'return': 3},
        'previous': previous ?? {'packing': 10, 'return': 2},
      };

  group('Pemetaan JSON', () {
    test('kunci "return" terbaca, bukan menjadi nol', () {
      final stats = DailyStats.fromJson(contohJson());

      expect(stats.total.returnCount, 3);
      expect(stats.previous.returnCount, 2);
      expect(stats.series.first.returnCount, 1);
      expect(stats.series.last.returnCount, 2);
    });

    test('tanggal dibaca sebagai hari setempat, tidak bergeser', () {
      final stats = DailyStats.fromJson(contohJson());

      // Server sudah memindahkannya ke waktu Jakarta dan mengirim tanggal
      // polos. Menafsirkannya sebagai UTC akan menggesernya tujuh jam dan
      // memundurkan seluruh grafik satu hari.
      expect(stats.startDate.year, 2026);
      expect(stats.startDate.month, 8);
      expect(stats.startDate.day, 24);
      expect(stats.series.last.date.day, 26);
    });

    test('hari kosong tetap menjadi satu titik bernilai nol', () {
      final stats = DailyStats.fromJson(contohJson());

      expect(stats.series.length, 3);
      expect(stats.series[1].total, 0);
    });
  });

  group('Hitungan turunan', () {
    test('total menjumlahkan packing dan return', () {
      final stats = DailyStats.fromJson(contohJson());
      expect(stats.totalVideos, 15);
    });

    test('rata-rata dibagi jumlah HARI, bukan jumlah hari yang ada isinya', () {
      final stats = DailyStats.fromJson(contohJson());

      // 15 video / 3 hari = 5. Membagi dengan 2 (hari yang ada rekamannya)
      // menghasilkan 7,5 — angka yang selalu terlihat lebih bagus dan tidak
      // dapat dipakai membandingkan dua periode.
      expect(stats.averagePerDay, 5);
    });

    test('🔴 puncak adalah garis tertinggi, BUKAN jumlah kedua garis', () {
      final stats = DailyStats.fromJson(contohJson());

      // Hari terakhir: packing 7, return 2. Yang digambar dua garis terpisah,
      // jadi titik tertingginya 7 — bukan 9. Memakai 9 sebagai batas atas
      // sumbu memipihkan seluruh grafik tanpa satu pun galat.
      expect(stats.peak, 7);
    });

    test('rentang nol hari tidak membuat pembagian dengan nol', () {
      final stats = DailyStats.fromJson(contohJson(days: 0));
      expect(stats.averagePerDay, 0);
    });
  });

  group('Perbandingan dengan periode sebelumnya', () {
    test('naik menghasilkan pecahan positif', () {
      final stats = DailyStats.fromJson(contohJson());
      // packing 10 → 12
      expect(stats.packingChange, closeTo(0.2, 1e-9));
    });

    test('turun menghasilkan pecahan negatif', () {
      final stats = DailyStats.fromJson(contohJson(
        total: {'packing': 5, 'return': 0},
        previous: {'packing': 10, 'return': 0},
      ));
      expect(stats.packingChange, closeTo(-0.5, 1e-9));
    });

    test('🔴 periode sebelumnya nol menghasilkan null, BUKAN 0 atau 1', () {
      final stats = DailyStats.fromJson(contohJson(
        total: {'packing': 40, 'return': 3},
        previous: {'packing': 0, 'return': 0},
      ));

      // Naik dari 0 ke 40 bukan "naik 100%" dan bukan "tidak berubah".
      // Angka apa pun yang dipaksakan di sini akan dituliskan layar sebagai
      // fakta — dan itu fakta yang dikarang.
      expect(stats.packingChange, isNull);
      expect(stats.returnChange, isNull);
      expect(stats.totalChange, isNull);
    });

    test('keduanya nol juga null, bukan "tidak berubah"', () {
      final stats = DailyStats.fromJson(contohJson(
        total: {'packing': 0, 'return': 0},
        previous: {'packing': 0, 'return': 0},
      ));
      expect(stats.totalChange, isNull);
    });
  });

  group('Kondisi kosong Bab 3.4', () {
    test('kosong bila tidak ada satu pun video pada rentangnya', () {
      final stats = DailyStats.fromJson(contohJson(
        series: [
          {'date': '2026-08-24', 'packing': 0, 'return': 0},
          {'date': '2026-08-25', 'packing': 0, 'return': 0},
        ],
        total: {'packing': 0, 'return': 0},
      ));
      expect(stats.isEmpty, isTrue);
    });

    test('tidak kosong walau hanya ada satu video return', () {
      final stats = DailyStats.fromJson(contohJson(
        total: {'packing': 0, 'return': 1},
      ));

      // Kalau `@JsonKey(name: 'return')` hilang, baris inilah yang gagal:
      // satu-satunya video tidak terbaca dan dasbor menyatakan dirinya kosong.
      expect(stats.isEmpty, isFalse);
    });
  });
}
