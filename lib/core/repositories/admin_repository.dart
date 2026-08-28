import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_constants.dart';
import '../models/enums.dart';
import '../models/pending_payment.dart';
import '../models/tenant.dart';
import '../services/supabase_service.dart';
import '../utils/result.dart';

/// Panel Admin **ringkas** untuk MVP (Bab 0.2).
///
/// Yang masuk MVP hanya dua: verifikasi pembayaran manual dan ubah tier tenant.
/// Pengaturan harga, promo, gambar iklan, dan CRUD tutorial dikelola Admin
/// lewat Supabase Dashboard sampai Fase 2 — jangan membangun UI-nya sekarang.
///
/// 🔴 Bab 2.2 catatan 5 — Admin dapat melihat **metadata** video pelanggan,
/// tetapi tidak dapat memutar, mengunduh, maupun membagikan isinya. Repository
/// ini sengaja tidak memiliki metode pemutaran video.
class AdminRepository {
  const AdminRepository(this._client);

  final SupabaseClient _client;

  Future<Result<List<Tenant>>> fetchTenants({
    TenantStatus? status,
    int limit = 50,
  }) async {
    try {
      var query = _client.from(AppConstants.tblTenants).select();
      if (status != null) query = query.eq('status', status.wire);
      final rows = await query.order('created_at', ascending: false).limit(limit);
      return Result.ok(
        rows.map((r) => Tenant.fromJson(r)).toList(growable: false),
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Pembayaran yang menunggu diverifikasi Admin (Bab 12.2).
  ///
  /// Hanya yang **sudah berbukti**: `proof_url` terisi. Baris `pending` tanpa
  /// bukti adalah orang yang menekan "Pilih Paket" lalu menutup aplikasinya,
  /// dan menampilkannya di sini hanya memenuhi daftar Admin dengan pekerjaan
  /// yang tidak dapat dikerjakan.
  ///
  /// 🔴 Nama usaha ikut diambil lewat embedding. Tanpa itu yang tampil hanya
  /// UUID tenant, dan mencocokkan `0b5ae403-…` dengan mutasi rekening adalah
  /// pekerjaan yang mustahil dilakukan tanpa salah.
  ///
  /// ⚠️ Email pemiliknya sengaja TIDAK ikut. `users` punya dua hubungan ke
  /// `tenants` sekaligus (`users.tenant_id` dan `tenants.owner_id`), dan
  /// PostgREST menolak embedding yang rancu seperti itu tanpa menyebut nama
  /// constraint-nya. Nama usaha sudah cukup untuk mencocokkan dengan mutasi
  /// rekening; email baru dibutuhkan bila Admin hendak menghubungi, dan itu
  /// bukan bagian dari memverifikasi.
  Future<Result<List<PendingPayment>>> fetchPendingPayments() async {
    try {
      final rows = await _client
          .from(AppConstants.tblSubscriptions)
          .select('*, tenants(business_name)')
          .eq('status', SubStatus.pending.wire)
          .not('proof_url', 'is', null)
          .order('created_at', ascending: false);
      return Result.ok(
        rows.map((r) => PendingPayment.fromJson(r)).toList(growable: false),
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Setujui pembayaran manual.
  ///
  /// ⚠️ Penyesuaian tier, periode langganan, dan reset saldo token dilakukan
  /// **trigger di server** setelah status menjadi `paid` (Bab 7.2 poin 4) —
  /// `activate_subscription()`, migrasi `28_activate_subscription.sql`.
  /// Jangan menghitung apa pun dari sini.
  ///
  /// 🔴 Kalimat di atas sudah tertulis di sini sejak awal padahal triggernya
  /// **belum pernah dibuat**, dan tidak ada yang menyadarinya selama
  /// berminggu-minggu: menyetujui pembayaran berhasil tanpa keluhan apa pun,
  /// lalu tidak terjadi apa-apa. Product Owner mentransfer uang sungguhan
  /// 22 Agustus 2026 dan layarnya berhenti di "Menunggu verifikasi" empat
  /// hari. Triggernya baru lahir 26 Agustus 2026.
  ///
  /// ⚠️ Bab 5.3 — JWT pelanggan masih membawa `tier_plan` lama sampai
  /// tokennya disegarkan. Aplikasi pelanggan wajib memanggil `refreshSession()`
  /// (atau keluar lalu masuk lagi) sebelum batas tier baru terasa.
  Future<Result<void>> approvePayment({
    required String subscriptionId,
    required String verifiedBy,
  }) async {
    try {
      await _client
          .from(AppConstants.tblSubscriptions)
          .update({
            'status': SubStatus.paid.wire,
            'verified_by': verifiedBy,
            'paid_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', subscriptionId);
      return okVoid;
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  Future<Result<void>> rejectPayment(String subscriptionId) async {
    try {
      await _client
          .from(AppConstants.tblSubscriptions)
          .update({'status': SubStatus.failed.wire})
          .eq('id', subscriptionId);
      return okVoid;
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Ubah tier tenant secara manual.
  ///
  /// ⚠️ Bab 5.3 — JWT pelanggan masih membawa `tier_plan` lama sampai token
  /// disegarkan. Aplikasi pelanggan harus memanggil `refreshSession()` setelah
  /// perubahan ini agar batas tier baru langsung berlaku.
  Future<Result<void>> changeTier({
    required String tenantId,
    required TierPlan plan,
    DateTime? periodEnd,
  }) async {
    try {
      await _client
          .from(AppConstants.tblTenants)
          .update({
            'tier_plan': plan.wire,
            'status': TenantStatus.active.wire,
            if (periodEnd != null)
              'period_end': periodEnd.toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', tenantId);
      return okVoid;
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  Future<Result<void>> setTenantStatus({
    required String tenantId,
    required TenantStatus status,
  }) async {
    try {
      await _client
          .from(AppConstants.tblTenants)
          .update({'status': status.wire})
          .eq('id', tenantId);
      return okVoid;
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }
}
