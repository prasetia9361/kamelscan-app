import 'package:flutter/foundation.dart' show debugPrint;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/tier_config.dart';
import '../domain/quota_status.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import '../models/tenant.dart';
import '../models/token_wallet.dart';
import '../services/supabase_service.dart';
import '../utils/app_failure.dart';
import '../utils/result.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

part 'session_provider.g.dart';

/// Konteks pengguna aktif: profil + tenant + tier + dompet token.
///
/// Hampir setiap layar bergantung pada ini, jadi dikumpulkan sekali di satu
/// tempat agar tidak ada layar yang mengambil ulang `users` dan `tenants`
/// sendiri-sendiri.
class SessionContext {
  const SessionContext({
    required this.user,
    required this.tenant,
    required this.tierCatalog,
    this.wallet,
  });

  final AppUser user;
  final Tenant tenant;
  final TierCatalog tierCatalog;
  final TokenWallet? wallet;

  UserRole get role => user.role;
  String get tenantId => tenant.id;
  TierPlan get plan => tenant.tierPlan;

  /// Aturan tier yang berlaku. Selama uji coba, fitur setara Standar
  /// (Bab 7.5).
  /// 🔴 Masa uji coba meminjam aturan paket [TrialConfig.tier], KECUALI batas
  /// packer — yang itu miliknya sendiri.
  ///
  /// Sampai 31 Agustus 2026 ia meminjam seluruhnya. Begitu paket Standar
  /// disetel tak terbatas, masa uji coba ikut tak terbatas tanpa satu pun
  /// galat, dan pendaftar baru dapat membuat seratus akun packer gratis.
  TierConfig get tier => tenant.isTrial
      ? tierCatalog
            .of(tierCatalog.trial.tier)
            .copyWith(maxPackers: tierCatalog.trial.maxPackers)
      : tierCatalog.of(plan);

  bool get isTrial => tenant.isTrial;
  bool get isAdmin => user.isAdmin;
  bool get isOwner => user.isOwner;
  bool get isPacker => user.isPacker;

  /// Keadaan kuota token (Bab 7.3). Seluruh ambangnya ada di [QuotaStatus]
  /// agar dapat diuji tanpa perangkat.
  QuotaStatus get quota => QuotaStatus(
        balance: wallet?.balance ?? 0,
        // Saat uji coba, kuota penuhnya 100 dari platform_settings.trial —
        // bukan kuota bulanan tier (Bab 7.5).
        quota: wallet?.monthlyQuota ?? (isTrial ? tierCatalog.trial.tokens : 0),
        isTrial: isTrial,
      );

  /// Keadaan masa langganan (Bab 7.6).
  SubscriptionStatus get subscription => SubscriptionStatus(
        tenantStatus: tenant.status,
        periodEnd: tenant.periodEnd,
        isTrial: isTrial,
      );

  /// Bab 7.3 & 7.6 — perekaman butuh langganan aktif **dan** saldo token.
  bool get canRecord =>
      user.canRecord && tenant.canRecord && !quota.isExhausted;

  /// Alasan perekaman terkunci, agar UI menampilkan pesan yang tepat alih-alih
  /// tombol abu-abu tanpa penjelasan.
  RecordingLock? get recordingLock {
    if (!user.canRecord) return RecordingLock.roleNotAllowed;
    if (!tenant.canRecord) return RecordingLock.subscriptionInactive;
    if (quota.isExhausted) {
      return isTrial ? RecordingLock.trialExhausted : RecordingLock.noTokens;
    }
    return null;
  }

  /// Bab 7.6 — saat langganan berakhir, riwayat tetap terlihat tetapi tombol
  /// tonton/unduh/bagikan dinonaktifkan.
  bool get canPlayVideo => tenant.canPlayVideo && !user.isAdmin;

  /// Bab 2.2 catatan 4 — watermark logo kustom hanya tier Pro.

  SessionContext copyWith({TokenWallet? wallet}) => SessionContext(
        user: user,
        tenant: tenant,
        tierCatalog: tierCatalog,
        wallet: wallet ?? this.wallet,
      );
}

enum RecordingLock {
  roleNotAllowed,
  subscriptionInactive,
  trialExhausted,
  noTokens;

  /// Kunci l10n untuk pesan yang ditampilkan.
  String get messageKey => switch (this) {
        RecordingLock.roleNotAllowed => 'errorPermissionDenied',
        RecordingLock.subscriptionInactive => 'errorSubscriptionInactive',
        RecordingLock.trialExhausted => 'trialExhausted',
        RecordingLock.noTokens => 'errorTokenExhausted',
      };
}

@Riverpod(keepAlive: true)
class Session extends _$Session {
  @override
  Future<SessionContext?> build() async {
    final signedIn = ref.watch(isSignedInProvider);
    if (!signedIn) return null;

    final hasilProfil =
        await ref.read(userRepositoryProvider).fetchCurrentUser();

    // 🔴 Sesi sah, tetapi profilnya sudah tidak ada.
    //
    // Ditemukan 20 Agustus 2026: seorang packer yang sudah dihapus Owner
    // masih dapat masuk, lalu **terjebak** di layar *"Data tidak ditemukan"*.
    // Setiap layar bergantung pada sesi ini, sesi ini bergantung pada baris
    // `users` yang sudah tidak ada, dan tombol *Coba lagi* hanya mengulangi
    // pertanyaan yang sama ke server yang jawabannya tidak akan berubah.
    // Bahkan tombol keluar pun tidak terjangkau, karena ia berada di layar
    // yang tidak pernah sempat tampil. Menutup paksa aplikasi tidak menolong:
    // sesinya tersimpan, jadi pembukaan berikutnya mendarat di jebakan yang
    // sama.
    //
    // Sebab utamanya sudah diperbaiki di Edge Function `delete-packer`, tetapi
    // penjagaan ini tetap perlu: akun dapat lenyap karena sebab lain (dihapus
    // dari dasbor Supabase, tenant dibersihkan), dan aplikasi tidak boleh
    // punya keadaan yang tidak dapat ditinggalkan penggunanya.
    //
    // `notFound` cukup untuk memutuskan: PostgREST menjawab dengan sukses dan
    // berkata nol baris — bukan jaringan yang gagal, bukan RLS yang menolak.
    // Karena itu keluar paksa di sini aman; melakukan hal yang sama untuk
    // kegagalan jaringan justru akan mengeluarkan orang dari aplikasi setiap
    // kali sinyalnya hilang.
    if (hasilProfil case Err(:final failure)
        when failure.kind == FailureKind.notFound) {
      debugPrint('KAMELSCAN_SESI profil tidak ada · keluar paksa ke login');
      await ref.read(authRepositoryProvider).signOut();
      return null;
    }

    final user = hasilProfil.unwrap();

    // 🔴 Bab 6.7 — packer yang dinonaktifkan Owner TIDAK BOLEH punya sesi.
    //
    // Dilaporkan 31 Agustus 2026: menonaktifkan packer hanya menyetel
    // `users.is_active = false`, dan tidak ada satu baris pun yang pernah
    // membacanya di jalur masuk. Bekas pegawai yang aksesnya "sudah dicabut"
    // tetap dapat masuk dan bekerja seperti biasa.
    //
    // Gejalanya sama persis dengan cacat `delete-packer` 20 Agustus: Owner
    // menekan tombol, layarnya berubah, dan yang dijanjikan tombol itu tidak
    // pernah terjadi. `errorAccountDisabled` sudah ada di ARB sejak awal dan
    // tidak pernah sekali pun ditampilkan.
    //
    // ⚠️ Alasannya DITITIPKAN sebelum keluar paksa. Tanpa itu packer mendarat
    // di layar Masuk tanpa sepatah kata, menyimpulkan passwordnya rusak, dan
    // mencobanya berkali-kali — lalu menelepon Owner untuk keadaan yang justru
    // Owner sendiri yang membuatnya. `authLinkFailure` memang lahir untuk
    // tautan email, tetapi yang dibawanya adalah "kegagalan yang tidak datang
    // dari tombol mana pun", dan ini persis itu.
    if (!user.isActive) {
      debugPrint('KAMELSCAN_SESI akun nonaktif · keluar paksa ke login');
      SupabaseService.authLinkFailure.value =
          AppFailure.validation('errorAccountDisabled');
      await ref.read(authRepositoryProvider).signOut();
      return null;
    }

    final tenant =
        (await ref.read(userRepositoryProvider).fetchTenant(user.tenantId))
            .unwrap();

    // Harga & kuota dibaca dari platform_settings; gagal baca tidak boleh
    // mematikan aplikasi, jadi jatuh ke nilai cadangan (Bab 7.1).
    final catalog = (await ref.read(settingsRepositoryProvider).fetchTierCatalog())
        .getOrElse((_) => TierCatalog.fallback);

    final wallet = (await ref.read(tokenRepositoryProvider).fetchWallet(tenant.id))
        .valueOrNull;

    return SessionContext(
      user: user,
      tenant: tenant,
      tierCatalog: catalog,
      wallet: wallet,
    );
  }

  /// Muat ulang setelah perubahan profil, tier, atau pembayaran.
  Future<void> reload() async {
    state = const AsyncLoading();
    ref.invalidateSelf();
    await future;
  }

  /// Bab 5.3 — segarkan JWT lebih dulu agar klaim `tier_plan`/`app_role` baru
  /// ikut terbawa, baru muat ulang konteks.
  Future<void> refreshAfterRoleChange() async {
    await ref.read(authRepositoryProvider).refreshSession();
    await reload();
  }

  void updateWallet(TokenWallet wallet) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(wallet: wallet));
  }
}

/// Pintasan yang sering dipakai layar. Melempar [AppFailure] bila belum login —
/// route guard sudah memastikan itu tidak terjadi pada layar terlindungi.
@riverpod
SessionContext requireSession(Ref ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) throw AppFailure.sessionExpired;
  return session;
}

/// Bab 6.2 — profil belum memenuhi kolom yang ditandai wajib.
///
/// Selalu `false` selagi sesi masih dimuat, agar pengguna tidak sekelebat
/// terlempar ke layar Lengkapi Profil sebelum profilnya sempat terbaca.
@riverpod
bool needsProfileCompletion(Ref ref) =>
    ref.watch(sessionProvider).value?.user.needsProfileCompletion ?? false;

@riverpod
UserRole? currentRole(Ref ref) =>
    ref.watch(sessionProvider).value?.role;

/// Bab 9.6 — akun sedang menunggu dimusnahkan.
///
/// 🔴 Ada HANYA supaya `GoRouterRefreshNotifier` punya sesuatu yang sempit
/// untuk disimak. `RouteGuards.redirect` membaca
/// `sessionProvider.value.tenant.isDeletionPending`, dan nilai yang dibaca
/// penjaga tetapi tidak disimak notifier menghasilkan gejala yang sudah
/// memakan waktu berkali-kali di proyek ini: **layar yang seharusnya
/// berpindah, diam di tempat, tanpa satu pun galat.**
///
/// Persis itu yang dilaporkan Product Owner 1 September 2026 — *"akun sudah
/// dihapus tapi tidak ada respon sama sekali"*. Permintaannya berhasil,
/// `deletion_requested_at` benar-benar terisi, dan routernya tidak pernah
/// diberi tahu untuk menilai ulang.
///
/// ⚠️ Selalu `false` selagi sesi masih dimuat, mengikuti alasan yang sama
/// dengan [needsProfileCompletion]: jangan melempar orang ke layar kunci
/// sekelebat sebelum tenant-nya sempat terbaca.
@riverpod
bool deletionPending(Ref ref) =>
    ref.watch(sessionProvider).value?.tenant.isDeletionPending ?? false;

/// Saldo token langsung dari server, agar indikator ikut berubah saat packer
/// lain menyelesaikan unggahan (Bab 7.3).
@riverpod
Stream<TokenWallet> tokenWalletStream(Ref ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return const Stream.empty();
  return ref.watch(tokenRepositoryProvider).watchWallet(session.tenantId);
}
