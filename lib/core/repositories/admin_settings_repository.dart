import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_constants.dart';
import '../config/tier_config.dart';
import '../models/payment_methods.dart';
import '../models/platform_contact.dart';
import '../models/promo.dart';
import '../services/supabase_service.dart';
import '../utils/result.dart';

/// Pengaturan platform yang dapat diubah Admin (Bab 11.3–11.6).
///
/// 🔴 Sampai 29 Agustus 2026 seluruh isi berkas ini dikerjakan lewat **Supabase
/// Dashboard** — antarmuka teknis berbahasa Inggris berupa tabel database.
/// Bab 11 menyebutnya keputusan lingkup MVP dan memperingatkan akibatnya:
/// mengubah harga berarti menyunting JSON dengan tangan, dan satu tanda kutip
/// yang hilang merusak baris yang dibaca setiap perangkat.
///
/// ⚠️ Tidak ada satu pun migrasi yang dibutuhkan repository ini. Izinnya sudah
/// ada sejak migrasi 14: `psettings_write_admin`, `promos_admin`, dan
/// `tutorials_admin` semuanya `for all using (is_admin())`. Yang selama ini
/// kurang hanyalah layarnya.
///
/// 🔴 **Kunci rahasia Midtrans tidak boleh menyentuh berkas ini.** Bab 11.6
/// menuliskannya sebagai larangan: `platform_settings.payment_methods` hanya
/// berisi sakelar aktif/nonaktif. Kuncinya hidup di Edge Function secrets, dan
/// menaruhnya di tabel berarti setiap orang yang dapat membaca pengaturan
/// dapat menagih atas nama Anda.
class AdminSettingsRepository {
  const AdminSettingsRepository(this._client);

  final SupabaseClient _client;

  static const String _keyPricing = 'pricing';
  static const String _keyInfraCost = 'infra_cost';
  static const String _keyPaymentMethods = 'payment_methods';
  static const String _keyContact = 'contact';

  /// Membaca satu baris `platform_settings`.
  ///
  /// Mengembalikan peta kosong bila barisnya tidak ada — bukan galat. Baris
  /// yang belum pernah dibuat adalah keadaan yang wajar pada pengaturan baru,
  /// dan layarnya cukup menampilkan formulir kosong.
  Future<Result<Map<String, dynamic>>> _fetch(String key) async {
    try {
      final row = await _client
          .from(AppConstants.tblPlatformSettings)
          .select('value')
          .eq('key', key)
          .maybeSingle();
      final value = row?['value'];
      return Result.ok(
        value is Map ? value.cast<String, dynamic>() : <String, dynamic>{},
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Menulis satu baris `platform_settings`.
  ///
  /// 🔴 `upsert`, bukan `update`. Baris `infra_cost` baru lahir di migrasi 30
  /// dan baris lain bisa saja belum ada di basis data yang dipasang lebih
  /// awal; `update` pada baris yang tidak ada **berhasil tanpa mengubah apa
  /// pun** dan tidak melempar galat sama sekali — layarnya akan menulis
  /// "tersimpan" untuk perubahan yang tidak pernah terjadi.
  Future<Result<void>> _save(String key, Map<String, dynamic> value) async {
    try {
      await _client.from(AppConstants.tblPlatformSettings).upsert({
        'key': key,
        'value': value,
      }, onConflict: 'key');
      return okVoid;
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  // -------------------------------------------------------------------------
  // 11.3 Harga & paket
  // -------------------------------------------------------------------------

  Future<Result<TierCatalog>> fetchPricing() async {
    final hasil = await _fetch(_keyPricing);
    if (hasil.isErr) return Result.err(hasil.failureOrNull!);
    return Result.ok(TierCatalog.fromPricingJson(hasil.valueOrNull!));
  }

  /// Menyimpan harga dan batas kedua paket.
  ///
  /// ⚠️ Bab 11.3 — **perubahan harga tidak berlaku surut.** Pelanggan yang
  /// periodenya sedang berjalan tetap memakai angka di `subscriptions.amount`
  /// yang sudah tersimpan saat ia membayar. Itu aman selama tidak ada kode
  /// yang menghitung ulang tagihan lama dari sini, dan sampai hari ini tidak
  /// ada.
  ///
  /// 🔴 Yang **berlaku seketika** adalah batas-batasnya: durasi video, hari
  /// retensi, jumlah packer, dan kuota token. Menurunkan `max_packers` di
  /// bawah jumlah packer yang sudah ada tidak menghapus siapa pun, tetapi
  /// membuat pelanggan itu tidak dapat menambah packer lagi sampai ia
  /// menguranginya sendiri — keadaan yang wajib dikatakan layar sebelum
  /// disimpan.
  Future<Result<void>> savePricing({
    required TierConfig standar,
    required TierConfig pro,
  }) => _save(_keyPricing, {'standar': standar.toJson(), 'pro': pro.toJson()});

  /// Biaya infrastruktur bulanan — dipakai kartu Margin di Dasbor Platform.
  ///
  /// `null` berarti belum pernah diisi, dan dasbor menuliskannya sebagai belum
  /// diisi alih-alih menganggapnya nol (migrasi 30 keputusan 3).
  Future<Result<num?>> fetchInfraCost() async {
    final hasil = await _fetch(_keyInfraCost);
    if (hasil.isErr) return Result.err(hasil.failureOrNull!);
    return Result.ok(hasil.valueOrNull!['monthly_idr'] as num?);
  }

  Future<Result<void>> saveInfraCost(num? monthlyIdr) =>
      _save(_keyInfraCost, {'monthly_idr': monthlyIdr});

  // -------------------------------------------------------------------------
  // 11.6 Metode pembayaran
  // -------------------------------------------------------------------------

  Future<Result<PaymentMethods>> fetchPaymentMethods() async {
    final hasil = await _fetch(_keyPaymentMethods);
    if (hasil.isErr) return Result.err(hasil.failureOrNull!);
    final json = hasil.valueOrNull!;
    return Result.ok(
      json.isEmpty ? PaymentMethods.fallback : PaymentMethods.fromJson(json),
    );
  }

  /// 🔴 Yang disimpan hanya sakelar dan daftar rekening. Tidak ada tempat bagi
  /// kunci rahasia Midtrans di sini, dan itu bukan kelalaian — lihat catatan
  /// di kepala kelas ini.
  Future<Result<void>> savePaymentMethods(PaymentMethods methods) =>
      _save(_keyPaymentMethods, methods.toJson());

  // -------------------------------------------------------------------------
  // 11.5 Kontak
  // -------------------------------------------------------------------------

  Future<Result<PlatformContact>> fetchContact() async {
    final hasil = await _fetch(_keyContact);
    if (hasil.isErr) return Result.err(hasil.failureOrNull!);
    return Result.ok(PlatformContact.fromJson(hasil.valueOrNull!));
  }

  Future<Result<void>> saveContact(PlatformContact contact) =>
      _save(_keyContact, contact.toJson());

  // -------------------------------------------------------------------------
  // 11.4 Promo
  // -------------------------------------------------------------------------

  /// Seluruh promo, termasuk yang sudah tidak aktif dan yang sudah kedaluwarsa.
  ///
  /// 🔴 Sengaja **tidak** disaring. Layar pelanggan hanya melihat yang aktif
  /// (policy `promos_read` memakai `using (is_active)`), tetapi Admin justru
  /// datang ke sini untuk menghidupkan kembali yang mati atau memeriksa berapa
  /// kali kode lama terpakai.
  Future<Result<List<Promo>>> fetchPromos() async {
    try {
      final rows = await _client
          .from(AppConstants.tblPromos)
          .select()
          .order('valid_until', ascending: false);
      return Result.ok(
        rows.map((r) => Promo.fromJson(r)).toList(growable: false),
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Membuat atau memperbarui satu promo. `code` adalah kunci utamanya.
  ///
  /// 🔴 `used_count` **tidak pernah ikut ditulis**. Ia dihitung server setiap
  /// kali sebuah kode benar-benar dipakai; mengirimkannya dari layar berarti
  /// setiap penyuntingan promo mengembalikan hitungannya ke angka yang
  /// kebetulan sedang tampil — dan batas pemakaian menjadi tidak berarti.
  Future<Result<void>> upsertPromo(Promo promo) async {
    try {
      await _client.from(AppConstants.tblPromos).upsert({
        'code': promo.code,
        'description': promo.description,
        'discount_type': promo.discountType,
        'discount_value': promo.discountValue,
        'applies_to': promo.appliesTo?.wire,
        if (promo.validFrom != null)
          'valid_from': promo.validFrom!.toUtc().toIso8601String(),
        'valid_until': promo.validUntil.toUtc().toIso8601String(),
        'max_uses': promo.maxUses,
        'is_active': promo.isActive,
      }, onConflict: 'code');
      return okVoid;
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Menghapus promo secara permanen.
  ///
  /// ⚠️ Untuk kode yang **pernah dipakai**, menonaktifkannya jauh lebih baik
  /// daripada menghapusnya: baris `subscriptions` yang lama menyimpan
  /// `promo_code` sebagai teks biasa, jadi menghapus kodenya tidak merusak
  /// apa pun secara teknis — tetapi menghilangkan satu-satunya keterangan
  /// tentang potongan yang pernah diberikan. Layar wajib menawarkan
  /// menonaktifkan lebih dulu.
  Future<Result<void>> deletePromo(String code) async {
    try {
      await _client.from(AppConstants.tblPromos).delete().eq('code', code);
      return okVoid;
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }
}
