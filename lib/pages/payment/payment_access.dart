import 'package:flutter/foundation.dart' show kIsWeb;

/// Di mana pelanggan boleh menyelesaikan pembayaran (Bab 12.5).
///
/// 🔴 **Aplikasi mobile sengaja tidak menyelesaikan pembayaran.** Google Play
/// dan Apple App Store mewajibkan pembelian dalam aplikasi (IAP) untuk konten
/// digital, dengan komisi 15–30%. Bab 12.5 menuliskan risikonya apa adanya:
/// melewatkan pertimbangan ini berarti aplikasi **ditolak saat review**, dan
/// kehilangan 1–2 minggu tepat di akhir proyek.
///
/// KamelScan berpeluang masuk pengecualian layanan bisnis, tetapi peluang
/// bukan jaminan — dan yang menanggung akibatnya adalah jadwal rilis. Bentuk
/// yang dipilih Product Owner 30 Agustus 2026 adalah yang paling sedikit
/// menuntut penjelasan kepada Apple: **di HP, paketnya tetap terlihat lengkap
/// dengan harga dan isinya, tetapi tombol bayarnya tidak ada** — diganti
/// arahan ke dasbor web.
///
/// Menyembunyikan harganya sekalian justru salah: pelanggan tetap perlu tahu
/// apa yang ditawarkan, dan halaman yang menyembunyikan harga terbaca sebagai
/// rusak.
///
/// 🔴 **Aturannya berupa fungsi yang MENERIMA `isWeb`, bukan `kIsWeb` yang
/// ditulis di dalam widget.** `kIsWeb` konstanta waktu kompilasi: pada
/// `flutter test` nilainya selalu `false`, sehingga cabang webnya tidak pernah
/// dijalankan sekali pun dan cacat di dalamnya tidak pernah tertangkap. Sudah
/// terjadi di proyek ini — uraiannya di `DEVIASI_LIBRARY.md` **O.14**, dan
/// polanya sama dengan `Env.oauthRedirectFor(isWeb:)`.
class PaymentAccess {
  const PaymentAccess._();

  /// Apakah pembayaran boleh diselesaikan pada platform ini.
  ///
  /// Inilah aturannya, dan satu-satunya bagian yang perlu diuji. Widget cukup
  /// memanggil [canPayHere].
  static bool canPay({required bool isWeb}) => isWeb;

  /// Nilai [canPay] untuk platform yang sedang berjalan.
  ///
  /// Sengaja tipis: ia hanya menyambungkan konstanta waktu kompilasi ke aturan
  /// di atas, sehingga tidak ada logika yang tersembunyi di balik `kIsWeb`.
  static bool get canPayHere => canPay(isWeb: kIsWeb);
}
