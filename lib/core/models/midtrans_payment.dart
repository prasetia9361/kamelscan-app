import 'package:freezed_annotation/freezed_annotation.dart';

part 'midtrans_payment.freezed.dart';
part 'midtrans_payment.g.dart';

/// Tagihan Midtrans yang baru dibuat — balasan Edge Function `create-payment`
/// (Bab 12.3).
///
/// 🔴 Seluruh angka di sini datang dari **server**, bukan dihitung ulang di
/// aplikasi. Bab 12.3 aturan 4: nominal dihitung dari `platform_settings` dan
/// tabel `promos`, dan aplikasi tidak pernah dipercaya menentukannya.
///
/// Perbedaannya dari transfer manual bukan soal kerapian: pada transfer manual
/// Admin melihat bukti transfernya dan mencocokkan angkanya dengan tangan.
/// Pada Midtrans tidak ada yang memeriksa, jadi nominal yang dikirim aplikasi
/// berarti siapa pun yang dapat menyunting permintaan HTTP dapat membeli paket
/// Pro seharga seribu rupiah — dan pembayarannya akan lunas dengan benar
/// sampai ke buku besar.
@freezed
abstract class MidtransPayment with _$MidtransPayment {
  const factory MidtransPayment({
    required String orderId,
    required String subscriptionId,

    /// Halaman pembayaran Snap. Inilah yang dibuka pelanggan.
    ///
    /// ⚠️ Dipakai sebagai **alamat yang dituju**, bukan dimuat di dalam
    /// aplikasi. Bab 12.5 — alur bayar yang berjalan di dalam aplikasi mobile
    /// adalah bentuk yang paling sering ditolak App Store.
    required String redirectUrl,

    /// Snap token. Hanya diperlukan bila suatu hari Snap dipasang sebagai
    /// jendela mengambang lewat `snap.js`; dengan [redirectUrl] ia tidak
    /// dipakai sama sekali, dan sengaja tetap dibawa agar tidak perlu
    /// mengubah Edge Function saat itu dibutuhkan.
    String? token,

    @Default(0) num amount,
    @Default(0) num discount,

    /// `false` berarti tagihan ini dibuat di lingkungan **Sandbox** — uangnya
    /// tidak berpindah.
    ///
    /// 🔴 Wajib ditampilkan di layar. Halaman pembayaran sandbox terlihat
    /// persis seperti aslinya, dan tidak ada yang lebih mahal daripada
    /// menyangka sudah menerima uang yang tidak pernah masuk.
    @Default(false) bool isProduction,
  }) = _MidtransPayment;

  const MidtransPayment._();

  factory MidtransPayment.fromJson(Map<String, dynamic> json) =>
      _$MidtransPaymentFromJson(json);
}
