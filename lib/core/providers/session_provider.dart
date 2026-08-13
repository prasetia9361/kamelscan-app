import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/tier_config.dart';
import '../domain/quota_status.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import '../models/tenant.dart';
import '../models/token_wallet.dart';
import '../utils/app_failure.dart';
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
  TierConfig get tier => tenant.isTrial
      ? tierCatalog.of(tierCatalog.trial.tier)
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
  bool get canUseCustomWatermark => isOwner && tier.allowsCustomWatermark;

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

    final user = (await ref.read(userRepositoryProvider).fetchCurrentUser())
        .unwrap();
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

/// Saldo token langsung dari server, agar indikator ikut berubah saat packer
/// lain menyelesaikan unggahan (Bab 7.3).
@riverpod
Stream<TokenWallet> tokenWalletStream(Ref ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return const Stream.empty();
  return ref.watch(tokenRepositoryProvider).watchWallet(session.tenantId);
}
