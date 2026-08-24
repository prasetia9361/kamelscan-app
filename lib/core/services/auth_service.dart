import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_constants.dart';
import '../config/env.dart';
import '../utils/app_failure.dart';
import '../utils/result.dart';
import '../utils/validators.dart';
import 'supabase_service.dart';

/// Pembungkus Supabase Auth (Bab 3.2).
///
/// Perilaku registrasi lengkap — trigger `handle_new_user`, pembuatan tenant,
/// dompet token uji coba, dan verifikasi email — ditetapkan di **Bab 6**.
/// Yang sudah pasti sejak Bab 0–4 dan dikunci di sini:
///
/// - Password **tidak pernah** menyentuh tabel aplikasi (Bab 5.1 poin 2).
/// - Registrasi mandiri selalu menghasilkan role `owner`; tidak ada jalur
///   registrasi menjadi `admin` maupun `packer` (Bab 2.1).
/// - Email dinormalkan sebelum dikirim agar celah alias Gmail tertutup
///   (Bab 7.5).
class AuthService {
  const AuthService();

  GoTrueClient get _auth => SupabaseService.auth;

  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  Session? get currentSession => _auth.currentSession;

  Future<Result<AuthResponse>> signInWithPassword({
    required String email,
    required String password,
  }) =>
      _guard(
        () => _auth.signInWithPassword(
          email: email.trim().toLowerCase(),
          password: password,
        ),
      );

  /// Registrasi mandiri Owner (Bab 6.2 & 6.3).
  ///
  /// Metadata di sini dibaca oleh trigger `handle_new_user` untuk membentuk
  /// tenant, profil, dompet uji coba, dan pengaturan awal. `role` dikirim
  /// eksplisit meski server sudah memakai `owner` sebagai bawaan — supaya
  /// niatnya terbaca dan tidak bergantung pada nilai bawaan yang bisa berubah.
  Future<Result<AuthResponse>> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String? username,
    String? businessName,
  }) =>
      _guard(
        () => _auth.signUp(
          email: email.trim().toLowerCase(),
          password: password,
          emailRedirectTo: Env.emailVerifyRedirectUrl,
          data: {
            'role': 'owner',
            'full_name': fullName.trim(),
            'email_normalized': Validators.normalizeEmail(email),
            if (phone != null && phone.trim().isNotEmpty)
              'phone': Validators.normalizePhone(phone),
            if (username != null && username.trim().isNotEmpty)
              'username': username.trim().toLowerCase(),
            if (businessName != null && businessName.trim().isNotEmpty)
              'business_name': businessName.trim(),
            // Bab 6.2 — centang S&K di formulir dicatat sekarang juga, supaya
            // pendaftar lewat formulir tidak diminta menyetujui dua kali.
            // Waktunya ditentukan server oleh trigger, bukan jam perangkat.
            'terms_version': AppConstants.termsVersion,
          },
        ),
      );

  /// Catat persetujuan Syarat & Ketentuan (Bab 6.2).
  ///
  /// Memakai RPC agar **waktunya ditentukan server**. Jam HP dapat dimundurkan,
  /// dan catatan persetujuan yang waktunya berasal dari perangkat pelanggan
  /// tidak ada gunanya justru saat disengketakan — alasan yang sama dengan
  /// `scan_date` di Bab 5.5b.
  Future<Result<void>> acceptTerms() => _guard(
        () => SupabaseService.client.rpc<void>(
          'accept_terms',
          params: {'p_version': AppConstants.termsVersion},
        ),
      );

  /// Lengkapi nomor HP yang tidak pernah diberikan Google (Bab 6.2).
  ///
  /// 🔴 `.select()` di ujungnya bukan hiasan. Tanpa itu PostgREST menjawab
  /// **sukses** walaupun tidak ada satu baris pun yang berubah — baris yang
  /// tersaring RLS tidak menghasilkan error, ia hanya menghasilkan nol baris.
  /// Akibatnya layar *Lengkapi Profil* melapor berhasil, memuat ulang sesi,
  /// lalu menemukan nomor HP masih kosong dan mengunci pengguna di layar yang
  /// sama tanpa satu pun pesan yang menjelaskan apa pun.
  Future<Result<void>> updatePhone(String phone) async {
    final id = SupabaseService.currentUser?.id;
    if (id == null) return const Result.err(AppFailure.sessionExpired);

    return _guard(() async {
      final rows = await SupabaseService.client
          .from(AppConstants.tblUsers)
          .update({'phone': Validators.normalizePhone(phone)})
          .eq('id', id)
          .select('id');
      if (rows.isEmpty) throw AppFailure.permissionDenied;
    });
  }

  /// Bab 6.2 — apakah username masih bebas.
  ///
  /// Dicek sebelum `signUp` dikirim. Bila dibiarkan sampai server, pelanggaran
  /// `users_username_key` terjadi di dalam trigger `handle_new_user` dan
  /// GoTrue membungkusnya menjadi *"Database error saving new user"* — pesan
  /// yang tidak menyebut username sama sekali.
  ///
  /// Memakai RPC `is_username_available` yang hanya mengembalikan boolean,
  /// bukan kueri ke tabel `users` (Bab 6.6).
  Future<Result<bool>> isUsernameAvailable(String username) => _guard(() async {
        final res = await SupabaseService.client.rpc<dynamic>(
          'is_username_available',
          params: {'p_username': username.trim().toLowerCase()},
        );
        return res == true;
      });

  /// Bab 6.6 — Supabase Auth hanya mengenal email, jadi username ditukar
  /// dulu lewat Edge Function `resolve-username`.
  ///
  /// ⚠️ Tabel `users` **tidak** boleh dibuka untuk `anon`; itu akan
  /// membocorkan seluruh daftar email pelanggan.
  Future<Result<String>> resolveUsernameToEmail(String username) async {
    try {
      final res = await SupabaseService.client.functions.invoke(
        AppConstants.fnResolveUsername,
        body: {'username': username.trim().toLowerCase()},
      );
      final email = (res.data as Map?)?['email'] as String?;
      if (email == null || email.isEmpty) {
        return const Result.err(
          AppFailure(
            kind: FailureKind.auth,
            messageKey: 'errorInvalidCredentials',
          ),
        );
      }
      return Result.ok(email);
    } on FunctionException catch (e) {
      // 404 = username tidak ada. Sengaja dipetakan ke pesan yang sama dengan
      // "kredensial salah" agar tidak bisa dipakai menebak username terdaftar.
      if (e.status == 429) {
        return const Result.err(
          AppFailure(kind: FailureKind.auth, messageKey: 'errorTooManyAttempts'),
        );
      }
      return const Result.err(
        AppFailure(kind: FailureKind.auth, messageKey: 'errorInvalidCredentials'),
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Inisialisasi `google_sign_in` v7, dikerjakan **sekali** dan dibagikan.
  ///
  /// 🔴 Sebelumnya `initialize()` dipanggil di dalam [signInWithGoogle], yaitu
  /// tepat setelah tombol ditekan. Di Android v7 langkah itulah yang menyiapkan
  /// Credential Manager dan mengambil konfigurasi akun perangkat — pekerjaan
  /// yang memakan waktu, dan seluruhnya terjadi sementara pengguna menatap
  /// tombol yang belum memunculkan apa pun. Dipindahkan ke awal aplikasi
  /// ([warmUpGoogleSignIn]), sehingga saat tombolnya ditekan yang tersisa
  /// hanya memunculkan pemilih akun.
  ///
  /// Bila gagal, hasilnya **tidak** disimpan — percobaan berikutnya harus
  /// benar-benar mencoba lagi, bukan mewarisi kegagalan lama selamanya.
  static Future<void>? _googleReady;

  Future<void> _ensureGoogleReady() async {
    final pending = _googleReady;
    if (pending != null) return pending;

    final started = Future<void>(() async {
      try {
        await GoogleSignIn.instance.initialize(
          serverClientId: Env.googleWebClientId,
          clientId:
              Env.googleIosClientId.isEmpty ? null : Env.googleIosClientId,
        );
      } on Object {
        _googleReady = null;
        rethrow;
      }
    });
    _googleReady = started;
    return started;
  }

  /// Dipanggil dari `main()` agar tombol *Lanjutkan dengan Google* tidak
  /// menanggung biaya inisialisasi.
  ///
  /// Sengaja menelan kegagalannya: gagal memanaskan bukan alasan untuk
  /// menggagalkan peluncuran aplikasi, dan percobaan sungguhan lewat tombol
  /// akan mencoba lagi beserta pesan errornya sendiri.
  Future<void> warmUpGoogleSignIn() async {
    if (kIsWeb || !Env.googleSignInConfigured) return;
    try {
      await _ensureGoogleReady();
      debugPrint('KAMELSCAN_GOOGLE siap dipakai');
    } on Object catch (e) {
      debugPrint('KAMELSCAN_GOOGLE pemanasan GAGAL · $e');
    }
  }

  /// Login Google (Bab 6.5).
  ///
  /// Web memakai alur OAuth lewat browser; mobile memakai `google_sign_in`
  /// untuk mengambil `idToken` lalu menukarnya di Supabase — sesuai Bab 6.5.
  ///
  /// ⚠️ `google_sign_in` v7 memakai singleton `GoogleSignIn.instance` dan wajib
  /// `initialize()` lebih dulu; berbeda total dari v6 yang ditulis di Bab 4.2
  /// (lihat DEVIASI_LIBRARY.md bagian B). Inisialisasi itu kini sudah
  /// dikerjakan lebih awal — lihat [warmUpGoogleSignIn].
  ///
  /// ⚠️ Di Android, alur ini **hanya berfungsi setelah SHA-1 dan SHA-256
  /// keystore debug DAN release didaftarkan di Google Cloud Console**. Bila
  /// belum, `authenticate()` gagal dengan galat konfigurasi.
  Future<Result<void>> signInWithGoogle() async {
    if (!Env.googleSignInConfigured) {
      return const Result.err(
        AppFailure(
          kind: FailureKind.auth,
          messageKey: 'errorGoogleNotConfigured',
        ),
      );
    }

    if (kIsWeb) {
      return _guard(
        () => _auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Env.oauthRedirectUrl,
        ),
      );
    }

    try {
      await _ensureGoogleReady();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        return const Result.err(
          AppFailure(kind: FailureKind.auth, messageKey: 'errorGoogleNoToken'),
        );
      }

      await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      return okVoid;
    } on GoogleSignInException catch (e) {
      // Pengguna menutup dialog pemilihan akun — bukan kegagalan, jangan
      // ditampilkan sebagai error merah.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const Result.err(
          AppFailure(kind: FailureKind.auth, messageKey: 'errorCancelled'),
        );
      }
      return Result.err(
        AppFailure(
          kind: FailureKind.auth,
          messageKey: 'errorGoogleFailed',
          debugMessage: '${e.code}: ${e.description}',
        ),
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  // ---------------------------------------------------------------
  // Wajib ganti password saat login pertama (Bab 6.7)
  // ---------------------------------------------------------------

  /// Dibaca dari `user_metadata`, yang diisi Edge Function `create-packer`.
  bool get mustChangePassword =>
      _auth.currentUser?.userMetadata?['must_change_password'] == true;

  /// Dipanggil setelah packer berhasil mengganti password. Flag dihapus agar
  /// ia tidak dipaksa mengganti lagi di login berikutnya.
  Future<Result<void>> clearMustChangePassword() => _guard(
        () => _auth.updateUser(
          UserAttributes(data: {'must_change_password': false}),
        ),
      );

  /// Bab 6.8 — verifikasi ulang password lama sebelum menggantinya.
  /// Tanpa ini, siapa pun yang menemukan HP tidak terkunci bisa mengambil alih
  /// akun hanya dengan mengganti password.
  Future<Result<void>> reauthenticate(String currentPassword) async {
    final email = _auth.currentUser?.email;
    if (email == null) {
      return const Result.err(AppFailure.sessionExpired);
    }
    final result = await signInWithPassword(
      email: email,
      password: currentPassword,
    );
    return result.map((_) {});
  }

  /// Bab 6.7 — pembuatan akun packer dijalankan Edge Function memakai service
  /// role. Klien **tidak pernah** memegang kunci itu (Bab 4.4).
  Future<Result<PackerCredentials>> createPacker({
    required String email,
    required String fullName,
    String? phone,
    List<String> shopIds = const [],
  }) async {
    try {
      final res = await SupabaseService.client.functions.invoke(
        AppConstants.fnCreatePacker,
        body: {
          'email': email.trim().toLowerCase(),
          'full_name': fullName.trim(),
          if (phone != null && phone.trim().isNotEmpty)
            'phone': Validators.normalizePhone(phone),
          'shop_ids': shopIds,
        },
      );
      final data = (res.data as Map?)?.cast<String, dynamic>() ?? const {};
      final password = data['temp_password'] as String?;
      final userId = data['user_id'] as String?;
      if (password == null || userId == null) {
        return const Result.err(
          AppFailure(kind: FailureKind.unknown, messageKey: 'errorUnknown'),
        );
      }
      return Result.ok(
        PackerCredentials(
          userId: userId,
          email: data['email'] as String? ?? email,
          temporaryPassword: password,
        ),
      );
    } on FunctionException catch (e) {
      return Result.err(_mapPackerError(e));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  static AppFailure _mapPackerError(FunctionException e) {
    final code = (e.details is Map)
        ? (e.details as Map)['error']?.toString()
        : null;
    return switch (code) {
      'PACKER_LIMIT_REACHED' => AppFailure.packerLimitReached,
      'EMAIL_ALREADY_USED' => const AppFailure(
          kind: FailureKind.conflict,
          messageKey: 'errorEmailAlreadyUsed',
        ),
      'SUBSCRIPTION_INACTIVE' => AppFailure.subscriptionInactive,
      'FORBIDDEN' || 'UNAUTHORIZED' => AppFailure.permissionDenied,
      _ => AppFailure(
          kind: FailureKind.unknown,
          messageKey: 'errorUnknown',
          debugMessage: 'create-packer: ${e.status} $code',
        ),
    };
  }

  Future<Result<void>> sendPasswordReset(String email) => _guard(
        () => _auth.resetPasswordForEmail(
          email.trim().toLowerCase(),
          redirectTo: Env.oauthRedirectUrl,
        ),
      );

  Future<Result<void>> updatePassword(String newPassword) =>
      _guard(() => _auth.updateUser(UserAttributes(password: newPassword)));

  Future<Result<void>> resendVerificationEmail(String email) => _guard(
        () => _auth.resend(
          type: OtpType.signup,
          email: email.trim().toLowerCase(),
        ),
      );

  Future<Result<void>> signOut() => _guard(() => _auth.signOut());

  Future<Result<T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Result.ok(await body());
    } on Object catch (e, s) {
      return Result<T>.err(SupabaseService.mapError(e, s));
    }
  }
}

/// Kredensial packer yang baru dibuat.
///
/// ⚠️ [temporaryPassword] hanya ada di memori dan **ditampilkan sekali**
/// (Bab 6.7). Jangan pernah menuliskannya ke log, Sentry, atau penyimpanan
/// lokal.
class PackerCredentials {
  const PackerCredentials({
    required this.userId,
    required this.email,
    required this.temporaryPassword,
  });

  final String userId;
  final String email;
  final String temporaryPassword;

  @override
  String toString() => 'PackerCredentials($email, password disembunyikan)';
}

/// Pemetaan pesan Supabase Auth yang sering muncul ke kunci l10n.
/// Dipakai lapisan UI, bukan di sini — [AppFailure] tetap bebas teks.
const Map<String, String> authErrorHints = {
  'Invalid login credentials': 'errorInvalidCredentials',
  'Email not confirmed': 'errorEmailNotConfirmed',
  'User already registered': 'errorEmailAlreadyUsed',
};
