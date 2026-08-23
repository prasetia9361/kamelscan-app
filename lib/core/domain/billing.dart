import 'dart:math';

import '../models/promo.dart';

/// Rincian tagihan satu upaya pembayaran (Bab 9.8 & 12.2).
///
/// Murni Dart — tanpa Flutter, tanpa jaringan — supaya seluruh aritmetikanya
/// dapat diuji tanpa perangkat. Uang adalah tempat terakhir yang pantas
/// menebak-nebak.
class BillingSummary {
  const BillingSummary({
    required this.subtotal,
    required this.discount,
    required this.uniqueCode,
  });

  /// Harga paket sebelum potongan, dari `platform_settings.pricing`.
  final num subtotal;

  /// Potongan kode promo. 0 bila tidak ada.
  final num discount;

  /// Tiga digit pembeda di ujung nominal, 1–999.
  ///
  /// 🔴 Inilah yang membuat transfer manual dapat dicocokkan sama sekali.
  /// Sepuluh pelanggan yang membeli paket Standar pada hari yang sama semuanya
  /// mengirim Rp 99.000, dan mutasi rekening tidak memuat nama tenant — Admin
  /// tidak punya cara memastikan uang siapa yang mana. Dengan tiga digit ini
  /// tiap tagihan menjadi angka yang berbeda: Rp 99.317, Rp 99.482, dan
  /// seterusnya.
  ///
  /// **Ditambahkan, bukan menggantikan digit terakhir.** Menggantikan dapat
  /// menghasilkan nominal yang lebih kecil daripada yang seharusnya dibayar
  /// (99.500 → 99.317), dan selisihnya baru ketahuan saat rekonsiliasi.
  final int uniqueCode;

  /// Yang harus benar-benar ditransfer.
  num get amountToTransfer => total + uniqueCode;

  /// Tagihan setelah potongan, sebelum digit pembeda.
  num get total {
    final sisa = subtotal - discount;
    return sisa < 0 ? 0 : sisa;
  }

  bool get hasDiscount => discount > 0;

  /// Menyusun rincian dari harga paket dan promo yang sudah lolos pemeriksaan.
  ///
  /// [random] dapat diisi pada pengujian agar digit pembedanya dapat diramal;
  /// di aplikasi ia dibiarkan kosong.
  factory BillingSummary.of({
    required num price,
    Promo? promo,
    Random? random,
  }) {
    final r = random ?? Random.secure();
    return BillingSummary(
      subtotal: price,
      discount: promo?.discountFor(price) ?? 0,
      // 1–999. Nol sengaja dikeluarkan: nominal tanpa digit pembeda persis
      // sama dengan harga daftar, yaitu keadaan yang justru ingin dihindari.
      uniqueCode: r.nextInt(999) + 1,
    );
  }
}
