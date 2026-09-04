import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_constants.dart';
import '../config/tier_config.dart';
import '../models/payment_methods.dart';
import '../models/platform_contact.dart';
import '../models/promo.dart';
import '../models/tutorial.dart';
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
  static const String _keyBannerLanding = 'banner_landing';
  static const String _keyBannerPayment = 'banner_payment';

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
  /// Menyimpan seluruh paket sekaligus.
  ///
  /// 🔴 Menerima DAFTAR, bukan satu parameter bernama per paket. Bentuk lama
  /// (`{standar, pro}`) menuntut berkas ini disunting setiap kali ada paket
  /// baru — dan paket yang lupa disebut di sini akan hilang dari
  /// `platform_settings.pricing` saat Admin menekan Simpan, tanpa satu pun
  /// galat, karena baris itu ditulis ulang seluruhnya.
  Future<Result<void>> savePricing({required List<TierConfig> tiers}) =>
      _save(_keyPricing, {for (final t in tiers) t.plan.wire: t.toJson()});

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

  // -------------------------------------------------------------------------
  // 11.5 Gambar iklan
  // -------------------------------------------------------------------------

  /// Spanduk landing page: `{image_url, headline, subheadline}`.
  Future<Result<Map<String, dynamic>>> fetchLandingBanner() =>
      _fetch(_keyBannerLanding);

  Future<Result<void>> saveLandingBanner(Map<String, dynamic> value) =>
      _save(_keyBannerLanding, value);

  /// Gambar kartu paket: `{standar_image_url, pro_image_url,
  /// bisnis_image_url}`.
  ///
  /// ⚠️ Kunci `bisnis_image_url` baru ditambahkan migrasi 39. Basis data yang
  /// belum menjalankannya tidak akan punya kunci itu — dan itu bukan galat,
  /// hanya berarti kartu Bisnis memakai ilustrasi bawaan.
  Future<Result<Map<String, dynamic>>> fetchPaymentBanners() =>
      _fetch(_keyBannerPayment);

  Future<Result<void>> savePaymentBanners(Map<String, dynamic> value) =>
      _save(_keyBannerPayment, value);

  /// Mengunggah satu gambar iklan dan mengembalikan alamat publiknya
  /// (Bab 11.5, bucket dibuat migrasi 46).
  ///
  /// 🔴 Nama berkasnya **tetap**, ditentukan pemanggil lewat [nama], dan
  /// gambar lama ditimpa. Itu keputusan yang sama seperti foto profil
  /// (`uploadAvatar`): tanpa nama tetap, setiap penggantian meninggalkan
  /// berkas lama yang tidak pernah dibaca siapa pun lagi — dan tidak ada satu
  /// pun layar yang dapat menemukannya untuk dihapus.
  ///
  /// ⚠️ Konsekuensinya alamatnya tidak berubah, sehingga gambar lama dapat
  /// bertahan di cache peramban. Karena itu penanda waktu ditempelkan sebagai
  /// query — sama seperti foto profil. Tanpa itu Admin mengganti gambar,
  /// melihat gambar lama, lalu mengunggah lagi berkali-kali.
  ///
  /// 🔴 Yang menegakkan "hanya admin" adalah policy `public_assets_write_admin`
  /// di server, bukan layar ini. Bucket-nya publik untuk dibaca, jadi
  /// penjagaan tulisnya satu-satunya yang memisahkan gambar iklan resmi dari
  /// gambar apa pun yang dititipkan orang.
  Future<Result<String>> uploadPublicAsset({
    required String nama,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    try {
      await _client.storage.from(AppConstants.bucketPublicAssets).uploadBinary(
            nama,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      final url = _client.storage
          .from(AppConstants.bucketPublicAssets)
          .getPublicUrl(nama);
      return Result.ok('$url?v=${DateTime.now().millisecondsSinceEpoch}');
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Membuang satu berkas dari bucket `public-assets`.
  ///
  /// ⚠️ Menerima **nama berkas**, bukan alamat publiknya. Alamat yang tersimpan
  /// di `platform_settings` berakhiran `?v=<cap waktu>` penangkal singgahan;
  /// menyerahkannya apa adanya ke Storage berarti menghapus berkas bernama
  /// `landing.jpg?v=1757...` yang tidak pernah ada, dan gagalnya diam.
  ///
  /// ⚠️ Menghapus berkas yang sudah tidak ada **bukan galat** bagi Supabase
  /// Storage. Itu justru sifat yang diinginkan di sini: Admin yang mencoba
  /// menghapus dua kali tidak boleh disuguhi pesan merah.
  Future<Result<void>> deletePublicAsset(String nama) async {
    try {
      await _client.storage
          .from(AppConstants.bucketPublicAssets)
          .remove([nama]);
      return const Result.ok(null);
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  // -------------------------------------------------------------------------
  // 9.9 Tutorial
  // -------------------------------------------------------------------------

  /// Seluruh langkah tutorial, **termasuk yang nonaktif**.
  ///
  /// 🔴 Berbeda dari `TutorialRepository.fetchActive()` yang dipakai pelanggan,
  /// dan perbedaannya bukan pilihan gaya. Policy `tutorials_read` memakai
  /// `using (is_active)`, sehingga langkah nonaktif **tidak terlihat sama
  /// sekali** lewat jalur itu — Admin yang menonaktifkan sebuah langkah akan
  /// melihatnya lenyap dan tidak punya cara mengaktifkannya kembali.
  ///
  /// Yang membuat kueri ini melihat semuanya adalah policy kedua,
  /// `tutorials_admin` (`for all using (is_admin())`); policy PostgreSQL
  /// digabung dengan OR, jadi Admin lolos lewat policy itu tanpa peduli
  /// `is_active`.
  Future<Result<List<Tutorial>>> fetchTutorials() async {
    try {
      final rows =
          await _client.from(AppConstants.tblTutorials).select();

      final daftar = rows.map((r) => Tutorial.fromJson(r)).toList()
        ..sort(Tutorial.urutkan);
      return Result.ok(List.unmodifiable(daftar));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Membuat atau memperbarui satu langkah tutorial.
  ///
  /// ⚠️ `id` kosong berarti **langkah baru**: kuncinya dibiarkan dibuat server
  /// lewat `default gen_random_uuid()`. Mengirim string kosong sebagai `id`
  /// akan ditolak PostgreSQL sebagai uuid tidak sah — galat yang benar, tetapi
  /// dengan pesan yang tidak menolong siapa pun.
  ///
  /// `created_at` tidak pernah ikut dikirim; ia milik server.
  Future<Result<void>> upsertTutorial(Tutorial tutorial) async {
    try {
      final baris = <String, dynamic>{
        if (tutorial.id.isNotEmpty) 'id': tutorial.id,
        'step_order': tutorial.stepOrder,
        'title': tutorial.title,
        'description': tutorial.description,
        'youtube_url': tutorial.youtubeUrl,
        'platform': tutorial.platform,
        'is_active': tutorial.isActive,
      };

      if (tutorial.id.isEmpty) {
        await _client.from(AppConstants.tblTutorials).insert(baris);
      } else {
        await _client.from(AppConstants.tblTutorials).upsert(baris);
      }
      return okVoid;
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Menghapus satu langkah tutorial secara permanen.
  ///
  /// ⚠️ Tidak seperti promo, menghapus tutorial tidak membuang keterangan apa
  /// pun tentang peristiwa yang sudah lewat — tidak ada tabel lain yang
  /// menyimpan rujukan ke `tutorials.id`. Meski begitu layar tetap menawarkan
  /// **menonaktifkan** lebih dulu: langkah yang videonya sedang direkam ulang
  /// biasanya ingin kembali dengan nomor dan judul yang sama.
  Future<Result<void>> deleteTutorial(String id) async {
    try {
      await _client.from(AppConstants.tblTutorials).delete().eq('id', id);
      return okVoid;
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }
}
