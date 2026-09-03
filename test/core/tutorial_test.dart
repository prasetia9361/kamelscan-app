import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/models/tutorial.dart';

/// Aturan halaman Tutorial (Bab 9.9) yang tidak melibatkan perangkat.
///
/// 🔴 Dua di antaranya menjaga cacat yang **tidak akan menghasilkan galat apa
/// pun** bila salah: daftar yang urutannya berpindah-pindah, dan langkah yang
/// muncul di rangka yang bukan miliknya. Keduanya hanya terlihat oleh orang
/// yang memakai aplikasinya, bukan oleh `analyze` maupun oleh tes yang hanya
/// memeriksa halamannya tergambar.
void main() {
  Tutorial buat({
    String id = 't1',
    int stepOrder = 1,
    String title = 'Langkah',
    String url = 'https://youtu.be/dQw4w9WgXcQ',
    String platform = 'all',
    bool isActive = true,
  }) =>
      Tutorial(
        id: id,
        stepOrder: stepOrder,
        title: title,
        youtubeUrl: url,
        platform: platform,
        isActive: isActive,
      );

  group('Membaca kode video dari tautan', () {
    test('bentuk watch?v= — yang disalin orang dari bilah alamat', () {
      expect(
        buat(url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ').youtubeId,
        'dQw4w9WgXcQ',
      );
    });

    test('bentuk youtu.be — yang diberikan tombol Bagikan', () {
      expect(buat(url: 'https://youtu.be/dQw4w9WgXcQ').youtubeId,
          'dQw4w9WgXcQ');
    });

    test('bentuk /embed/ dan /shorts/', () {
      expect(
        buat(url: 'https://www.youtube.com/embed/dQw4w9WgXcQ').youtubeId,
        'dQw4w9WgXcQ',
      );
      expect(
        buat(url: 'https://youtube.com/shorts/dQw4w9WgXcQ').youtubeId,
        'dQw4w9WgXcQ',
      );
    });

    test('parameter tambahan tidak mengganggu pembacaannya', () {
      expect(
        buat(url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=90')
            .youtubeId,
        'dQw4w9WgXcQ',
      );
    });

    test('bukan YouTube, kosong, dan omong kosong semuanya null', () {
      expect(buat(url: 'https://vimeo.com/12345').youtubeId, isNull);
      expect(buat(url: '').youtubeId, isNull);
      expect(buat(url: 'bukan alamat sama sekali').youtubeId, isNull);
      expect(buat(url: 'https://www.youtube.com/').youtubeId, isNull);
    });

    test('🔴 tautan tidak dikenali TIDAK melempar — ia hanya null', () {
      // Formulir Admin memakai nilai ini untuk memberi peringatan, bukan untuk
      // memblokir. Melempar di sini berarti satu salah tempel meruntuhkan
      // seluruh halaman Kelola Tutorial.
      expect(() => buat(url: '::::').youtubeId, returnsNormally);
      expect(buat(url: '::::').isYoutubeUrlValid, isFalse);
    });
  });

  group('Penyaringan platform', () {
    test('all tampil di kedua rangka', () {
      final t = buat(platform: 'all');
      expect(t.berlakuDi(isWeb: true), isTrue);
      expect(t.berlakuDi(isWeb: false), isTrue);
    });

    test('mobile hanya di HP, web hanya di web', () {
      expect(buat(platform: 'mobile').berlakuDi(isWeb: false), isTrue);
      expect(buat(platform: 'mobile').berlakuDi(isWeb: true), isFalse);
      expect(buat(platform: 'web').berlakuDi(isWeb: true), isTrue);
      expect(buat(platform: 'web').berlakuDi(isWeb: false), isFalse);
    });

    test('🔴 nilai tak dikenal tidak tampil di mana pun, bukan di mana-mana',
        () {
      // `platform` teks bebas di database (Bab 5.2), jadi salah ketik Admin
      // mungkin terjadi. Jatuhan `true` akan membuat langkah yang salah ketik
      // muncul di KEDUA rangka sebagai langkah yang tidak relevan — kekeliruan
      // yang menyebar. Jatuhan `false` membuatnya hilang, yang segera terlihat
      // Admin sendiri di halamannya.
      final t = buat(platform: 'moblie');
      expect(t.berlakuDi(isWeb: true), isFalse);
      expect(t.berlakuDi(isWeb: false), isFalse);
    });
  });

  group('Urutan tampil', () {
    test('menurut step_order menaik', () {
      final daftar = [
        buat(id: 'c', stepOrder: 3, title: 'Ketiga'),
        buat(id: 'a', stepOrder: 1, title: 'Pertama'),
        buat(id: 'b', stepOrder: 2, title: 'Kedua'),
      ]..sort(Tutorial.urutkan);

      expect(daftar.map((e) => e.id).toList(), ['a', 'b', 'c']);
    });

    test('🔴 nomor kembar TIDAK membuat urutannya berpindah-pindah', () {
      // `step_order` tidak unik di database. Tanpa pemutus seri, dua langkah
      // bernomor sama bertukar tempat setiap kali daftarnya dimuat ulang — dan
      // daftar bernomor yang isinya berpindah persis yang paling membingungkan
      // pada layar yang gunanya mengajari orang.
      //
      // Diuji dengan menyusun ulang masukannya: hasilnya wajib sama.
      final a = buat(id: 'x', stepOrder: 2, title: 'Anu');
      final b = buat(id: 'y', stepOrder: 2, title: 'Beta');

      final maju = [a, b]..sort(Tutorial.urutkan);
      final mundur = [b, a]..sort(Tutorial.urutkan);

      expect(maju.map((e) => e.id).toList(), ['x', 'y']);
      expect(mundur.map((e) => e.id).toList(), ['x', 'y'],
          reason: 'urutannya wajib sama berapa pun urutan masukannya');
    });

    test('pemutus serinya tidak peduli huruf besar-kecil', () {
      final a = buat(id: 'x', stepOrder: 1, title: 'apel');
      final b = buat(id: 'y', stepOrder: 1, title: 'Bebek');
      expect(([b, a]..sort(Tutorial.urutkan)).map((e) => e.id).toList(),
          ['x', 'y']);
    });
  });
}
