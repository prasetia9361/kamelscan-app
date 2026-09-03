import 'package:freezed_annotation/freezed_annotation.dart';

part 'tutorial.freezed.dart';
part 'tutorial.g.dart';

/// Satu langkah tutorial (Bab 9.9). Cerminan tabel `public.tutorials`.
///
/// Tabelnya sudah ada sejak migrasi 10, tetapi tidak pernah ada satu pun kode
/// yang membacanya sampai 3 September 2026 — halaman Tutorial di HP maupun web
/// selama itu mendarat di halaman kosong, dan itu keadaan yang memang diterima
/// Product Owner sambil menunggu channel YouTube-nya siap.
///
/// 🔴 Isinya dikelola Admin, bukan ditulis mati di kode (Bab 0.2 poin 14).
/// Menambah tutorial karena itu tidak menuntut rilis aplikasi baru — dan itu
/// justru alasan tabel ini ada sejak awal.
@freezed
abstract class Tutorial with _$Tutorial {
  const factory Tutorial({
    required String id,

    /// Urutan tampil. Bukan primary key dan **tidak dijamin unik** — dua
    /// langkah bernomor sama tidak melanggar apa pun di database, jadi
    /// pengurutannya di aplikasi wajib punya pemutus seri (lihat [urutkan]).
    required int stepOrder,
    required String title,
    required String youtubeUrl,
    String? description,

    /// `all` | `mobile` | `web`. Teks bebas di database, bukan enum, jadi
    /// nilai di luar ketiganya mungkin saja ada — [berlakuDi] memperlakukannya
    /// sebagai "tidak berlaku di mana pun" alih-alih melempar.
    @Default('all') String platform,
    @Default(true) bool isActive,
    DateTime? createdAt,
  }) = _Tutorial;

  const Tutorial._();

  factory Tutorial.fromJson(Map<String, dynamic> json) =>
      _$TutorialFromJson(json);

  /// Kode video YouTube dari [youtubeUrl], atau null bila tautannya tidak
  /// dikenali.
  ///
  /// Tiga bentuk yang ditemui pada tautan yang disalin orang dari peramban
  /// maupun dari tombol Bagikan YouTube:
  ///
  ///   - `https://www.youtube.com/watch?v=ABC123`
  ///   - `https://youtu.be/ABC123`
  ///   - `https://www.youtube.com/embed/ABC123`
  ///
  /// ⚠️ Dipakai **hanya untuk memeriksa kewajaran tautan di formulir Admin**,
  /// bukan untuk menyusun ulang alamatnya. Yang dibuka `url_launcher` selalu
  /// [youtubeUrl] apa adanya — menyusun ulang alamat dari kodenya akan
  /// membuang parameter yang sengaja dipasang Admin, misalnya `?t=90` untuk
  /// melompat ke menit tertentu.
  String? get youtubeId {
    final u = Uri.tryParse(youtubeUrl.trim());
    if (u == null) return null;

    final host = u.host.toLowerCase().replaceFirst('www.', '');

    if (host == 'youtu.be') {
      final id = u.pathSegments.isEmpty ? '' : u.pathSegments.first;
      return _idSah(id) ? id : null;
    }

    if (host == 'youtube.com' || host == 'm.youtube.com') {
      final v = u.queryParameters['v'];
      if (v != null && _idSah(v)) return v;

      // `/embed/ABC123` dan `/shorts/ABC123`.
      if (u.pathSegments.length >= 2) {
        final awalan = u.pathSegments.first;
        if (awalan == 'embed' || awalan == 'shorts') {
          final id = u.pathSegments[1];
          return _idSah(id) ? id : null;
        }
      }
    }

    return null;
  }

  /// Tautannya terbaca sebagai video YouTube.
  ///
  /// Dipakai formulir Admin untuk menolak salah tempel **sebelum** disimpan.
  /// Tanpa ini kekeliruannya baru ketahuan oleh packer di gudang, yang
  /// mengetuk sebuah langkah lalu tidak terjadi apa-apa.
  bool get isYoutubeUrlValid => youtubeId != null;

  /// Langkah ini ditampilkan pada rangka yang sedang berjalan.
  ///
  /// ⚠️ Nilai [platform] yang tidak dikenal menjawab `false`, bukan `true`.
  /// Salah ketik di formulir Admin lebih baik membuat satu langkah tidak
  /// muncul di mana pun — kekeliruan yang segera terlihat Admin sendiri —
  /// daripada muncul di kedua rangka sebagai langkah yang tidak relevan.
  bool berlakuDi({required bool isWeb}) => switch (platform) {
        'all' => true,
        'web' => isWeb,
        'mobile' => !isWeb,
        _ => false,
      };

  static bool _idSah(String id) =>
      id.isNotEmpty && RegExp(r'^[A-Za-z0-9_-]{6,20}$').hasMatch(id);

  /// Urutan tampil resmi: [stepOrder] menaik, lalu judul.
  ///
  /// 🔴 Pemutus serinya bukan hiasan. `step_order` tidak unik di database, dan
  /// dua langkah bernomor sama akan bertukar tempat setiap kali daftarnya
  /// dimuat ulang bila urutannya hanya bergantung pada nomor itu — daftar
  /// bernomor yang isinya berpindah-pindah persis yang paling membingungkan
  /// pada layar yang gunanya mengajari orang.
  static int urutkan(Tutorial a, Tutorial b) {
    final n = a.stepOrder.compareTo(b.stepOrder);
    return n != 0 ? n : a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }
}
