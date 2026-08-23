import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_constants.dart';
import '../models/enums.dart';
import '../models/payment_methods.dart';
import '../models/promo.dart';
import '../models/subscription.dart';
import '../services/supabase_service.dart';
import '../utils/app_failure.dart';
import '../utils/result.dart';

/// Sumber kebenaran data pembayaran & langganan (Bab 9.8 / Bab 12).
class SubscriptionRepository {
  const SubscriptionRepository(this._client);

  final SupabaseClient _client;

  /// Upaya pembayaran terakhir milik tenant aktif, atau null bila belum pernah
  /// ada.
  ///
  /// Hanya satu baris terakhir yang diambil: halaman Pembayaran menjawab satu
  /// pertanyaan — *"tagihan saya sekarang bagaimana?"* — bukan menampilkan
  /// riwayat. Riwayat pembayaran adalah layar tersendiri di panel Admin.
  Future<Result<Subscription?>> fetchLatest() async {
    try {
      final row = await _client
          .from(AppConstants.tblSubscriptions)
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return Result.ok(row == null ? null : Subscription.fromJson(row));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Membuat tagihan berstatus `pending` (Bab 12.2 langkah 2).
  ///
  /// 🔴 `status` sengaja tidak dikirim. Policy `sub_insert_owner` mensyaratkan
  /// `status = 'pending'`, dan nilai bawaan kolomnya memang itu — mengirimnya
  /// dari aplikasi hanya menambah satu tempat lagi yang dapat meleset dari
  /// aturan servernya.
  ///
  /// ⚠️ [amount] adalah nominal yang **benar-benar ditransfer**, sudah termasuk
  /// tiga digit pembeda. Tanpa digit itu, sepuluh pelanggan paket Standar pada
  /// hari yang sama mengirim angka yang sama persis dan Admin tidak punya cara
  /// mencocokkan uang siapa yang mana.
  Future<Result<Subscription>> createPending({
    required String tenantId,
    required TierPlan plan,
    required num amount,
    num discountAmount = 0,
    String? promoCode,
  }) async {
    try {
      final row = await _client
          .from(AppConstants.tblSubscriptions)
          .insert({
            'tenant_id': tenantId,
            'plan': plan.wire,
            'amount': amount,
            'discount_amount': discountAmount,
            'promo_code': ?promoCode,
            'payment_method': 'manual_transfer',
          })
          .select()
          .single();

      return Result.ok(Subscription.fromJson(row));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Mengunggah bukti transfer dan menempelkannya ke tagihan (langkah 4).
  ///
  /// Jalurnya `{tenantId}/{subscriptionId}.jpg` — folder teratas adalah tenant
  /// pemiliknya, dan itulah yang diperiksa policy `proofs_insert_own_tenant`
  /// (migrasi `25_payment_proofs.sql`).
  ///
  /// Yang disimpan di `proof_url` adalah **jalur berkasnya**, bukan URL siap
  /// pakai. Buckettnya privat, jadi URL yang benar hanya ada sesaat dan harus
  /// diterbitkan ulang tiap kali dibuka; menyimpan tautan bertanda tangan di
  /// kolom database hanya menghasilkan tautan mati beberapa menit kemudian.
  Future<Result<String>> uploadProof({
    required String tenantId,
    required String subscriptionId,
    required Uint8List bytes,
  }) async {
    try {
      final key = '$tenantId/$subscriptionId.jpg';

      await _client.storage.from(AppConstants.bucketPaymentProofs).uploadBinary(
            key,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      await _client
          .from(AppConstants.tblSubscriptions)
          .update({'proof_url': key})
          .eq('id', subscriptionId);

      return Result.ok(key);
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// URL bertanda tangan untuk menengok bukti yang sudah diunggah.
  ///
  /// Berumur pendek dengan sengaja: bukti transfer memuat mutasi rekening, dan
  /// tautan yang hidup lama akan bertahan di riwayat browser serta log.
  Future<Result<String>> signedProofUrl(String path) async {
    try {
      final url = await _client.storage
          .from(AppConstants.bucketPaymentProofs)
          .createSignedUrl(path, 300);
      return Result.ok(url);
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Mencari kode promo. Null bila kodenya tidak ada.
  ///
  /// Policy `promos_read` hanya membuka baris `is_active`, jadi kode yang
  /// dimatikan Admin memang tidak akan ditemukan di sini — dan itu tampak sama
  /// dengan kode yang salah ketik. Perbedaan itu tidak perlu dijelaskan ke
  /// Owner; keduanya sama-sama tidak dapat dipakai.
  Future<Result<Promo?>> findPromo(String code) async {
    try {
      final row = await _client
          .from(AppConstants.tblPromos)
          .select()
          .eq('code', code.trim().toUpperCase())
          .maybeSingle();

      return Result.ok(row == null ? null : Promo.fromJson(row));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Metode pembayaran yang sedang dinyalakan Admin (Bab 12.1).
  Future<Result<PaymentMethods>> fetchPaymentMethods() async {
    try {
      final row = await _client
          .from(AppConstants.tblPlatformSettings)
          .select('value')
          .eq('key', 'payment_methods')
          .maybeSingle();

      final value = row?['value'];
      if (value is! Map) return const Result.ok(PaymentMethods.fallback);

      return Result.ok(PaymentMethods.fromJson(Map<String, dynamic>.from(value)));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Gambar kartu paket, agar desainer dapat menggantinya tanpa rilis aplikasi
  /// (Bab 9.8). Kosong berarti kartu memakai ilustrasi bawaan.
  Future<Result<Map<String, String>>> fetchPlanBanners() async {
    try {
      final row = await _client
          .from(AppConstants.tblPlatformSettings)
          .select('value')
          .eq('key', 'banner_payment')
          .maybeSingle();

      final value = row?['value'];
      if (value is! Map) return const Result.ok(<String, String>{});

      return Result.ok({
        for (final e in value.entries)
          if (e.value is String && (e.value as String).isNotEmpty)
            e.key.toString(): e.value as String,
      });
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Nomor WhatsApp bantuan, untuk Owner yang tersangkut saat membayar.
  Future<Result<String?>> fetchSupportWhatsapp() async {
    try {
      final row = await _client
          .from(AppConstants.tblPlatformSettings)
          .select('value')
          .eq('key', 'contact')
          .maybeSingle();

      final value = row?['value'];
      if (value is! Map) return const Result.ok(null);

      final nomor = value['whatsapp'];
      return Result.ok(nomor is String && nomor.isNotEmpty ? nomor : null);
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }
}

/// Kegagalan khusus halaman Pembayaran.
extension PaymentFailures on AppFailure {
  /// Trigger `guard_subscription_owner_update` menolak perubahan kolom selain
  /// `proof_url` (migrasi 25). Tidak seharusnya pernah terjadi lewat aplikasi;
  /// bila muncul, ada yang memanggil API di luar jalur yang dimaksudkan.
  bool get isSubscriptionFieldLocked =>
      debugMessage?.contains('SUBSCRIPTION_FIELD_LOCKED') ?? false;
}
