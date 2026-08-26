import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/repositories/video_repository.dart';
import 'package:kamelscan/pages/web/history/web_history_view_model.dart';

/// Hitungan halaman tabel Riwayat web (Bab 10.5).
///
/// 🔴 Dipisah sebagai hitungan murni karena salahnya diam. Nomor halaman
/// terakhir yang meleset satu menghasilkan tombol "berikutnya" yang membuka
/// tabel kosong — dan yang melihatnya menyimpulkan datanya habis, bukan
/// menyimpulkan tombolnya salah.
void main() {
  WebHistoryData data({required int total, int page = 0, int pageSize = 25}) =>
      WebHistoryData(
        items: const [],
        total: total,
        page: page,
        pageSize: pageSize,
        filter: const VideoFilter(),
        sort: HistorySort.date,
        ascending: false,
      );

  group('Jumlah halaman', () {
    test('pas sekali halaman', () {
      expect(data(total: 25).pageCount, 1);
    });

    test('🔴 lebih satu baris berarti dua halaman', () {
      // Inilah yang paling mudah meleset: pembagian biasa memberi 1 untuk 26
      // baris, dan baris ke-26 tidak akan pernah dapat dibuka.
      expect(data(total: 26).pageCount, 2);
    });

    test('kelipatan pas tidak menghasilkan halaman kosong di belakang', () {
      // 50 / 25 = 2 tepat. Rumus yang salah memberi 3, dan halaman terakhir
      // selalu kosong.
      expect(data(total: 50).pageCount, 2);
      expect(data(total: 431).pageCount, 18);
    });

    test('tabel kosong tetap "halaman 1 dari 1"', () {
      // Bukan "halaman 1 dari 0".
      expect(data(total: 0).pageCount, 1);
    });
  });

  group('Rentang baris yang sedang ditampilkan', () {
    test('halaman pertama', () {
      final d = data(total: 431);
      expect(d.firstRow, 1);
      expect(d.lastRow, 25);
    });

    test('halaman tengah', () {
      final d = data(total: 431, page: 3);
      expect(d.firstRow, 76);
      expect(d.lastRow, 100);
    });

    test('halaman terakhir berhenti pada jumlah sebenarnya', () {
      // 431 baris, halaman ke-18 (indeks 17) berisi 6 baris saja.
      final d = data(total: 431, page: 17);
      expect(d.firstRow, 426);
      expect(d.lastRow, 431);
    });

    test('tabel kosong menyebut baris 0, bukan baris 1', () {
      final d = data(total: 0);
      expect(d.firstRow, 0);
      expect(d.lastRow, 0);
    });
  });

  group('Tombol maju dan mundur', () {
    test('halaman pertama tidak bisa mundur', () {
      expect(data(total: 431).hasPrevious, isFalse);
      expect(data(total: 431).hasNext, isTrue);
    });

    test('halaman terakhir tidak bisa maju', () {
      final d = data(total: 431, page: 17);
      expect(d.hasPrevious, isTrue);
      expect(d.hasNext, isFalse);
    });

    test('satu-satunya halaman tidak bisa ke mana-mana', () {
      final d = data(total: 3);
      expect(d.hasPrevious, isFalse);
      expect(d.hasNext, isFalse);
    });
  });

  group('Kolom yang boleh diurutkan', () {
    test('seluruhnya kolom milik package_videos sendiri', () {
      // Bila suatu hari ada yang menambahkan kolom tabel tetangga
      // (`shops(shop_name)`), baris ini yang memberi tahu — pengurutan
      // semacam itu belum pernah dibuktikan, dan bila salah server hanya
      // mengabaikannya tanpa satu pun pesan.
      for (final s in HistorySort.values) {
        expect(s.column, isNot(contains('(')));
        expect(s.column, isNot(contains('.')));
      }
    });
  });
}
