import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_constants.dart';
import '../domain/capacity_status.dart';
import '../models/admin_tenant_row.dart';
import '../models/enums.dart';
import '../models/pending_payment.dart';
import '../models/platform_stats.dart';
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

  /// Kapasitas platform (Bab 11.1) — RPC `get_capacity_stats()`,
  /// migrasi `42_capacity_stats.sql`.
  ///
  /// 🔴 Dipisahkan dari [fetchPlatformStats] dengan sengaja. `pg_database_size`
  /// memindai seluruh direktori database, dan menempelkannya ke ringkasan yang
  /// dimuat setiap kali Dasbor Platform dibuka berarti membayar pemindaian itu
  /// untuk angka yang hanya berubah beberapa kilobyte per jam.
  Future<Result<CapacityStats>> fetchCapacityStats() async {
    try {
      final row = await _client.rpc<Map<String, dynamic>>('get_capacity_stats');
      return Result.ok(CapacityStats.fromJson(row));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Angka ringkasan seluruh platform (Bab 11.1) — RPC `get_platform_stats()`,
  /// migrasi `30_platform_stats.sql`.
  ///
  /// 🔴 Satu-satunya panggilan di aplikasi ini yang **melintasi batas antar
  /// pelanggan**. Fungsinya `security definer`, jadi RLS tidak berlaku di
  /// dalamnya; penjagaannya `is_admin()` pada baris pertama fungsi itu.
  ///
  /// Yang bukan admin menerima **galat**, bukan angka nol. Angka nol akan
  /// tampil di layar sebagai "platform ini belum punya pelanggan" — kalimat
  /// yang salah dan terlihat masuk akal.
  Future<Result<PlatformStats>> fetchPlatformStats() async {
    try {
      final json = await _client.rpc<Map<String, dynamic>>(
        'get_platform_stats',
      );
      return Result.ok(PlatformStats.fromJson(json));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Tabel Kelola Pengguna (Bab 11.2) — RPC `admin_list_tenants()`,
  /// migrasi `31_admin_tenants.sql`.
  ///
  /// 🔴 Panggilan **lintas pelanggan** yang kedua di aplikasi ini, setelah
  /// [fetchPlatformStats]. Fungsinya `security definer`, jadi RLS tidak
  /// berlaku di dalamnya; penjagaannya `is_admin()` pada baris pertama fungsi
  /// itu. Yang bukan admin menerima **galat**, bukan daftar kosong — daftar
  /// kosong akan terbaca sebagai "platform ini belum punya pelanggan".
  ///
  /// ⚠️ Sengaja **tidak** memakai [fetchTenants]. Yang itu hanya membaca tabel
  /// `tenants`, sehingga empat kolom pemakaian (toko, packer, video, token)
  /// harus dikumpulkan satu per satu dari aplikasi: 50 pelanggan berarti 200
  /// permintaan terpisah, dan Bab 11.1 melarang kueri lintas tenant dijalankan
  /// dari klien.
  Future<Result<List<AdminTenantRow>>> fetchAdminTenants({
    int limit = 200,
  }) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'admin_list_tenants',
        params: {'p_limit': limit},
      );
      return Result.ok(
        rows
            .cast<Map<String, dynamic>>()
            .map(AdminTenantRow.fromJson)
            .toList(growable: false),
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  Future<Result<List<Tenant>>> fetchTenants({
    TenantStatus? status,
    int limit = 50,
  }) async {
    try {
      var query = _client.from(AppConstants.tblTenants).select();
      if (status != null) query = query.eq('status', status.wire);
      final rows = await query
          .order('created_at', ascending: false)
          .limit(limit);
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

  /// Tolak pembayaran manual, **dengan alasan** (Bab 11.7) — RPC
  /// `admin_reject_payment()`, migrasi `32_admin_actions.sql`.
  ///
  /// 🔴 [reason] dibaca **pelanggan** apa adanya di halaman Pembayaran. Sampai
  /// 29 Agustus 2026 penolakan hanya mengubah status menjadi `failed` dari
  /// aplikasi, dan akibatnya di layar pelanggan: spanduk "menunggu verifikasi"
  /// lenyap tanpa satu kalimat pun yang menggantikannya — tagihannya seolah
  /// menguap. Ditemukan Product Owner saat menguji tombol Tolak pada baris
  /// sungguhan.
  ///
  /// Lewat RPC, bukan `update` biasa, karena penolakan wajib tercatat di
  /// `audit_logs` — dan tabel itu tidak punya izin tulis dari aplikasi sama
  /// sekali (migrasi 14).
  ///
  /// ⚠️ Yang tetap TIDAK terjadi: uang tidak dikembalikan, dan tidak ada
  /// pemberitahuan yang dikirim ke mana pun. Yang berubah hanya bahwa
  /// penolakannya kini terlihat saat pelanggan membuka halamannya.
  Future<Result<void>> rejectPayment({
    required String subscriptionId,
    required String reason,
  }) async {
    try {
      await _client.rpc<void>(
        'admin_reject_payment',
        params: {'p_subscription_id': subscriptionId, 'p_reason': reason},
      );
      return okVoid;
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Tambah atau kurangi token satu pelanggan (Bab 11.2) — RPC
  /// `admin_adjust_tokens()`. Mengembalikan saldo barunya.
  ///
  /// [delta] negatif berarti mengurangi. Saldo tidak pernah menjadi negatif;
  /// bila pengurangannya melebihi saldo, yang tercatat di buku besar adalah
  /// selisih yang benar-benar terjadi.
  ///
  /// 🔴 [reason] wajib dan ditegakkan **di server**, bukan hanya di formulir.
  /// `token_ledger` adalah satu-satunya alat menyelesaikan sengketa token
  /// dengan pelanggan (Bab 7.2 poin 5), dan baris tanpa alasan tidak
  /// menyelesaikan apa pun.
  ///
  /// ⚠️ Bonusnya **hangus** pada reset periode berikutnya — cron harian
  /// menjalankan `balance = monthly_quota` (Bab 7.2 poin 3). Itu keputusan
  /// Product Owner 29 Agustus 2026, bukan cacat. Layar wajib menyebutkan
  /// tanggal hangusnya sebelum tombolnya ditekan.
  Future<Result<int>> adjustTokens({
    required String tenantId,
    required int delta,
    required String reason,
  }) async {
    try {
      final saldo = await _client.rpc<int>(
        'admin_adjust_tokens',
        params: {'p_tenant_id': tenantId, 'p_delta': delta, 'p_reason': reason},
      );
      return Result.ok(saldo);
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Beri token serentak ke seluruh pelanggan **berstatus aktif** — RPC
  /// `admin_grant_tokens_all()`. Untuk pemberian bertema seperti "81 token
  /// untuk HUT RI ke-81".
  ///
  /// 🔴 Hanya menambah, dan hanya yang aktif. Uji coba sengaja tidak ikut
  /// (kuotanya 100 sekali seumur akun, Bab 7.5), begitu pula yang
  /// ditangguhkan (tokennya bertambah tetapi tetap tidak dapat merekam,
  /// Bab 7.6). Keputusan Product Owner 29 Agustus 2026.
  ///
  /// Mengembalikan `(sasaran, berhasil)`. Keduanya biasanya sama; selisih
  /// muncul bila ada tenant aktif yang dompetnya hilang, dan layar **wajib**
  /// menampilkan selisih itu alih-alih satu angka yang menutupinya.
  Future<Result<({int target, int granted})>> grantTokensToAllActive({
    required int delta,
    required String reason,
  }) async {
    try {
      final json = await _client.rpc<Map<String, dynamic>>(
        'admin_grant_tokens_all',
        params: {'p_delta': delta, 'p_reason': reason},
      );
      return Result.ok((
        target: (json['target'] as num?)?.toInt() ?? 0,
        granted: (json['granted'] as num?)?.toInt() ?? 0,
      ));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Ubah tier tenant secara manual — RPC `admin_change_tier()`, migrasi
  /// `35_admin_change_tier.sql`.
  ///
  /// 🔴 Lewat RPC, bukan `update` biasa, karena mengubah paket **wajib** ikut
  /// mengubah dompet tokennya (Bab 7.2 poin 4) — dan `token_wallets` beserta
  /// `token_ledger` sengaja tidak punya izin tulis dari aplikasi sama sekali
  /// (migrasi 14).
  ///
  /// Sampai 30 Agustus 2026 metode ini hanya menyentuh kolom `tier_plan`.
  /// Akibat terbesarnya bukan saldo hari itu, melainkan `monthly_quota` yang
  /// tertinggal: cron reset bulanan menjalankan `balance = monthly_quota`,
  /// jadi pelanggan yang dinaikkan ke Pro **selamanya** kembali ke 1.000 token
  /// tiap bulan, bukan 5.000 — tanpa satu pun galat, dan hanya tampak seperti
  /// pelanggan yang boros.
  ///
  /// ⚠️ **Status tenant tidak ikut berubah.** Kode lama menyetel
  /// `status = 'active'` setiap kali tier diubah, sehingga mengubah paket
  /// pelanggan yang sedang ditangguhkan diam-diam mencabut penangguhannya.
  /// Mencabut penangguhan punya tombolnya sendiri, dan aturan yang sama sudah
  /// disepakati untuk Perpanjang Periode.
  ///
  /// ⚠️ Bab 5.3 — JWT pelanggan masih membawa `tier_plan` lama sampai token
  /// disegarkan. Pelanggannya wajib keluar lalu masuk lagi sebelum batas tier
  /// baru terasa; sampai saat itu layarnya masih menulis keadaan lama padahal
  /// database sudah benar.
  Future<Result<void>> changeTier({
    required String tenantId,
    required TierPlan plan,
  }) async {
    try {
      await _client.rpc<Object?>(
        'admin_change_tier',
        params: {'p_tenant_id': tenantId, 'p_plan': plan.wire},
      );
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

  /// Perpanjang periode langganan tanpa mengubah tier (Bab 11.2).
  ///
  /// 🔴 [reactivate] ditentukan **pemanggil**, bukan disimpulkan di sini, dan
  /// itu sengaja. Memperpanjang tenant `expired` tanpa mengaktifkannya kembali
  /// menghasilkan pelanggan yang tanggal langganannya masih panjang tetapi
  /// tetap tidak dapat merekam (Bab 7.6) — keadaan yang benar menurut
  /// database dan mustahil dipahami dari layar. Sebaliknya, tenant
  /// `suspended` ditangguhkan karena alasan di luar pembayaran, dan
  /// memperpanjang periodenya tidak boleh diam-diam mencabut penangguhan itu.
  ///
  /// Karena keduanya berlawanan, keputusannya diambil di layar tempat
  /// keadaannya terlihat, lalu dikatakan pada dialog konfirmasi sebelum
  /// ditekan.
  ///
  /// ⚠️ Bab 5.3 — periode ada di dalam JWT lewat `tenant_status`. Akun
  /// pelanggannya wajib keluar lalu masuk lagi (atau `refreshSession()`)
  /// sebelum kuncinya benar-benar terbuka.
  Future<Result<void>> extendPeriod({
    required String tenantId,
    required DateTime periodEnd,
    required bool reactivate,
  }) async {
    try {
      await _client
          .from(AppConstants.tblTenants)
          .update({
            'period_end': periodEnd.toUtc().toIso8601String(),
            if (reactivate) 'status': TenantStatus.active.wire,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', tenantId);
      return okVoid;
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }
}
