import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Registrasi mandiri Owner. `email_normalized` dikirim sebagai metadata
  /// agar trigger server dapat memakainya tanpa menghitung ulang.
  Future<Result<AuthResponse>> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) =>
      _guard(
        () => _auth.signUp(
          email: email.trim().toLowerCase(),
          password: password,
          emailRedirectTo: Env.oauthRedirectUrl,
          data: {
            'full_name': fullName.trim(),
            'email_normalized': Validators.normalizeEmail(email),
            if (phone != null && phone.trim().isNotEmpty)
              'phone': Validators.normalizePhone(phone),
          },
        ),
      );

  /// Login Google.
  ///
  /// ⚠️ `google_sign_in` v7 memakai singleton `GoogleSignIn.instance` dan
  /// wajib `initialize()` lebih dulu — berbeda total dari v6 yang ditulis di
  /// Bab 4.2. Implementasi native menyusul di Bab 6; untuk sekarang jalur
  /// OAuth browser dipakai karena berlaku di semua platform.
  Future<Result<bool>> signInWithGoogle() => _guard(
        () => _auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Env.oauthRedirectUrl,
        ),
      );

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

/// Pemetaan pesan Supabase Auth yang sering muncul ke kunci l10n.
/// Dipakai lapisan UI, bukan di sini — [AppFailure] tetap bebas teks.
const Map<String, String> authErrorHints = {
  'Invalid login credentials': 'errorInvalidCredentials',
  'Email not confirmed': 'errorEmailNotConfirmed',
  'User already registered': 'errorEmailAlreadyUsed',
};
