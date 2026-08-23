import 'package:http/http.dart' as http;

/// Klien HTTP dengan batas waktu untuk **seluruh** permintaan ke Supabase.
///
/// 🔴 Ditambahkan 19 Agustus 2026 setelah aplikasi berputar tanpa henti di
/// layar splash saat perangkat dalam mode pesawat.
///
/// Klien HTTP bawaan Dart tidak punya batas waktu sama sekali. Pada jaringan
/// yang **diam** — bukan menolak sambungan, melainkan tidak menjawab — sebuah
/// permintaan dapat menggantung selamanya. Batas waktu yang dipasang di layar
/// tidak menyelesaikannya: layarnya memang berhenti menunggu, tetapi
/// permintaannya sendiri tetap hidup, dan percobaan berikutnya menunggu dari
/// nol lagi. Terbaca di logcat sebagai putaran 20 detik yang tidak pernah
/// berakhir:
///
/// ```
/// 09:27:54  mulai · isSignedIn=true
/// 09:28:14  sesi TIMEOUT setelah 20 dtk
/// 09:28:14  mulai · isSignedIn=true      ← mengulang
/// 09:28:34  sesi TIMEOUT setelah 20 dtk
/// ```
///
/// Batasnya harus berdiri di sini, di permintaannya sendiri.
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient({http.Client? inner, this.timeout = defaultTimeout})
      : _inner = inner ?? http.Client();

  final http.Client _inner;
  final Duration timeout;

  /// 15 detik.
  ///
  /// Dipilih agar **lebih pendek** daripada batas waktu di layar splash
  /// (20 detik). Bila urutannya terbalik, layar akan menyerah lebih dulu
  /// sementara permintaannya masih berjalan — dan putaran tak berujung itu
  /// kembali lagi.
  ///
  /// Cukup longgar untuk Edge Function yang baru bangun (*cold start*) di
  /// wilayah ap-southeast-1, dan cukup pendek untuk tidak terasa seperti
  /// aplikasi yang menggantung.
  ///
  /// ⚠️ Tidak berlaku untuk unggahan video: berkasnya dikirim langsung ke
  /// Cloudflare R2 lewat `dio`, bukan lewat klien ini. Batas waktunya sendiri
  /// ada di `AppConstants.uploadChunkTimeout` (5 menit) — video 1 MB pada
  /// jaringan gudang memang wajar memakan waktu lebih lama daripada
  /// permintaan metadata.
  static const Duration defaultTimeout = Duration(seconds: 15);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request).timeout(timeout);

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
