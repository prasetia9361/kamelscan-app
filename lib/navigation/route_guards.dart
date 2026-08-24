import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/enums.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/session_provider.dart';
import 'route_names.dart';

/// Redirect berdasarkan sesi & role (Bab 3.2).
///
/// ⚠️ Bab 2.3 — ini **lapisan kenyamanan, bukan keamanan**. Penegakan
/// sesungguhnya ada di RLS Supabase. Setiap policy harus tetap aman dengan
/// asumsi penyerang memanggil API langsung tanpa lewat aplikasi.
class RouteGuards {
  const RouteGuards(this._ref);

  final Ref _ref;

  String? redirect(String location) {
    final signedIn = _ref.read(isSignedInProvider);

    // Splash memutuskan tujuannya sendiri setelah sesi selesai dipulihkan.
    if (location == Routes.splash) return null;

    if (!signedIn) {
      if (!Routes.isPublic(location)) {
        // 🔴 Jejak diagnosis — jangan dihapus tanpa penggantinya.
        //
        // Inilah satu-satunya tempat pengguna dilempar ke halaman masuk. Saat
        // aplikasi dalam mode pesawat membuka login padahal sesinya masih
        // tersimpan (19 Agustus 2026), baris ini yang membuktikan apakah
        // pengalihannya datang dari sini atau dari layar splash.
        //
        // Dicetak hanya saat benar-benar mengalihkan — `redirect` dipanggil
        // pada setiap perpindahan rute, dan mencetak semuanya akan menenggelamkan
        // jejak lain.
        debugPrint('KAMELSCAN_GUARD → login · dari=$location');
        return Routes.login;
      }
      return null;
    }

    // Bab 6.8 — pemulihan password mendahului segalanya.
    //
    // Tautan dari email menghasilkan sesi yang sah, jadi tanpa penjagaan ini
    // pengguna langsung mendarat di Beranda dalam keadaan "masuk" — password
    // lamanya masih berlaku dan ia tidak pernah diminta membuat yang baru.
    // Yang ia minta justru itu.
    //
    // Diletakkan sebelum aturan halaman publik karena tautannya biasa tiba
    // ketika pengguna masih berdiri di layar Masuk atau Lupa Password; aturan
    // di bawah akan melemparnya ke layar pembuka lebih dulu.
    if (_ref.read(passwordResetPendingProvider)) {
      if (location != Routes.resetPassword) {
        debugPrint('KAMELSCAN_RESET → layar password baru · dari=$location');
        return Routes.resetPassword;
      }
      return null;
    }

    // Pemulihan sudah selesai atau dibatalkan — layar itu tidak punya isi lagi.
    if (location == Routes.resetPassword) {
      return _homeFor(_ref.read(currentRoleProvider));
    }

    // Sudah login tetapi membuka halaman auth — lempar ke beranda.
    //
    // 🔴 …kecuali bila perannya BELUM diketahui. Saat itu tujuannya layar
    // pembuka, bukan Beranda.
    //
    // Sesaat setelah tombol Masuk ditekan, `isSignedIn` sudah true sementara
    // `sessionProvider` baru mulai memuat profil, tenant, katalog tier, dan
    // dompet. Mengirim pengguna ke Beranda pada detik itu berarti membangun
    // layar yang seluruh isinya bergantung pada sesi yang belum ada.
    //
    // Terbukti di perangkat Product Owner 22 Agustus 2026, empat siklus
    // logout–login berturut-turut lewat kabel:
    //
    //     SHELL cabang=0 tab=0 role=null
    //     HOME  vm mulai · sesi=AsyncLoading role=null   ← dibangun terlalu dini
    //     HOME  bangun · AsyncLoading error=true         ← gagal, lalu mengulang
    //     SPLASH mulai · isSignedIn=true                 ← splash baru jalan di sini
    //     SPLASH sesi siap · role=packer
    //     HOME  vm keadaan → AsyncData punyaNilai=true   ← datanya akhirnya jadi…
    //     HOME  vm dibuang                               ← …ke ViewModel yang sudah
    //                                                      tidak ada penontonnya
    //
    // Baris terakhir itu yang terlihat sebagai Beranda kosong: halaman yang
    // terlanjur dibangun sudah dibuang ketika rutenya digantikan, dan hasil
    // kerjanya tidak pernah sampai ke layar. Tiga dari empat siklus berakhir
    // begitu; yang satu lolos hanya karena datanya kebetulan tiba sebelum
    // pembuangan. Itu sebabnya cacat ini kadang muncul kadang tidak.
    //
    // Owner nyaris tidak pernah terkena bukan karena ia kebal, melainkan karena
    // urutan waktunya kebetulan berbeda.
    //
    // Layar pembuka memang dibuat untuk keadaan ini: ia menunggu sesi dengan
    // batas waktu, punya tampilan memuat, dan punya tombol *Coba lagi* bila
    // gagal (M.13). Mengembalikan penantian itu kepadanya membuat jalur sesudah
    // login sama persis dengan jalur membuka aplikasi dari mati — jalur yang
    // pada pengujian yang sama terbukti sehat tiga dari tiga kali.
    if (Routes.isPublic(location) && location != Routes.splash) {
      final peran = _ref.read(currentRoleProvider);
      if (peran == null) {
        debugPrint('KAMELSCAN_GUARD → splash · sesi belum siap · dari=$location');
        return Routes.splash;
      }
      return _homeFor(peran);
    }

    // Bab 6.7 — packer yang masih memakai password sementara tidak boleh
    // masuk ke layar mana pun sebelum menggantinya. Password itu sudah dilihat
    // Owner, jadi selama belum diganti akunnya bukan miliknya sendiri.
    if (_ref.read(mustChangePasswordProvider) &&
        location != Routes.changePassword) {
      return Routes.changePassword;
    }

    // Bab 6.2 — nomor HP dan persetujuan S&K ditandai WAJIB, tetapi
    // pendaftaran lewat Google melewati formulir dan tidak pernah menanyakan
    // keduanya. Tanpa penjagaan ini, seseorang memperoleh tenant dan 100 video
    // gratis tanpa nomor kontak dan tanpa pernah menyetujui apa pun —
    // kelalaian yang berbalik menyerang justru saat ada sengketa.
    if (_ref.read(needsProfileCompletionProvider) &&
        location != Routes.completeProfile) {
      return Routes.completeProfile;
    }

    // Sudah lengkap tetapi membuka layarnya lagi — tidak ada yang perlu diisi.
    if (location == Routes.completeProfile &&
        !_ref.read(needsProfileCompletionProvider)) {
      return _homeFor(_ref.read(currentRoleProvider));
    }

    final role = _ref.read(currentRoleProvider);
    if (role == null) return null; // konteks sesi masih dimuat

    // Bab 10.1 — rute perekaman tidak boleh sekadar disembunyikan di web,
    // rutenya memang tidak terdaftar. Guard ini menangkap deep link manual.
    if (kIsWeb && _isRecordingRoute(location)) {
      return _homeFor(role);
    }

    // Bab 2.2 catatan 2 — Admin tidak punya toko, jalur rekam tidak dibuat.
    if (role == UserRole.admin && _isRecordingRoute(location)) {
      return Routes.adminDashboard;
    }

    // Packer tidak punya menu Toko, Pembayaran, maupun kelola packer.
    if (role == UserRole.packer && _isOwnerOnly(location)) {
      return Routes.home;
    }

    if (role != UserRole.admin && location.startsWith(Routes.adminDashboard)) {
      return _homeFor(role);
    }

    return null;
  }

  static String _homeFor(UserRole? role) => switch (role) {
        UserRole.admin => Routes.adminDashboard,
        _ => kIsWeb ? Routes.webDashboard : Routes.home,
      };

  static bool _isRecordingRoute(String location) =>
      location.startsWith(Routes.recordSetup);

  static bool _isOwnerOnly(String location) =>
      location.startsWith(Routes.shops) ||
      location.startsWith(Routes.payment) ||
      location.startsWith(Routes.packers) ||
      location.startsWith(Routes.watermark);
}

/// Jembatan agar GoRouter ikut menghitung ulang `redirect` saat status login
/// berubah. Tanpa ini, pengguna yang sesinya kedaluwarsa tetap melihat layar
/// terlindungi sampai ia menekan sesuatu.
/// 🔴 **Aturannya satu kalimat: apa pun yang dibaca `redirect` di atas WAJIB
/// ikut disimak di sini.**
///
/// GoRouter tidak mengintip provider. Ia hanya menghitung ulang tujuan ketika
/// sesuatu memberitahunya, dan satu-satunya yang memberitahu adalah kelas ini.
/// Setiap nilai yang dibaca guard tetapi tidak disimak di sini menghasilkan
/// cacat berbentuk sama: **layar yang seharusnya berpindah, diam di tempat.**
///
/// Terbukti di perangkat Product Owner 24 Agustus 2026, pada pendaftaran lewat
/// Google. `needsProfileCompletion` dibaca guard tetapi tidak disimak di sini:
///
///     KAMELSCAN_PROFIL bangun · butuhHp=true butuhSetuju=true   <- kolom tampil
///     (nomor HP diisi, centang ditekan, Simpan ditekan)
///     KAMELSCAN_PROFIL simpan BERHASIL · butuhLengkap=false     <- data tersimpan
///     (…tidak terjadi apa-apa)
///
/// Datanya benar-benar tersimpan — `phone` dan `terms_accepted_at` terisi di
/// `public.users`. Yang tidak terjadi hanyalah pemberitahuan: status login
/// tidak berubah, peran tetap `owner`, jadi tidak ada satu pun pemicu yang
/// menghitung ulang tujuan. Layar Lengkapi Profil pun bertahan — kini tanpa
/// kolom apa pun, karena semuanya sudah terisi — dengan tombol kembali yang
/// sengaja dimatikan. Aplikasi harus ditutup paksa.
///
/// Product Owner menekan Simpan berulang kali tanpa reaksi; jejaknya tertinggal
/// di basis data sebagai `terms_accepted_at` yang tertulis ulang beberapa
/// menit sesudah akunnya dibuat.
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(this._ref) {
    _ref.listen(isSignedInProvider, (_, _) => notifyListeners());
    _ref.listen(currentRoleProvider, (_, _) => notifyListeners());

    // Bab 6.7 — packer selesai mengganti password sementara.
    _ref.listen(mustChangePasswordProvider, (_, _) => notifyListeners());

    // Bab 6.2 — profil selesai dilengkapi. Inilah yang hilang sampai
    // 24 Agustus 2026; uraiannya di atas.
    _ref.listen(needsProfileCompletionProvider, (_, _) => notifyListeners());

    // Bab 6.8 — tautan reset tiba saat aplikasi sedang terbuka. Sesinya
    // berubah tanpa mengubah status login maupun peran.
    _ref.listen(passwordResetPendingProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}
